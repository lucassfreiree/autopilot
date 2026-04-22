import { AgentsRepo } from "../repository/agentsRepo";
import { resolveAgentExecuteUrl } from "./agent-url";

export function resolveTrustedRegisteredAgentExecuteUrlByCluster(
  cluster: string,
): string | null {
  const registeredAgent = AgentsRepo.getAgentByCluster(cluster);
  if (!registeredAgent) return null;

  return resolveAgentExecuteUrl({ cluster: registeredAgent.Cluster });
}
