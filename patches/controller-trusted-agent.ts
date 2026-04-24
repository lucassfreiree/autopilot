import { AgentsRepo } from "../repository/agentsRepo";
import type { AgentRow } from "../db/sqlite";
import { resolveAgentExecuteUrl } from "./agent-url";

type TrustedAgentInput = {
  cluster: string;
  namespace: string;
};

export type TrustedRegisteredAgentResolution = {
  agentUrl: string;
  cluster: string;
  namespace: string;
  lookupStrategy: "cluster+namespace" | "cluster";
};

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

export function validateTrustedUrl(url: string): boolean {
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

function buildResolution(
  registeredAgent: AgentRow,
  lookupStrategy: TrustedRegisteredAgentResolution["lookupStrategy"],
): TrustedRegisteredAgentResolution | null {
  const agentUrl = resolveAgentExecuteUrl({ cluster: registeredAgent.Cluster });
  if (!agentUrl) return null;
  if (!validateTrustedUrl(agentUrl)) return null;

  return {
    agentUrl,
    cluster: registeredAgent.Cluster,
    namespace: registeredAgent.Namespace,
    lookupStrategy,
  };
}

export function resolveTrustedRegisteredAgentExecuteUrl(
  input: TrustedAgentInput,
): string | null {
  const registeredAgent = AgentsRepo.getAgentByClusterAndNamespace(
    input.cluster,
    input.namespace,
  );
  if (!registeredAgent) return null;

  return resolveAgentExecuteUrl({ cluster: registeredAgent.Cluster });
}

export function resolveTrustedRegisteredAgentByCluster(
  cluster: string,
): TrustedRegisteredAgentResolution | null {
  const registeredAgent = AgentsRepo.getAgentByCluster(cluster);
  if (!registeredAgent) return null;

  return buildResolution(registeredAgent, "cluster");
}

export function resolveTrustedRegisteredAgentExecuteTarget(
  input: TrustedAgentInput,
): TrustedRegisteredAgentResolution | null {
  const registeredAgent = AgentsRepo.getAgentByClusterAndNamespace(
    input.cluster,
    input.namespace,
  );
  if (registeredAgent) {
    return buildResolution(registeredAgent, "cluster+namespace");
  }

  return resolveTrustedRegisteredAgentByCluster(input.cluster);
}

export function resolveTrustedRegisteredAgentExecuteUrlByCluster(
  cluster: string,
): string | null {
  return resolveTrustedRegisteredAgentByCluster(cluster)?.agentUrl || null;
}
