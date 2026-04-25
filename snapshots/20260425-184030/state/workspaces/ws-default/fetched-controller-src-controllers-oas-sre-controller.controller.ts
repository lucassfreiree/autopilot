import type { Request, Response } from "express";
import crypto from "node:crypto";
import {
  initExecution,
  type ExecutionSnapshot,
  waitForFinalExecution,
} from "./agents-execute-logs.controller";
import type { OasOriginAuthDecision } from "../middleware/oas-origin-auth";
import { timestampSP } from "../util/time";
import {
  resolveTrustedRegisteredAgentExecuteUrl,
  resolveTrustedRegisteredAgentExecuteUrlByCluster,
} from "../util/trusted-agent";
import { readSyncTimeoutMs } from "../util/sync-timeout";

type JsonRecord = Record<string, unknown>;

type Locals = {
  requestId?: string;
  oasAuthDecision?: OasOriginAuthDecision;
};

type DispatchPlan = {
  cluster: string;
};

type ResolvedDispatchPlan = DispatchPlan & {
  agentUrl: string;
};

type ValidationResult =
  | {
      ok: true;
      requestType: "legacy";
      execId?: string;
      image: string;
      envs: JsonRecord;
      clustersNames: string[];
    }
  | {
      ok: true;
      requestType: "function";
      execId?: string;
      functionName: string;
      cluster: string;
      namespace: string;
      envs?: JsonRecord;
      clustersNames: string[];
    }
  | {
      ok: false;
      errors: string[];
    };

type AgentCallResult = {
  cluster: string;
  status: number;
  ok: boolean;
};

type SyncResponseContext = {
  execId: string;
  requestType: "legacy" | "function";
  image?: string;
  functionName?: string;
  cluster?: string;
  namespace?: string;
  clustersNames: string[];
  authMode: string;
  dispatches: AgentCallResult[];
  snapshot: ExecutionSnapshot;
};

type AllowedImage = {
  key: string;
  aliases: string[];
  functionName: string;
};

const SAFE_IDENTIFIER_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;
const DEFAULT_AGENT_CALL_TIMEOUT_MS = 35_000;
const DEFAULT_COPY_RESOURCE_TYPES = "secrets,configmaps";
const SUPPORTED_SRE_FUNCTIONS = [
  "migration_origem",
  "migration_destino",
  "migration",
  "manage_namespace_origem",
  "manage_namespace_destino",
  "copy_resources_origem",
  "copy_resources_destino",
  "get_pods",
  "get_all_resources",
];
const COPY_RESOURCES_FUNCTIONS = new Set([
  "copy_resources_origem",
  "copy_resources_destino",
]);
const ALLOWED_COPY_RESOURCE_ACTIONS = ["copy", "apply", "remove"];

