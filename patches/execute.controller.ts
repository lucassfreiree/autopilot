import type { NextFunction, Request, Response } from "express";
import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { initExecution } from "./agents-execute-logs.controller";
import { timestampSP } from "../util/time";
import { resolveTrustedRegisteredAgentExecuteUrl } from "../util/trusted-agent";

type AgentForwardBody = {
  execId: string;
  cluster: string;
  namespace: string;
  function: string;
};

type FetchJsonResult =
  | { ok: true; status: number; json: unknown }
  | { ok: false; status: number; json: unknown }
  | { ok: false; status: number; text: string };

type LocalsExec = {
  execId: string;
  startedAt: number;
};

const SAFE_IDENTIFIER_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;
const DEFAULT_AGENT_CALL_TIMEOUT_MS = 30_000;
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

function sanitizeForOutput(value: unknown): string {
  return String(value ?? "")
    .replace(/[<>"'&]/g, "")
    .replace(/[\r\n\t]+/g, " ")
    .trim()
    .slice(0, 256);
}

function parseSafeIdentifier(value: unknown): string {
  if (typeof value !== "string") return "";

  const trimmed = value.trim();
  if (!trimmed || !SAFE_IDENTIFIER_PATTERN.test(trimmed)) return "";

  return encodeURIComponent(trimmed);
}

function normalizeMode(req: Request): "sync" | "async" {
  const raw =
    typeof req.query.mode === "string"
      ? req.query.mode.trim().toLowerCase()
      : "";
  return raw === "sync" ? "sync" : "async";
}

function safeString(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

function readAgentCallTimeoutMs(): number {
  const raw = Number(process.env.AGENT_CALL_TIMEOUT_MS || "");
  if (!Number.isFinite(raw) || raw < 1) {
    return DEFAULT_AGENT_CALL_TIMEOUT_MS;
  }

  return Math.floor(raw);
}

type ExecuteRequestBody = {
  cluster?: unknown;
  namespace?: unknown;
  function?: unknown;
};

function extractExecuteRequestBody(body: unknown): ExecuteRequestBody {
  if (!body || typeof body !== "object" || Array.isArray(body)) return {};

  const source = body as Record<string, unknown>;
  return {
    cluster: source.cluster,
    namespace: source.namespace,
    function: source.function,
  };
}

async function postJson(
  url: string,
  headers: Record<string, string>,
  body: unknown,
): Promise<FetchJsonResult> {
  if (!validateTrustedUrl(url)) {
    return { ok: false, status: 400, text: "Untrusted URL" };
  }
  const timeoutMs = readAgentCallTimeoutMs();
  const abort = new AbortController();
  const timeoutId = setTimeout(() => abort.abort(), timeoutMs);
  let resp: globalThis.Response;

  try {
    resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
      signal: abort.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }

  const ct = String(resp.headers.get("content-type") || "");
  if (ct.includes("application/json")) {
    const json = await resp.json().catch(() => null);
    if (resp.ok) return { ok: true, status: resp.status, json };
    return { ok: false, status: resp.status, json };
  }

  const text = await resp.text().catch(() => "");
  return { ok: false, status: resp.status, text };
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
    safeString(process.env.JWT_DEFAULT_SUBJECT) || "execute-controller";
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

function setLocals(res: Response, locals: LocalsExec): void {
  const obj = res.locals as unknown;
  if (typeof obj !== "object" || obj === null) {
    res.locals = locals as unknown as typeof res.locals;
    return;
  }
  const rec = obj as Record<string, unknown>;
  rec.execId = locals.execId;
  rec.startedAt = locals.startedAt;
}

export async function executeAgent(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const mode = normalizeMode(req);
    const body = extractExecuteRequestBody(req.body);
    const cluster = parseSafeIdentifier(body.cluster);
    const namespace = parseSafeIdentifier(body.namespace);
    const fn = parseSafeIdentifier(body.function);

    if (!cluster || !namespace || !fn) {
      res.status(400).json({
        ok: false,
        error:
          "Missing or invalid required fields: cluster, namespace, function",
      });
      return;
    }

    const execId = randomUUID();
    setLocals(res, { execId, startedAt: Date.now() });
    initExecution(execId);

    const reqId = safeString(req.header("x-request-id")) || execId;
    const trustedAgentUrl = resolveTrustedRegisteredAgentExecuteUrl({
      cluster,
      namespace,
    });
    if (!trustedAgentUrl) {
      res.status(404).json({
        ok: false,
        error: "Agent not registered for given cluster/namespace",
      });
      return;
    }

    if (!validateTrustedUrl(trustedAgentUrl)) {
      res.status(500).json({ ok: false, error: "Resolved agent URL is not trusted" });
      return;
    }

    const headers: Record<string, string> = {
      "x-request-id": reqId,
      "x-exec-id": execId,
    };

    const outboundAuth = generateOutboundAgentJwt(execId);
    if (outboundAuth) headers.authorization = outboundAuth;

    const forwardBody: AgentForwardBody = {
      execId,
      cluster: encodeURIComponent(cluster),
      namespace: encodeURIComponent(namespace),
      function: encodeURIComponent(fn),
    };

    const resp = await postJson(trustedAgentUrl, headers, forwardBody);

    if (!resp.ok) {
      res.status(502).json({
        ok: false,
        error: "Failed to call Agent",
        execId,
        agentStatus: resp.status,
      });
      return;
    }

    if (mode === "async") {
      res.status(202).json({
        ok: true,
        execId,
        mode: "async",
        status: "RUNNING",
        timestamp: timestampSP(),
        message:
          "Request accepted. The Agent will process this execution asynchronously.",
      });
      return;
    }

    next();
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    const isAbort = e instanceof Error && e.name === "AbortError";
    const execId = ((res.locals as Record<string, unknown>).execId as string) || undefined;
    if (isAbort) {
      const timeoutMs = readAgentCallTimeoutMs();
      res.status(504).json({
        ok: false,
        error: "Timed out while waiting for Agent response",
        detail: `No response from Agent after ${timeoutMs}ms`,
        execId,
      });
      return;
    }

    res.status(500).json({
      ok: false,
      error: "Internal error while dispatching execution",
      detail: sanitizeForOutput(msg),
      execId,
    });
  }
}
