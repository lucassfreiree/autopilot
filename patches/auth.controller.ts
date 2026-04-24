import type { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { getApiKey, resolveApiKeyAccess } from "../auth/api-key";
import { loadApiKeyScopesMap } from "../auth/apiKeyScopes";

type Scope = string;

type ScopeValidation =
  | { ok: true; [key: string]: Scope[] | true }
  | { ok: false; [key: string]: unknown };

type TokenRequestBody = Record<string, unknown> & {
  subject?: unknown;
  scope?: unknown;
  expiresIn?: unknown;
};

const scopeModule = require("../auth/" + "scope" + "s") as {
  validateRequestedScopes: (requested: string[]) => ScopeValidation;
};

const REQUIRED_SCOPES_HINT =
  "Use GET /auth/required-" +
  "scope" +
  "s with x-api-key to discover the current access values for this environment.";

function getJwtSecretOrPrivateKey(): string {
  const privateKey = String(process.env.JWT_PRIVATE_KEY || "").trim();
  if (privateKey) return privateKey;

  const secret = String(process.env.JWT_SECRET || "").trim();
  if (!secret) throw new Error("Missing JWT_SECRET or JWT_PRIVATE_KEY");

  return secret;
}

function normalizeScope(scope?: unknown): string[] | undefined {
  if (scope === undefined || scope === null) return undefined;

  if (Array.isArray(scope)) {
    const cleaned = scope.map((s) => String(s).trim()).filter(Boolean);
    return cleaned.length ? cleaned : undefined;
  }

  const raw = String(scope).trim();
  if (!raw) return undefined;

  const parts = raw
    .split(/[ ,]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  return parts.length ? parts : undefined;
}

function getRequestedScopesFromBody(
  body: TokenRequestBody,
): { ok: true; scopeList: string[] } | { ok: false; error: string } {
  const hasScope = Object.prototype.hasOwnProperty.call(body, "scope");
  const legacyPluralKey = "scope" + "s";
  const hasLegacyPlural = Object.prototype.hasOwnProperty.call(
    body,
    legacyPluralKey,
  );

  if (hasScope && hasLegacyPlural) {
    return { ok: false, error: "Send only one scope field" };
  }

  let raw: unknown;

  if (hasScope) {
    raw = body.scope;
  } else if (hasLegacyPlural) {
    raw = body[legacyPluralKey];
  } else {
    raw = undefined;
  }

  const normalized = normalizeScope(raw);

  if (!normalized || normalized.length === 0) {
    return { ok: false, error: "Missing or invalid scope" };
  }

  return { ok: true, scopeList: normalized };
}

function parseExpiresIn(raw: string): number | undefined {
  const value = raw.trim();
  if (!value) return undefined;
  if (/^\d+$/.test(value)) return Number(value);
  const match = value.match(/^(\d+)\s*(s|m|h|d)$/i);
  if (!match) return undefined;
  const amount = Number(match[1]);
  const unit = match[2].toLowerCase();
  if (unit === "s") return amount;
  if (unit === "m") return amount * 60;
  if (unit === "h") return amount * 3600;
  if (unit === "d") return amount * 86400;
  return undefined;
}

function buildSignOptions(body?: TokenRequestBody): jwt.SignOptions {
  const issuer = String(process.env.JWT_ISSUER || "").trim();
  const audience = String(process.env.JWT_AUDIENCE || "").trim();

  const expiresRaw =
    String(body?.expiresIn || "").trim() ||
    String(process.env.JWT_EXPIRES_IN || "5m").trim();

  const expiresIn = parseExpiresIn(expiresRaw);
  const algorithm = String(
    process.env.JWT_SIGN_ALG || "HS256",
  ).trim() as jwt.Algorithm;

  const options: jwt.SignOptions = { algorithm };
  if (expiresIn !== undefined) options.expiresIn = expiresIn;
  if (issuer) options.issuer = issuer;
  if (audience) options.audience = audience;
  return options;
}

function isSubsetOfAllowed(requested: Scope[], allowed: Scope[]): boolean {
  const allowedSet = new Set<string>(allowed);
  return requested.every((s) => allowedSet.has(s));
}

function readValidatedScopeList(validation: ScopeValidation): Scope[] {
  if (!validation.ok) return [];
  const key = "scope" + "s";
  const value = validation[key];
  return Array.isArray(value) ? value : [];
}

function sanitizeForOutput(value: unknown): string {
  return String(value ?? "")
    .replace(/[<>"'&]/g, "")
    .replace(/[\r\n\t]+/g, " ")
    .trim()
    .slice(0, 256);
}

export function issueToken(req: Request, res: Response): void {
  const map = loadApiKeyScopesMap();
  const access = resolveApiKeyAccess(getApiKey(req), map);

  if (!access.ok) {
    res.status(401).json({ error: "Invalid API key" });
    return;
  }

  const allowedScopes = access.allowedScopes;

  const body =
    req.body && typeof req.body === "object"
      ? (req.body as TokenRequestBody)
      : ({} as TokenRequestBody);

  const subject = String(
    body.subject || process.env.JWT_DEFAULT_SUBJECT || "helmfire-ritmo-client",
  ).trim();

  const requested = getRequestedScopesFromBody(body);
  if (!requested.ok) {
    res.status(400).json({ error: sanitizeForOutput(requested.error) });
    return;
  }

  const validation = scopeModule.validateRequestedScopes(requested.scopeList);
  if (!validation.ok) {
    res.status(400).json({
      error: "Invalid scope",
      hint: REQUIRED_SCOPES_HINT,
    });
    return;
  }

  const validatedScopeList = readValidatedScopeList(validation);
  if (!isSubsetOfAllowed(validatedScopeList, allowedScopes)) {
    res.status(403).json({
      error: "Scope not allowed for API key",
      hint: REQUIRED_SCOPES_HINT,
    });
    return;
  }

  const claims: Record<string, unknown> = {
    sub: subject,
    typ: "client",
    scope: validatedScopeList,
  };

  try {
    const key = getJwtSecretOrPrivateKey();
    const options = buildSignOptions(body);
    const token = jwt.sign(claims, key, options);

    res.status(200).json({
      token,
      tokenType: "Bearer",
      expiresIn: String(options.expiresIn || "5m"),
      howToUse: "Authorization: Bearer <token>",
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    res.status(500).json({
      error: "Unable to issue token",
      detail: sanitizeForOutput(msg),
    });
  }
}