function asRecord(value: unknown): JsonRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as JsonRecord;
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function sanitizeForOutput(value: unknown): string {
  return String(value ?? "")
    .replace(/[<>"'&]/g, "")
    .replace(/[\r\n\t]+/g, " ")
    .trim()
    .slice(0, 256);
}

function safeLogValue(value: unknown): string {
  return String(value ?? "")
    .replace(/[\r\n\t]+/g, " ")
    .trim()
    .slice(0, 256);
}

function readAgentCallTimeoutMs(): number {
  const raw = Number(process.env.AGENT_CALL_TIMEOUT_MS || "");
  if (!Number.isFinite(raw) || raw < 1) {
    return DEFAULT_AGENT_CALL_TIMEOUT_MS;
  }

  return Math.floor(raw);
}

function parseSafeIdentifier(value: unknown): string {
  const normalized = safeString(value);
  if (!normalized || !SAFE_IDENTIFIER_PATTERN.test(normalized)) return "";
  return encodeURIComponent(normalized);
}

function normalizeFunctionName(value: string): string {
  return value.replace(/-/g, "_").trim().toLowerCase();
}

function normalizeMode(req: Request): "sync" | "async" {
  const raw =
    typeof req.query.mode === "string"
      ? req.query.mode.trim().toLowerCase()
      : "";
  return raw === "sync" ? "sync" : "async";
}

function normalizeImageKey(imageName: string): string {
  const withoutDigest = imageName.split("@")[0].trim();
  const lastPath = withoutDigest.split("/").pop() || withoutDigest;
  const withoutTag = lastPath.split(":")[0];
  return withoutTag.trim().toLowerCase();
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(
    new Set(values.map((item) => item.trim()).filter(Boolean)),
  );
}

function allowedImages(): AllowedImage[] {
  const defaultImageKey = "psc-sre-ns-migration-preflight";

  const configuredImageKey =
    safeString(process.env.OAS_PREFLIGHT_IMAGE_KEY) || defaultImageKey;
  const configuredImageAliases = String(
    process.env.OAS_PREFLIGHT_IMAGE_ALIASES || "",
  )
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);

  return [
    {
      key: normalizeImageKey(configuredImageKey),
      aliases: uniqueStrings([configuredImageKey, ...configuredImageAliases]),
      functionName:
        safeString(process.env.OAS_PREFLIGHT_FUNCTION) ||
        safeString(process.env.OAS_PREFLIGHT_FUNCTION_ORIGEM) ||
        "sre_execute",
    },
  ];
}

function resolveAllowedImage(rawImageName: string): AllowedImage | null {
  const key = normalizeImageKey(rawImageName);
  return (
    allowedImages().find((image) => {
      if (image.key === key) return true;
      return image.aliases.some((alias) => normalizeImageKey(alias) === key);
    }) ?? null
  );
}

function parseClustersNames(
  value: unknown,
  errors: string[],
): string[] {
  let rawValues: unknown[] = [];

  if (Array.isArray(value)) {
    rawValues = value;
  } else {
    const asText = safeString(value);
    if (!asText) {
      errors.push(
        "Field 'CLUSTERS_NAMES' is required and must be an array of cluster names.",
      );
      return [];
    }

    if (asText.startsWith("[")) {
      try {
        const parsed = JSON.parse(asText) as unknown;
        if (Array.isArray(parsed)) {
          rawValues = parsed;
        } else {
          errors.push("Field 'CLUSTERS_NAMES' must be a JSON array.");
          return [];
        }
      } catch {
        errors.push("Field 'CLUSTERS_NAMES' must be a valid JSON array.");
        return [];
      }
    } else {
      rawValues = asText.split(",").map((item) => item.trim());
    }
  }

  const clusters = rawValues
    .map((item) => parseSafeIdentifier(item))
    .filter(Boolean);

  if (clusters.length < 1) {
    errors.push(
      "Field 'CLUSTERS_NAMES' must include at least one valid cluster name.",
    );
    return [];
  }

  if (clusters.length !== rawValues.length) {
    errors.push(
      "Field 'CLUSTERS_NAMES' contains invalid values. Allowed pattern: A-Z, a-z, 0-9, dot, underscore, hyphen.",
    );
    return [];
  }

  return uniqueStrings(clusters);
}

function cloneEnvs(value: unknown): JsonRecord | null {
  const record = asRecord(value);
  if (!record) return null;
  try {
    return JSON.parse(JSON.stringify(record)) as JsonRecord;
  } catch {
    return null;
  }
}

function readEnvsSource(source: JsonRecord): unknown {
  return (
    source["envs"] ??
    source["ENVS"] ??
    source["variables"] ??
    source["vars"]
  );
}

function readEnvString(envs: JsonRecord, keys: string[]): string {
  return keys.reduce<string>((acc, key) => acc || safeString(envs[key]), "");
}

function parseOptionalExecId(
  source: JsonRecord,
  errors: string[],
): string | undefined {
  if (source["execId"] === undefined) return undefined;

  const execId = parseSafeIdentifier(source["execId"]);
  if (!execId) {
    errors.push(
      "Field 'execId' must match the allowed identifier pattern.",
    );
    return undefined;
  }

  return execId;
}

function validateLegacyPayload(source: JsonRecord): ValidationResult {
  const errors: string[] = [];
  const execId = parseOptionalExecId(source, errors);

  const imageRaw = safeString(source["image"] ?? source["IMAGE"]);
  if (!imageRaw) {
    errors.push("Field 'image' is required.");
    return { ok: false, errors };
  }

  const allowedImage = resolveAllowedImage(imageRaw);
  if (!allowedImage) {
    const allowed = allowedImages().map((img) => img.key);
    errors.push(
      `Image '${sanitizeForOutput(imageRaw)}' is not allowed. Allowed images: ${allowed.join(", ")}.`,
    );
    return { ok: false, errors };
  }

  const envs = cloneEnvs(readEnvsSource(source));
  if (!envs) {
    errors.push(
      "Field 'envs' is required and must be a JSON object with the environment variables for the image.",
    );
    return { ok: false, errors };
  }

  const clustersNamesRaw =
    source["CLUSTERS_NAMES"] ??
    source["clusters_names"] ??
    source["clustersNames"];
  const clustersNames = parseClustersNames(clustersNamesRaw, errors);
  if (errors.length > 0) return { ok: false, errors };

  return {
    ok: true,
    requestType: "legacy",
    execId,
    image: imageRaw,
    envs,
    clustersNames,
  };
}

function validateFunctionPayload(source: JsonRecord): ValidationResult {
  const errors: string[] = [];
  const execId = parseOptionalExecId(source, errors);

  const cluster = parseSafeIdentifier(source["cluster"]);
  if (!cluster) {
    errors.push(
      "Field 'cluster' is required and must match the allowed identifier pattern.",
    );
  }

  const namespace = parseSafeIdentifier(source["namespace"]);
  if (!namespace) {
    errors.push(
      "Field 'namespace' is required and must match the allowed identifier pattern.",
    );
  }

  const rawFunctionName = safeString(source["function"]);
  const functionName = normalizeFunctionName(
    parseSafeIdentifier(rawFunctionName),
  );
  if (!functionName) {
    errors.push(
      "Field 'function' is required and must match the allowed identifier pattern.",
    );
  } else if (!SUPPORTED_SRE_FUNCTIONS.includes(functionName)) {
    errors.push(
      `Function ${sanitizeForOutput(functionName)} is not recognized. Available: ${SUPPORTED_SRE_FUNCTIONS.join(", ")}.`,
    );
  }

  const envsRaw = readEnvsSource(source);
  let envs: JsonRecord | undefined;
  if (envsRaw !== undefined) {
    const clonedEnvs = cloneEnvs(envsRaw);
    if (!clonedEnvs) {
      errors.push("Field 'envs' must be a JSON object when provided.");
    } else {
      envs = clonedEnvs;
    }
  }

  if (functionName && COPY_RESOURCES_FUNCTIONS.has(functionName)) {
    if (!envs) {
      errors.push(`Field 'envs' is required for function '${functionName}'.`);
    } else {
      const action = readEnvString(envs, ["ACTION", "action"]).toLowerCase();
      if (!action) {
        errors.push(
          `Field 'envs.ACTION' is required for function '${functionName}'. Allowed values: ${ALLOWED_COPY_RESOURCE_ACTIONS.join(", ")}.`,
        );
      } else if (!ALLOWED_COPY_RESOURCE_ACTIONS.includes(action)) {
        errors.push(
          `Field 'envs.ACTION' has invalid value '${sanitizeForOutput(action)}'. Allowed values: ${ALLOWED_COPY_RESOURCE_ACTIONS.join(", ")}.`,
        );
      } else {
        envs.ACTION = action;
      }

      const namespaceEnvironment = readEnvString(envs, [
        "NAMESPACE_ENVIRONMENT",
        "namespace_environment",
      ]);
      if (!namespaceEnvironment) {
        errors.push(
          `Field 'envs.NAMESPACE_ENVIRONMENT' is required for function '${functionName}'.`,
        );
      } else {
        envs.NAMESPACE_ENVIRONMENT = namespaceEnvironment;
      }

      const resourceTypes = readEnvString(envs, [
        "RESOURCE_TYPES",
        "resource_types",
      ]);
      envs.RESOURCE_TYPES = resourceTypes || DEFAULT_COPY_RESOURCE_TYPES;
    }
  }

  if (errors.length > 0) return { ok: false, errors };

  return {
    ok: true,
    requestType: "function",
    execId,
    functionName,
    cluster,
    namespace,
    envs,
    clustersNames: [cluster],
  };
}

function validateSreControllerPayload(body: unknown): ValidationResult {
  const source = asRecord(body);
  if (!source) {
    return { ok: false, errors: ["Request body must be a JSON object."] };
  }

  const hasLegacyContract = Boolean(safeString(source["image"] ?? source["IMAGE"]));
  const hasFunctionContract =
    source["function"] !== undefined ||
    source["cluster"] !== undefined ||
    source["namespace"] !== undefined;

  if (hasLegacyContract && hasFunctionContract) {
    return {
      ok: false,
      errors: [
        "Payload must use either the legacy image/envs/CLUSTERS_NAMES contract or the function/cluster/namespace contract, but not both.",
      ],
    };
  }

  if (hasFunctionContract) {
    return validateFunctionPayload(source);
  }

  if (hasLegacyContract) {
    return validateLegacyPayload(source);
  }

  return {
    ok: false,
    errors: [
      "Payload must include either field 'image' or the fields 'function', 'cluster', and 'namespace'.",
    ],
  };
}

function getIncomingAuthorization(req: Request): string | undefined {
  const auth = safeString(req.headers.authorization);
  return auth || undefined;
}

function getAgentAuthorization(req: Request): string | undefined {
  const incoming = getIncomingAuthorization(req);
  if (incoming) return incoming;

  const fromEnv = safeString(process.env.AGENT_EXECUTE_AUTHORIZATION);
  return fromEnv || undefined;
}

async function callAgent(
  url: string,
  headers: Record<string, string>,
  payload: unknown,
): Promise<{ status: number; ok: boolean }> {
  const timeoutMs = readAgentCallTimeoutMs();
  const abort = new AbortController();
  const timeoutId = setTimeout(() => abort.abort(), timeoutMs);
  try {
    const resp = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
      signal: abort.signal,
    });

    return {
      status: resp.status,
      ok: resp.ok,
    };
  } finally {
    clearTimeout(timeoutId);
  }
}

