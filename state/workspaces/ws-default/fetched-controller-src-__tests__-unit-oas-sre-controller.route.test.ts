import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import express from "express";
import request from "supertest";
import jwt from "jsonwebtoken";

jest.setTimeout(15000);

describe("POST /oas/sre-controller", () => {
  const originalEnv = { ...process.env };
  const fetchMock = jest.fn();
  const JWT_SECRET = process.env.JWT_SECRET || "router-test-secret";
  const EXECUTE_SCOPE =
    process.env.SCOPE_EXECUTE_AUTOMATION || "scope:test:execute";
  const READ_SCOPE = process.env.SCOPE_READ_STATUS || "scope:test:read";
  let tmpDir = "";
  let dbPath = "";

  async function makeApp() {
    const { default: oasRouter } = await import("../../routes/oasRouter");
    const app = express();
    app.use(express.json());
    app.use("/oas", oasRouter);
    return app;
  }

  function bearer(scopes: string[]): string {
    const token = jwt.sign({ sub: "tester", scope: scopes }, JWT_SECRET, {
      algorithm: "HS256",
      expiresIn: "10m",
    });
    return `Bearer ${token}`;
  }

  function jsonResponse(status: number, body: unknown): Response {
    return {
      status,
      ok: status >= 200 && status < 300,
      headers: {
        get: (name: string) => {
          if (name.toLowerCase() === "content-type") {
            return "application/json";
          }
          return null;
        },
      },
      json: async () => body,
      text: async () => JSON.stringify(body),
    } as unknown as Response;
  }

  function buildFunctionPayload(
    overrides: Partial<{
      execId: string;
      cluster: string;
      namespace: string;
      function: string;
      envs: Record<string, unknown>;
    }> = {},
  ) {
    return {
      execId: "550e8400-e29b-41d4-a716-446655440000",
      cluster: "k8shmlbb111b",
      namespace: "meu-namespace",
      function: "get_pods",
      ...overrides,
    };
  }

  beforeEach(async () => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "oas-sre-route-"));
    dbPath = path.join(tmpDir, "test.db");
    process.env.JWT_SECRET = JWT_SECRET;
    process.env.SCOPE_EXECUTE_AUTOMATION = EXECUTE_SCOPE;
    process.env.SCOPE_READ_STATUS = READ_SCOPE;
    process.env.DB_PATH = dbPath;

    process.env.OAS_TRUSTED_NAMESPACE = "sgh-oaas-playbook-jobs";
    process.env.OAS_TRUSTED_SERVICE_ACCOUNT = "default";
    process.env.TECHBB_TRUSTED_NAMESPACE = "sgh-oaas-playbook-jobs";
    process.env.TECHBB_TRUSTED_SERVICE_ACCOUNT = "default";

    process.env.OAS_ORIGIN_NAMESPACE_HEADERS =
      "x-techbb-namespace,x-k8s-namespace,x-origin-namespace,x-namespace";
    process.env.OAS_ORIGIN_SERVICE_ACCOUNT_HEADERS =
      "x-techbb-service-account,x-k8s-service-account,x-origin-service-account,x-service-account,x-service-account-name";

    process.env.AGENT_BASE_URL = "http://agent.local";
    process.env.AGENT_BASE_URL_TEMPLATE = "";
    process.env.AGENT_EXECUTE_URL = "";
    process.env.AGENT_EXECUTE_URL_TEMPLATE = "";

    fetchMock.mockReset();
    fetchMock.mockResolvedValue(jsonResponse(200, { message: "ok" }));
    (global as unknown as { fetch: typeof fetch }).fetch =
      fetchMock as unknown as typeof fetch;

    jest.resetModules();

    const { AgentsRepo } = await import("../../repository/agentsRepo");
    [
      { Namespace: "teste", Cluster: "k8scluster01", environment: "hml" },
      { Namespace: "teste", Cluster: "cluster-a", environment: "hml" },
      { Namespace: "teste", Cluster: "cluster-b", environment: "hml" },
      { Namespace: "teste", Cluster: "cluster-origem", environment: "hml" },
      { Namespace: "teste", Cluster: "cluster-destino", environment: "hml" },
      {
        Namespace: "meu-namespace",
        Cluster: "k8shmlbb111b",
        environment: "hml",
      },
      {
        Namespace: "psc-sre-dummy-migration",
        Cluster: "k8shmlbb111",
        environment: "hml",
      },
      {
        Namespace: "psc-sre-dummy-migration",
        Cluster: "k8shmlbb111b",
        environment: "hml",
      },
    ].forEach((agent) => {
      AgentsRepo.upsertAgent(agent);
    });
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // Best-effort cleanup for temp dir.
    }
  });

  test("requires JWT when request is not from trusted internal origin", async () => {
    const app = await makeApp();
    const res = await request(app).post("/oas/sre-controller").send({
      image: "psc-sre-ns-migration-preflight",
      envs: { NAMESPACE: "teste" },
      CLUSTERS_NAMES: ["k8scluster01"],
    });

    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: "Unauthorized" });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("accepts request without JWT for trusted internal origin headers", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("x-techbb-namespace", "sgh-oaas-playbook-jobs")
      .set("x-techbb-service-account", "default")
      .set("x-namespace", "sgh-oaas-playbook-jobs")
      .set("x-service-account", "default")
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.authMode).toBe("internal-origin");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  test("requires execute scope when JWT is provided for external origin", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([READ_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(403);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("accepts JWT with execute scope and dispatches to all clusters", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    fetchMock
      .mockResolvedValueOnce(jsonResponse(200, { message: "cluster-a" }))
      .mockResolvedValueOnce(jsonResponse(200, { message: "cluster-b" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: {
          CLUSTER_DE_ORIGEM: true,
          CLUSTER_DE_DESTINO: false,
          NAMESPACE: "teste",
        },
        CLUSTERS_NAMES: ["cluster-a", "cluster-b"],
      });

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.mode).toBe("async");
    expect(res.body.clustersNames).toEqual(["cluster-a", "cluster-b"]);
    expect(res.body.dispatches).toHaveLength(2);
    expect(fetchMock).toHaveBeenCalledTimes(2);

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    expect(callBody.image).toBe("psc-sre-ns-migration-preflight");
    expect(callBody.cluster).toBe("cluster-a");
    const envs = callBody.envs as Record<string, unknown>;
    expect(envs.CLUSTER_DE_ORIGEM).toBe(true);
    expect(envs.NAMESPACE).toBe("teste");
  });

  test("dispatches to a single cluster with custom envs via template URL", async () => {
    process.env.AGENT_EXECUTE_URL = "";
    process.env.AGENT_EXECUTE_URL_TEMPLATE = "";
    process.env.AGENT_BASE_URL_TEMPLATE = "http://agent.{cluster}.svc.local";

    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: {
          NAMESPACE: ["vip-autorizador-auditoria-transacoes"],
          CLUSTER_DE_ORIGEM: true,
          CLUSTER_DE_DESTINO: false,
        },
        CLUSTERS_NAMES: ["cluster-origem"],
      });

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const calledUrl = String(
      (fetchMock.mock.calls[0] as [string, RequestInit])[0],
    );
    expect(calledUrl).toBe(
      "http://agent.cluster-origem.svc.local/agent/execute",
    );

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    const envs = callBody.envs as Record<string, unknown>;
    expect(Array.isArray(envs.NAMESPACE)).toBe(true);
    expect(callBody.image).toBe("psc-sre-ns-migration-preflight");
  });

  test("accepts function=get_pods", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const payload = buildFunctionPayload();
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(payload);

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.execId).toBe(payload.execId);
    expect(res.body.function).toBe("get_pods");
    expect(res.body.cluster).toBe("k8shmlbb111b");
    expect(res.body.namespace).toBe("meu-namespace");
    expect(res.body.clustersNames).toEqual(["k8shmlbb111b"]);

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    expect(callBody.execId).toBe(payload.execId);
    expect(callBody.cluster).toBe("k8shmlbb111b");
    expect(callBody.namespace).toBe("meu-namespace");
    expect(callBody.function).toBe("get_pods");
  });

  test("accepts function=get_all_resources", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(buildFunctionPayload({ function: "get_all_resources" }));

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.function).toBe("get_all_resources");

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    expect(callBody.function).toBe("get_all_resources");
  });

  test.each([
    "migration_origem",
    "migration_destino",
    "migration",
    "manage_namespace_origem",
    "manage_namespace_destino",
  ])("keeps existing function %s valid", async (functionName) => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(buildFunctionPayload({ function: functionName }));

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.function).toBe(functionName);

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    expect(callBody.function).toBe(functionName);
  });

  test("accepts copy_resources_origem with ACTION=copy", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_origem",
          envs: {
            ACTION: "copy",
            NAMESPACE_ENVIRONMENT: "hml",
            RESOURCE_TYPES: "secrets,configmaps",
          },
        }),
      );

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.function).toBe("copy_resources_origem");

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    const envs = callBody.envs as Record<string, unknown>;
    expect(callBody.function).toBe("copy_resources_origem");
    expect(envs.ACTION).toBe("copy");
    expect(envs.NAMESPACE_ENVIRONMENT).toBe("hml");
    expect(envs.RESOURCE_TYPES).toBe("secrets,configmaps");
  });

  test("accepts copy_resources_destino with ACTION=apply and defaults RESOURCE_TYPES", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111b",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_destino",
          envs: {
            ACTION: "apply",
            NAMESPACE_ENVIRONMENT: "hml",
          },
        }),
      );

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);
    expect(res.body.function).toBe("copy_resources_destino");

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    const envs = callBody.envs as Record<string, unknown>;
    expect(envs.ACTION).toBe("apply");
    expect(envs.NAMESPACE_ENVIRONMENT).toBe("hml");
    expect(envs.RESOURCE_TYPES).toBe("secrets,configmaps");
  });

  test("accepts copy_resources_origem with ACTION=remove", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_origem",
          envs: {
            ACTION: "remove",
            NAMESPACE_ENVIRONMENT: "hml",
            RESOURCE_TYPES: "secrets",
          },
        }),
      );

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    const envs = callBody.envs as Record<string, unknown>;
    expect(envs.ACTION).toBe("remove");
    expect(envs.RESOURCE_TYPES).toBe("secrets");
  });

  test("rejects copy_resources payload when envs is missing", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_origem",
        }),
      );

    expect(res.status).toBe(400);
    expect(res.body.details).toContain(
      "Field 'envs' is required for function 'copy_resources_origem'.",
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects copy_resources payload without NAMESPACE_ENVIRONMENT", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_origem",
          envs: {
            ACTION: "copy",
          },
        }),
      );

    expect(res.status).toBe(400);
    expect(res.body.details).toContain(
      "Field 'envs.NAMESPACE_ENVIRONMENT' is required for function 'copy_resources_origem'.",
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects copy_resources payload with invalid ACTION", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(
        buildFunctionPayload({
          cluster: "k8shmlbb111b",
          namespace: "psc-sre-dummy-migration",
          function: "copy_resources_destino",
          envs: {
            ACTION: "rename",
            NAMESPACE_ENVIRONMENT: "hml",
          },
        }),
      );

    expect(res.status).toBe(400);
    expect(res.body.details).toContain(
      "Field 'envs.ACTION' has invalid value 'rename'. Allowed values: copy, apply, remove.",
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects unknown function names", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send(buildFunctionPayload({ function: "funcao_inexistente" }));

    expect(res.status).toBe(400);
    expect(res.body.details[0]).toContain(
      "Function funcao_inexistente is not recognized.",
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects payload when image is not in allowlist", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "ubuntu:latest",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects payload when envs field is missing", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(400);
    expect(Array.isArray(res.body.details)).toBe(true);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects payload when CLUSTERS_NAMES is missing", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
      });

    expect(res.status).toBe(400);
    expect(Array.isArray(res.body.details)).toBe(true);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("returns 502 when agent rejects one cluster", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    fetchMock.mockResolvedValueOnce(
      jsonResponse(503, { error: "agent unavailable" }),
    );

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
    expect(res.body.agentStatus).toBe(503);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  test("returns 504 when agent dispatch times out", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";
    process.env.AGENT_CALL_TIMEOUT_MS = "1234";
    const abortError = Object.assign(new Error("aborted"), {
      name: "AbortError",
    });

    fetchMock.mockRejectedValueOnce(abortError);

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(res.status).toBe(504);
    expect(res.body.ok).toBe(false);
    expect(res.body.error).toBe("Timed out while waiting for Agent response");
    expect(res.body.detail).toBe("No response from Agent after 1234ms");
  });

  test("accepts envs passed under legacy 'variables' key", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        variables: { NAMESPACE: "teste", SOME_FLAG: true },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(202);
    expect(res.body.ok).toBe(true);

    const callBody = JSON.parse(
      String((fetchMock.mock.calls[0] as [string, RequestInit])[1].body),
    ) as Record<string, unknown>;
    const envs = callBody.envs as Record<string, unknown>;
    expect(envs.NAMESPACE).toBe("teste");
    expect(envs.SOME_FLAG).toBe(true);
  });

  test("supports sync mode and waits for final execution state", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    const { pushAgentExecutionLogs } = await import(
      "../../controllers/agents-execute-logs.controller"
    );

    let capturedExecId = "";

    // Push DONE logs from within the fetch mock so the execution state is
    // already DONE before waitForFinalExecution is called — avoids a race
    // condition where the supertest request has not yet started when the
    // setTimeout fires, leaving fetchMock.mock.calls[0] undefined.
    fetchMock.mockImplementationOnce(
      async (_url: unknown, init: unknown) => {
        const body = JSON.parse(
          String((init as RequestInit).body),
        ) as Record<string, unknown>;
        capturedExecId = String(body.execId);

        const req = {
          body: {
            execId: capturedExecId,
            entries: [
              {
                ts: "2026-03-19T10:00:00-03:00",
                status: "DONE",
                level: "info",
                message: "completed",
              },
            ],
          },
          query: {},
          header: () => undefined,
          agentCallbackJwt: { execId: capturedExecId },
        } as unknown;

        const statusCode = jest.fn();
        const json = jest.fn();
        const resMock = {
          status: statusCode.mockReturnThis(),
          json,
        } as unknown;

        await pushAgentExecutionLogs(req as never, resMock as never);

        return jsonResponse(200, { message: "ok" });
      },
    );

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller?mode=sync")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    const [calledUrl] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(calledUrl).toContain("/agent/execute");
    expect(fetchMock).toHaveBeenCalledTimes(1);

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.mode).toBe("sync");
    expect(res.body.execId).toBe(capturedExecId);
    expect(res.body.status).toBe("DONE");
    expect(res.body.finished).toBe(true);
    expect(Array.isArray(res.body.entries)).toBe(true);
  });

  test("returns 502 in sync mode when the callback finishes with ERROR", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";

    const { pushAgentExecutionLogs } = await import(
      "../../controllers/agents-execute-logs.controller"
    );

    let capturedExecId = "";

    fetchMock.mockImplementationOnce(
      async (_url: unknown, init: unknown) => {
        const body = JSON.parse(
          String((init as RequestInit).body),
        ) as Record<string, unknown>;
        capturedExecId = String(body.execId);

        const req = {
          body: {
            execId: capturedExecId,
            entries: [
              {
                ts: "2026-03-19T10:05:00-03:00",
                status: "ERROR",
                level: "error",
                message: "automation failed",
              },
            ],
          },
          query: {},
          header: () => undefined,
          agentCallbackJwt: { execId: capturedExecId },
        } as unknown;

        const statusCode = jest.fn();
        const json = jest.fn();
        const resMock = {
          status: statusCode.mockReturnThis(),
          json,
        } as unknown;

        await pushAgentExecutionLogs(req as never, resMock as never);

        return jsonResponse(200, { message: "ok" });
      },
    );

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller?mode=sync")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
    expect(res.body.error).toBe("EXECUTION_ERROR");
    expect(res.body.mode).toBe("sync");
    expect(res.body.execId).toBe(capturedExecId);
    expect(res.body.status).toBe("ERROR");
    expect(res.body.finished).toBe(true);
  });

  test("returns 504 in sync mode when execution does not finish before timeout", async () => {
    process.env.AGENT_EXECUTE_URL = "http://agent.local/agent/execute";
    process.env.SYNC_TIMEOUT_MS = "20";

    fetchMock.mockResolvedValueOnce(jsonResponse(200, { message: "ok" }));

    const app = await makeApp();
    const res = await request(app)
      .post("/oas/sre-controller?mode=sync")
      .set("Authorization", bearer([EXECUTE_SCOPE]))
      .send({
        image: "psc-sre-ns-migration-preflight",
        envs: { NAMESPACE: "teste" },
        CLUSTERS_NAMES: ["k8scluster01"],
      });

    expect(res.status).toBe(504);
    expect(res.body.ok).toBe(false);
    expect(res.body.mode).toBe("sync");
    expect(res.body.error).toBe("TIMEOUT");
    expect(res.body.finished).toBe(false);
  });
});
