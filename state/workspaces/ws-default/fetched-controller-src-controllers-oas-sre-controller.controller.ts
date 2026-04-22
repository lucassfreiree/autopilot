import type { Request, Response } from "express";
import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import {
  initExecution,
  type ExecutionSnapshot,
  waitForFinalExecution,
} from "./agents-execute-logs.controller";
import type { OasOriginAuthDecision } from "../middleware/oas-origin-auth";
import { timestampSP } from "../util/time";
import { resolveTrustedRegisteredAgentExecuteUrlByCluster } from "../util/trusted-agent";
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
      image: string;
      functionName: string;
      namespace: string;
      envs: JsonRecord;
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
  image: string;
  clustersNames: string[];
  authMode: string;
  dispatches: AgentCallResult[];
  snapshot: ExecutionSnapshot;
};

type AllowedImage = {
  key: string;
  aliases: string[];
  functionName: string;
  functionVariants?: Record<string, string>;
};

const SAFE_IDENTIFIER_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;
const DEFAULT_AGENT_CALL_TIMEOUT_MS = 35_000;
const TRUSTED_AGENT_URL_PATTERN =
  /^https?:\/\/(?!.*@)[a-zA-Z0-9._-]+(?::[0-9]{1,5})?(?:\/[^\s<>"']*)?$/;

const BLOCKED_SSRF_HOSTS = [
  "169.254.169.254",
  "metadata.google.internal",
  "metadata.goog",
  "localhost",
  "127.0.0.1",
  "[::1]",
  "0.0.0.0",
];

function isBlockedSsrfHost(hostname: string): boolean {
  const host = hostname.toLowerCase();
  if (BLOCKED_SSRF_HOSTS.includes(host)) return true;
  if (host.startsWith("169.254.")) return true;
  return false;
}

function parseAllowedAgentDomains(): string[] {
  return (process.env.ALLOWED_AGENT_DOMAINS || "")
    .split(",")
    .map((d) => d.trim().toLowerCase())
    .filter(Boolean);
}

function isAllowedAgentHost(hostname: string): boolean {
  const allowedDomains = parseAllowedAgentDomains();
  if (allowedDomains.length === 0) return true;
  const host = hostname.toLowerCase();
  return allowedDomains.some(
    (domain) => host === domain || host.endsWith(`.${domain}`),
  );
}

function validateTrustedUrl(url: string): boolean {
  if (!url || !TRUSTED_AGENT_URL_PATTERN.test(url)) return false;
  try {
    const parsed = new URL(url);
    if (isBlockedSsrfHost(parsed.hostname)) return false;
    if (!isAllowedAgentHost(parsed.hostname)) return false;
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") return false;
    return true;
  } catch {
    return false;
  }
}

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

function sanitizeEnvValues(envs: JsonRecord): JsonRecord {
  return Object.fromEntries(
    Object.entries(envs).map(([key, value]) => [
      key,
      typeof value === "string"
        ? value.replace(/[<>"'&]/g, "").replace(/[\r\n\t]+/g, " ").trim()
        : value,
    ]),
  ) as JsonRecord;
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
  const preflightKey =
    safeString(process.env.OAS_PREFLIGHT_IMAGE_KEY) ||
    "psc-sre-ns-migration-preflight";

  const provisionKey =
    safeString(process.env.OAS_PROVISION_IMAGE_KEY) ||
    "psc-sre-provision-or-remove-ns";

  const copyKey =
    safeString(process.env.OAS_COPY_IMAGE_KEY) ||
    "psc-sre-cp-or-del-sec-and-cm";

  return [
    {
      key: normalizeImageKey(preflightKey),
      aliases: [preflightKey],
      functionName:
        safeString(process.env.OAS_PREFLIGHT_FUNCTION_ORIGEM) ||
        "migration_origem",
      functionVariants: {
        migration_origem: "migration_origem",
        migration_destino: "migration_destino",
        migration: "migration",
      },
    },
    {
      key: normalizeImageKey(provisionKey),
      aliases: [provisionKey],
      functionName: "manage_namespace_origem",
      functionVariants: {
        manage_namespace_origem: "manage_namespace_origem",
        manage_namespace_destino: "manage_namespace_destino",
      },
    },
    {
      key: normalizeImageKey(copyKey),
      aliases: [copyKey],
      functionName: "copy_resources_origem",
      functionVariants: {
        copy_resources_origem: "copy_resources_origem",
        copy_resources_destino: "copy_resources_destino",
      },
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

function resolveFunction(
  source: JsonRecord,
  allowedImage: AllowedImage | null,
): string {
  const fnRaw = safeString(source["function"] ?? source["FUNCTION"]);
  if (fnRaw) {
    const safe = parseSafeIdentifier(fnRaw);
    if (safe && allowedImage?.functionVariants) {
      const decoded = decodeURIComponent(safe);
      if (decoded in allowedImage.functionVariants) {
        return allowedImage.functionVariants[decoded];
      }
    }
    if (safe) return decodeURIComponent(safe);
  }
  return allowedImage?.functionName ?? "";
}

function validateSreControllerPayload(body: unknown): ValidationResult {
  const errors: string[] = [];

  const source = asRecord(body);
  if (!source) {
    return { ok: false, errors: ["Request body must be a JSON object."] };
  }

  // image — optional when function is provided
  const imageRaw = safeString(source["image"] ?? source["IMAGE"]);
  const functionRaw = safeString(source["function"] ?? source["FUNCTION"]);

  if (!imageRaw && !functionRaw) {
    errors.push("Either 'image' or 'function' is required.");
    return { ok: false, errors };
  }

  let allowedImage: AllowedImage | null = null;
  let resolvedImage = imageRaw;

  if (imageRaw) {
    allowedImage = resolveAllowedImage(imageRaw);
    if (!allowedImage) {
      const allowed = allowedImages().map((img) => img.key);
      errors.push(
        `Image '${sanitizeForOutput(imageRaw)}' is not allowed. Allowed images: ${allowed.join(", ")}.`,
      );
      return { ok: false, errors };
    }
  } else if (functionRaw) {
    const all = allowedImages();
    const matched = all.find(
      (img) =>
        (img.functionVariants && functionRaw in img.functionVariants) ||
        img.functionName === functionRaw,
    );
    if (matched) {
      allowedImage = matched;
      resolvedImage = matched.key;
    }
    if (!allowedImage) {
      const allFunctions = allowedImages().flatMap((img) =>
        img.functionVariants ? Object.keys(img.functionVariants) : [img.functionName],
      );
      errors.push(
        `Function '${sanitizeForOutput(functionRaw)}' is not recognized. Available: ${allFunctions.join(", ")}.`,
      );
      return { ok: false, errors };
    }
  }

  const functionName = resolveFunction(source, allowedImage);
  if (!functionName) {
    errors.push("Could not resolve a valid function name from image or function field.");
    return { ok: false, errors };
  }

  // namespace — required
  const namespaceRaw = safeString(
    source["namespace"] ?? source["NAMESPACE"],
  );
  const namespace = parseSafeIdentifier(namespaceRaw);
  if (!namespace) {
    errors.push(
      "Field 'namespace' is required (target namespace for the automation).",
    );
    return { ok: false, errors };
  }

  // envs — optional (some automations like get_pods don't need envs)
  const envsRaw =
    source["envs"] ??
    source["ENVS"] ??
    source["variables"] ??
    source["vars"];
  const envs = cloneEnvs(envsRaw) ?? {};

  // CLUSTERS_NAMES or cluster (single)
  const clustersNamesRaw =
    source["CLUSTERS_NAMES"] ??
    source["clusters_names"] ??
    source["clustersNames"] ??
    source["cluster"];

  let clustersNames: string[];
  if (typeof clustersNamesRaw === "string" && !safeString(clustersNamesRaw).startsWith("[")) {
    const single = parseSafeIdentifier(clustersNamesRaw);
    if (!single) {
      errors.push("Field 'cluster' or 'CLUSTERS_NAMES' is required with at least one valid cluster name.");
      return { ok: false, errors };
    }
    clustersNames = [decodeURIComponent(single)];
  } else {
    clustersNames = parseClustersNames(clustersNamesRaw, errors);
    if (errors.length > 0) return { ok: false, errors };
  }

  return {
    ok: true,
    image: resolvedImage,
    functionName,
    namespace: decodeURIComponent(namespace),
    envs: sanitizeEnvValues(envs),
    clustersNames,
  };
}

function parseExpiresIn(raw: string): number {
  if (!raw) return 0;
  const num = Number(raw);
  if (Number.isFinite(num) && num > 0) return Math.floor(num);
  const match = raw.match(/^(\d+)\s*(s|m|h|d)$/i);
  if (!match) return 0;
  const value = Number(match[1]);
  const unit = match[2].toLowerCase();
  if (unit === "s") return value;
  if (unit === "m") return value * 60;
  if (unit === "h") return value * 3600;
  if (unit === "d") return value * 86400;
  return 0;
}

function generateOutboundAgentJwt(execId: string): string | undefined {
  const secret = safeString(process.env.JWT_SECRET);
  if (!secret) {
    const fromEnv = safeString(process.env.AGENT_EXECUTE_AUTHORIZATION);
    return fromEnv || undefined;
  }

  const issuer =
    safeString(process.env.JWT_ISSUER) || "psc-sre-automacao-controller";
  const audience =
    safeString(process.env.JWT_AUDIENCE) || "psc-sre-automacao-agent";
  const subject =
    safeString(process.env.JWT_DEFAULT_SUBJECT) || "oas-sre-controller";
  const expiresInRaw = safeString(process.env.JWT_EXPIRES_IN);
  const expiresIn = parseExpiresIn(expiresInRaw) || 300;
  const algorithm = (safeString(process.env.JWT_SIGN_ALG) ||
    "HS256") as jwt.Algorithm;

  const scopeExecute = safeString(process.env.SCOPE_EXECUTE_AUTOMATION);

  const token = jwt.sign(
    {
      sub: subject,
      scope: scopeExecute ? [scopeExecute] : [],
      execId,
    },
    secret,
    { algorithm, expiresIn, issuer, audience },
  );

  return `Bearer ${token}`;
}

async function callAgent(
  url: string,
  headers: Record<string, string>,
  payload: unknown,
): Promise<{ status: number; ok: boolean }> {
  if (!validateTrustedUrl(url)) {
    return { status: 400, ok: false };
  }
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

function buildSyncResponsePayload(context: SyncResponseContext) {
  const MAX_SYNC_ENTRIES = 500;
  const boundedEntries = context.snapshot.entries.slice(0, MAX_SYNC_ENTRIES);
  return {
    mode: "sync" as const,
    execId: context.execId,
    image: sanitizeForOutput(context.image),
    clustersNames: context.clustersNames.map(sanitizeForOutput),
    authMode: sanitizeForOutput(context.authMode),
    dispatches: summarizeDispatches(context.dispatches),
    statusEndpoint: `/agent/execute?uuid=${encodeURIComponent(context.execId)}`,
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

  const safeImage = sanitizeForOutput(validation.image);
  const safeClusters = validation.clustersNames.map(sanitizeForOutput);

  const execId = crypto.randomUUID();
  initExecution(execId);

  const requestId = safeString(req.header("x-request-id")) || execId;
  const authDecision = readAuthDecision(res);
  const outboundAuthorization = generateOutboundAgentJwt(execId);

  console.info(
    "[oas-sre-controller] start execId=%s function=%s image=%s namespace=%s clusters=%d authMode=%s",
    safeLogValue(execId),
    safeLogValue(validation.functionName),
    safeLogValue(validation.image),
    safeLogValue(validation.namespace),
    validation.clustersNames.length,
    safeLogValue(authDecision?.mode || "jwt"),
  );

  let dispatches: AgentCallResult[] = [];

  try {
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

    const plans = resolvedPlans.filter(
      (p): p is ResolvedDispatchPlan => p !== null,
    );

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

        const forwardBody = {
          execId,
          cluster: encodeURIComponent(plan.cluster),
          namespace: encodeURIComponent(validation.namespace),
          function: encodeURIComponent(validation.functionName),
          image: encodeURIComponent(validation.image),
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
        image: safeImage,
        clustersNames: safeClusters,
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
      execId,
      status: "RUNNING",
      startedAt: timestampSP(),
      image: safeImage,
      clustersNames: safeClusters,
      authMode: sanitizeForOutput(authDecision?.mode || "jwt"),
      dispatches: summarizeDispatches(dispatches),
      statusEndpoint: `/agent/execute?uuid=${encodeURIComponent(execId)}`,
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