function readAuthDecision(res: Response): OasOriginAuthDecision | undefined {
  const locals = res.locals as Locals;
  return locals.oasAuthDecision;
}

function summarizeDispatches(dispatches: AgentCallResult[]) {
  return dispatches.map((item) => ({
    cluster: sanitizeForOutput(item.cluster),
    agentStatus: item.status,
  }));
}

function buildBaseResponsePayload(context: {
  execId: string;
  requestType: "legacy" | "function";
  image?: string;
  functionName?: string;
  cluster?: string;
  namespace?: string;
  clustersNames: string[];
  authMode: string;
  dispatches: AgentCallResult[];
}) {
  return {
    ...(context.requestType === "legacy" && context.image
      ? { image: sanitizeForOutput(context.image) }
      : {}),
    ...(context.requestType === "function"
      ? {
          function: sanitizeForOutput(context.functionName),
          cluster: sanitizeForOutput(context.cluster),
          namespace: sanitizeForOutput(context.namespace),
        }
      : {}),
    execId: context.execId,
    clustersNames: context.clustersNames.map(sanitizeForOutput),
    authMode: sanitizeForOutput(context.authMode),
    dispatches: summarizeDispatches(context.dispatches),
    statusEndpoint: `/agent/execute?uuid=${encodeURIComponent(context.execId)}`,
  };
}

