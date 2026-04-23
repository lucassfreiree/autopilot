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

function buildResolution(
  registeredAgent: AgentRow,
  lookupStrategy: TrustedRegisteredAgentResolution["lookupStrategy"],
): TrustedRegisteredAgentResolution | null {
  const agentUrl = resolveAgentExecuteUrl({ cluster: registeredAgent.Cluster });
  if (!agentUrl) return null;

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
