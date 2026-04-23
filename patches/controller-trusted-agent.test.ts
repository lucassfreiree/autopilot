import fs from "node:fs";
import os from "node:os";
import path from "node:path";

describe("trusted agent resolution", () => {
  const originalEnv = process.env;
  let tmpDir = "";
  let dbPath = "";

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "trusted-agent-"));
    dbPath = path.join(tmpDir, "test.db");
    process.env = {
      ...originalEnv,
      DB_PATH: dbPath,
      AGENT_BASE_URL_TEMPLATE: "https://agent.{cluster}.svc.local",
      AGENT_EXECUTE_URL_TEMPLATE: "",
      AGENT_BASE_URL: "",
      AGENT_EXECUTE_URL: "",
    };
    jest.resetModules();
  });

  afterEach(() => {
    process.env = originalEnv;
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // Best-effort cleanup for temp dir.
    }
  });

  test("returns null when cluster is not registered", async () => {
    const {
      resolveTrustedRegisteredAgentByCluster,
      resolveTrustedRegisteredAgentExecuteUrlByCluster,
      resolveTrustedRegisteredAgentExecuteTarget,
    } = await import("../../util/trusted-agent");

    expect(
      resolveTrustedRegisteredAgentExecuteUrlByCluster("cluster-a"),
    ).toBeNull();
    expect(resolveTrustedRegisteredAgentByCluster("cluster-a")).toBeNull();
    expect(
      resolveTrustedRegisteredAgentExecuteTarget({
        cluster: "cluster-a",
        namespace: "target-ns",
      }),
    ).toBeNull();
  });

  test("resolves agent URL for registered cluster regardless of namespace", async () => {
    const { AgentsRepo } = await import("../../repository/agentsRepo");
    const { resolveTrustedRegisteredAgentExecuteUrlByCluster } = await import(
      "../../util/trusted-agent"
    );

    AgentsRepo.upsertAgent({
      Namespace: "psc-agent",
      Cluster: "cluster-a",
      environment: "hml",
    });

    expect(
      resolveTrustedRegisteredAgentExecuteUrlByCluster("cluster-a"),
    ).toBe("https://agent.cluster-a.svc.local/agent/execute");
  });

  test("returns null for unregistered cluster even if another cluster is registered", async () => {
    const { AgentsRepo } = await import("../../repository/agentsRepo");
    const { resolveTrustedRegisteredAgentExecuteUrlByCluster } = await import(
      "../../util/trusted-agent"
    );

    AgentsRepo.upsertAgent({
      Namespace: "psc-agent",
      Cluster: "cluster-a",
      environment: "hml",
    });

    expect(
      resolveTrustedRegisteredAgentExecuteUrlByCluster("cluster-b"),
    ).toBeNull();
  });

  test("prefers exact cluster/namespace matches when available", async () => {
    const { AgentsRepo } = await import("../../repository/agentsRepo");
    const { resolveTrustedRegisteredAgentExecuteTarget } = await import(
      "../../util/trusted-agent"
    );

    AgentsRepo.upsertAgent({
      Namespace: "psc-agent",
      Cluster: "cluster-a",
      environment: "hml",
    });
    AgentsRepo.upsertAgent({
      Namespace: "target-ns",
      Cluster: "cluster-a",
      environment: "hml",
    });

    expect(
      resolveTrustedRegisteredAgentExecuteTarget({
        cluster: "cluster-a",
        namespace: "target-ns",
      }),
    ).toEqual({
      agentUrl: "https://agent.cluster-a.svc.local/agent/execute",
      cluster: "cluster-a",
      namespace: "target-ns",
      lookupStrategy: "cluster+namespace",
    });
  });

  test("falls back to cluster when target namespace is not the registered agent namespace", async () => {
    const { AgentsRepo } = await import("../../repository/agentsRepo");
    const { resolveTrustedRegisteredAgentExecuteTarget } = await import(
      "../../util/trusted-agent"
    );

    AgentsRepo.upsertAgent({
      Namespace: "psc-agent",
      Cluster: "cluster-a",
      environment: "hml",
    });

    expect(
      resolveTrustedRegisteredAgentExecuteTarget({
        cluster: "cluster-a",
        namespace: "some-target-ns",
      }),
    ).toEqual({
      agentUrl: "https://agent.cluster-a.svc.local/agent/execute",
      cluster: "cluster-a",
      namespace: "psc-agent",
      lookupStrategy: "cluster",
    });
  });
});