function buildSyncResponsePayload(context: SyncResponseContext) {
  const MAX_SYNC_ENTRIES = 500;
  const boundedEntries = context.snapshot.entries.slice(0, MAX_SYNC_ENTRIES);
  return {
    mode: "sync" as const,
    ...buildBaseResponsePayload(context),
    status: context.snapshot.status,
    statusLabel: context.snapshot.statusLabel,
    finished: context.snapshot.finished,
    lastUpdate: context.snapshot.lastUpdate,
    count: boundedEntries.length,
    entries: boundedEntries,
  };
}

export async function postOasSreController(
  req: Request,
  res: Response,
): Promise<void> {
  const mode = normalizeMode(req);
  const validation = validateSreControllerPayload(req.body);

  if (!validation.ok) {
    res.status(400).json({
      ok: false,
      error: "Invalid payload for /oas/sre-controller",
      details: validation.errors.map(sanitizeForOutput),
    });
    return;
  }

  const execId = validation.execId || crypto.randomUUID();
  initExecution(execId);

  const requestId = safeString(req.header("x-request-id")) || execId;
  const authDecision = readAuthDecision(res);
  const outboundAuthorization = getAgentAuthorization(req);
  const safeRequestName = safeLogValue(
    validation.requestType === "legacy"
      ? validation.image
      : validation.functionName,
  );

  console.info(
    "[oas-sre-controller] start execId=%s request=%s clusters=%d authMode=%s",
    safeLogValue(execId),
    safeRequestName,
    validation.clustersNames.length,
    safeLogValue(authDecision?.mode || "jwt"),
  );

  let dispatches: AgentCallResult[] = [];

  try {
    let plans: ResolvedDispatchPlan[] = [];

    if (validation.requestType === "legacy") {
      const resolvedPlans: Array<ResolvedDispatchPlan | null> =
        validation.clustersNames.map((cluster) => {
          const agentUrl =
            resolveTrustedRegisteredAgentExecuteUrlByCluster(cluster);
          return agentUrl ? { cluster, agentUrl } : null;
        });

      const missingTargets = validation.clustersNames.filter(
        (_, i) => resolvedPlans[i] === null,
      );

      if (missingTargets.length > 0) {
        res.status(404).json({
          ok: false,
          error: "Agent not registered for one or more cluster targets",
          missingTargets: missingTargets.map(sanitizeForOutput),
        });
        return;
      }

      plans = resolvedPlans.filter(
        (plan): plan is ResolvedDispatchPlan => plan !== null,
      );
    } else {
      const agentUrl = resolveTrustedRegisteredAgentExecuteUrl({
        cluster: validation.cluster,
        namespace: validation.namespace,
      });
      if (!agentUrl) {
        res.status(404).json({
          ok: false,
          error: "Agent not registered for given cluster/namespace",
          cluster: sanitizeForOutput(validation.cluster),
          namespace: sanitizeForOutput(validation.namespace),
        });
        return;
      }

      plans = [{ cluster: validation.cluster, agentUrl }];
    }

    if (plans.length === 0) {
      res.status(404).json({
        ok: false,
        error: "Agent not registered for the requested execution target",
      });
      return;
    }

    dispatches = await Promise.all(
      plans.map(async (plan) => {
        const headers: Record<string, string> = {
          "content-type": "application/json",
          "x-request-id": requestId,
          "x-exec-id": execId,
        };

        if (outboundAuthorization) {
          headers.authorization = outboundAuthorization;
        }

        const forwardBody =
          validation.requestType === "legacy"
            ? {
                execId,
                cluster: plan.cluster,
                image: validation.image,
                envs: validation.envs,
              }
            : {
                execId,
                cluster: validation.cluster,
                namespace: validation.namespace,
                function: validation.functionName,
                envs: validation.envs,
              };

        console.info(
          "[oas-sre-controller] dispatch execId=%s cluster=%s url=%s",
          safeLogValue(execId),
          safeLogValue(plan.cluster),
          safeLogValue(plan.agentUrl),
        );

        const agentResponse = await callAgent(
          plan.agentUrl,
          headers,
          forwardBody,
        );
        return {
          ...agentResponse,
          cluster: plan.cluster,
        };
      }),
    );

    const failedDispatch = dispatches.find((dispatch) => !dispatch.ok);
    if (failedDispatch) {
      console.error(
        "[oas-sre-controller] agent-error execId=%s cluster=%s status=%d",
        safeLogValue(execId),
        safeLogValue(failedDispatch.cluster),
        failedDispatch.status,
      );

      res.status(502).json({
        ok: false,
        error: "Failed to call Agent",
        execId,
        cluster: sanitizeForOutput(failedDispatch.cluster),
        agentStatus: failedDispatch.status,
        dispatches: summarizeDispatches(dispatches),
      });
      return;
    }

    console.info(
      "[oas-sre-controller] accepted execId=%s clusters=%d",
      safeLogValue(execId),
      dispatches.length,
    );

    if (mode === "sync") {
      const timeoutMs = readSyncTimeoutMs(process.env);
      const { timedOut, snapshot } = await waitForFinalExecution(
        execId,
        timeoutMs,
      );
      const syncPayload = buildSyncResponsePayload({
        execId,
        requestType: validation.requestType,
        image: validation.requestType === "legacy" ? validation.image : undefined,
        functionName:
          validation.requestType === "function"
            ? validation.functionName
            : undefined,
        cluster: validation.requestType === "function" ? validation.cluster : undefined,
        namespace:
          validation.requestType === "function" ? validation.namespace : undefined,
        clustersNames: validation.clustersNames,
        authMode: sanitizeForOutput(authDecision?.mode || "jwt"),
        dispatches,
        snapshot,
      });

      if (timedOut) {
        res.status(504).json({
          ok: false,
          error: "TIMEOUT",
          message:
            "Timed out while waiting for execution to reach a final state (DONE or ERROR).",
          timeoutMs,
          ...syncPayload,
        });
        return;
      }

      if (snapshot.status === "ERROR") {
        res.status(502).json({
          ok: false,
          error: "EXECUTION_ERROR",
          message:
            "Execution finished with ERROR status reported by the Agent callback.",
          ...syncPayload,
        });
        return;
      }

      res.status(200).json({
        ok: true,
        ...syncPayload,
      });
      return;
    }

    res.status(202).json({
      ok: true,
      mode: "async",
      status: "RUNNING",
      startedAt: timestampSP(),
      ...buildBaseResponsePayload({
        execId,
        requestType: validation.requestType,
        image: validation.requestType === "legacy" ? validation.image : undefined,
        functionName:
          validation.requestType === "function"
            ? validation.functionName
            : undefined,
        cluster: validation.requestType === "function" ? validation.cluster : undefined,
        namespace:
          validation.requestType === "function" ? validation.namespace : undefined,
        clustersNames: validation.clustersNames,
        authMode: authDecision?.mode || "jwt",
        dispatches,
      }),
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    const isAbort = error instanceof Error && error.name === "AbortError";

    if (isAbort) {
      const timeoutMs = readAgentCallTimeoutMs();
      console.error(
        "[oas-sre-controller] timeout execId=%s timeoutMs=%d",
        safeLogValue(execId),
        timeoutMs,
      );

      res.status(504).json({
        ok: false,
        error: "Timed out while waiting for Agent response",
        detail: `No response from Agent after ${timeoutMs}ms`,
        execId,
        dispatches: summarizeDispatches(dispatches),
      });
      return;
    }

    console.error(
      "[oas-sre-controller] exception execId=%s detail=%s",
      safeLogValue(execId),
      safeLogValue(msg),
    );

    res.status(500).json({
      ok: false,
      error: "Internal error while dispatching OAS automation",
      detail: sanitizeForOutput(msg),
      execId,
      dispatches: summarizeDispatches(dispatches),
    });
  }
}
