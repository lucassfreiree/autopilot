/**
 * Unit tests for patches/cronjob-result.controller.ts
 *
 * Covers:
 *  - validateCronjobResult (exercised via receiveCronjobResult handler)
 *  - mapComplianceStatusToExecStatus
 *  - adaptCronjobResultToLogEntries
 *  - receiveCronjobResult handler: 200 / 400 / 500
 *  - getCronjobStatus handler: 200 / 400 / 500
 */

import type { Request as ExpressRequest, Response as ExpressResponse } from "express";

// ── Mocks (declared before any module import) ──────────────────────────────

const mockInitExecution = jest.fn();
const mockPushAgentExecutionLogs = jest.fn();
const mockGetExecutionSnapshot = jest.fn();

jest.mock("../../controllers/agents-execute-logs.controller", () => ({
  initExecution: (...args: unknown[]) => mockInitExecution(...args),
  pushAgentExecutionLogs: (...args: unknown[]) =>
    mockPushAgentExecutionLogs(...args),
  getExecutionSnapshot: (...args: unknown[]) =>
    mockGetExecutionSnapshot(...args),
}));

jest.mock("../../util/time", () => ({
  timestampSP: () => "2024-01-01T00:00:00.000Z",
}));

// ── Helpers ────────────────────────────────────────────────────────────────

function makeReq(
  body: unknown = {},
  params: Record<string, string> = {},
): ExpressRequest {
  return { body, params, query: {} } as unknown as ExpressRequest;
}

function makeRes() {
  const res: Partial<ExpressResponse> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as ExpressResponse;
}

function validSuccessBody() {
  return {
    compliance_status: "success",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-001",
    captured_data: { key: "value" },
  };
}

function validFailedBody() {
  return {
    compliance_status: "failed",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-002",
    failures: [{ reason: "step-1 failed" }],
  };
}

function validErrorBody() {
  return {
    compliance_status: "error",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-003",
    errors: [{ message: "unexpected exception" }],
  };
}

function makeSnapshot(execId = "exec-001") {
  return {
    ok: true,
    execId,
    status: "DONE" as const,
    statusLabel: "Done",
    finished: true,
    lastUpdate: "2024-01-01T00:00:00.000Z",
    count: 1,
    entries: [{ ts: "2024-01-01T00:00:00.000Z", status: "DONE" }],
  };
}

// ────────────────────────────────────────────────────────────────────────────
// validateCronjobResult — exercised through receiveCronjobResult
// ────────────────────────────────────────────────────────────────────────────

describe("validateCronjobResult — via receiveCronjobResult", () => {
  beforeEach(() => {
    jest.resetModules();
    mockInitExecution.mockReturnValue(undefined);
    mockPushAgentExecutionLogs.mockImplementation(
      async (_req: unknown, res: ExpressResponse) => {
        res.status(202).json({ ok: true });
      },
    );
  });

  test("accepts valid success payload (200)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(true);
    expect(body.indexed).toBe(true);
    expect(body.execId).toBe("exec-001");
    expect(body.compliance_status).toBe("success");
  });

  test("accepts valid failed payload (200)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validFailedBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.compliance_status).toBe("failed");
  });

  test("accepts valid error payload (200)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validErrorBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.compliance_status).toBe("error");
  });

  test("rejects body missing compliance_status (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).compliance_status;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(false);
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("compliance_status")]),
    );
  });

  test("rejects invalid compliance_status value (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq({ ...validSuccessBody(), compliance_status: "unknown" });
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  test("rejects body missing namespace (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).namespace;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("namespace")]),
    );
  });

  test("rejects body missing cluster_type (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).cluster_type;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  test("rejects body missing timestamp (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).timestamp;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  test("rejects body missing execId (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).execId;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("execId")]),
    );
  });

  test("rejects success body missing captured_data (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validSuccessBody() };
    delete (payload as Record<string, unknown>).captured_data;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("captured_data")]),
    );
  });

  test("rejects failed body missing failures (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validFailedBody() };
    delete (payload as Record<string, unknown>).failures;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("failures")]),
    );
  });

  test("rejects error body missing errors (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const payload = { ...validErrorBody() };
    delete (payload as Record<string, unknown>).errors;
    const req = makeReq(payload);
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
  });

  test("rejects non-object body (400)", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq("not-an-object");
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("JSON object")]),
    );
  });
});

// ────────────────────────────────────────────────────────────────────────────
// mapComplianceStatusToExecStatus
// ────────────────────────────────────────────────────────────────────────────

describe("mapComplianceStatusToExecStatus — indirect via adaptCronjobResultToLogEntries", () => {
  test("success → log entry has status DONE and level INFO", async () => {
    mockInitExecution.mockReturnValue(undefined);
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(capturedEntries.length).toBeGreaterThan(0);
    const entry = capturedEntries[0] as Record<string, unknown>;
    expect(entry.status).toBe("DONE");
    expect(entry.level).toBe("INFO");
    expect(entry.execStatus).toBe("DONE");
  });

  test("failed → log entry has status ERROR and level ERROR", async () => {
    jest.resetModules();
    mockInitExecution.mockReturnValue(undefined);
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validFailedBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    const entry = capturedEntries[0] as Record<string, unknown>;
    expect(entry.status).toBe("ERROR");
    expect(entry.level).toBe("ERROR");
  });

  test("error → log entry has status ERROR", async () => {
    jest.resetModules();
    mockInitExecution.mockReturnValue(undefined);
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validErrorBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    const entry = capturedEntries[0] as Record<string, unknown>;
    expect(entry.status).toBe("ERROR");
  });
});

// ────────────────────────────────────────────────────────────────────────────
// adaptCronjobResultToLogEntries — field verification
// ────────────────────────────────────────────────────────────────────────────

describe("adaptCronjobResultToLogEntries — field verification", () => {
  beforeEach(() => {
    jest.resetModules();
    mockInitExecution.mockReturnValue(undefined);
  });

  test("success entry contains ts, execId, source, from, level, status, message, data.captured_data", async () => {
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    const entry = capturedEntries[0] as Record<string, unknown>;
    expect(entry).toMatchObject({
      execId: "exec-001",
      source: "cronjob-callback",
      from: "agent",
      level: "INFO",
      status: "DONE",
      execStatus: "DONE",
    });
    expect(typeof entry.ts).toBe("string");
    expect(typeof entry.message).toBe("string");
    const data = entry.data as Record<string, unknown>;
    expect(data.captured_data).toEqual({ key: "value" });
  });

  test("failed entry contains data.failures", async () => {
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validFailedBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    const entry = capturedEntries[0] as Record<string, unknown>;
    const data = entry.data as Record<string, unknown>;
    expect(data.failures).toEqual([{ reason: "step-1 failed" }]);
  });

  test("error entry contains data.errors", async () => {
    let capturedEntries: unknown[] = [];
    mockPushAgentExecutionLogs.mockImplementation(
      async (req: ExpressRequest, res: ExpressResponse) => {
        capturedEntries = (req.body as Record<string, unknown>)
          .entries as unknown[];
        res.status(202).json({ ok: true });
      },
    );

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validErrorBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    const entry = capturedEntries[0] as Record<string, unknown>;
    const data = entry.data as Record<string, unknown>;
    expect(data.errors).toEqual([{ message: "unexpected exception" }]);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// receiveCronjobResult handler
// ────────────────────────────────────────────────────────────────────────────

describe("receiveCronjobResult handler", () => {
  beforeEach(() => {
    jest.resetModules();
    mockInitExecution.mockReturnValue(undefined);
    mockPushAgentExecutionLogs.mockImplementation(
      async (_req: unknown, res: ExpressResponse) => {
        res.status(202).json({ ok: true });
      },
    );
  });

  test("returns 200 with indexed:true and statusEndpoint on success", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(true);
    expect(body.indexed).toBe(true);
    expect(body.statusEndpoint).toContain("exec-001");
  });

  test("calls initExecution with the execId", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(mockInitExecution).toHaveBeenCalledWith("exec-001");
  });

  test("calls pushAgentExecutionLogs with adapted entries", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(mockPushAgentExecutionLogs).toHaveBeenCalledTimes(1);
  });

  test("returns 400 for invalid payload", async () => {
    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq({ compliance_status: "success" });
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(false);
  });

  test("returns 500 when pushAgentExecutionLogs throws", async () => {
    mockPushAgentExecutionLogs.mockRejectedValue(new Error("storage failure"));

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(false);
  });

  test("returns 500 when initExecution throws", async () => {
    mockInitExecution.mockImplementation(() => {
      throw new Error("init failure");
    });

    const { receiveCronjobResult } = await import(
      "../../controllers/cronjob-result.controller"
    );
    const req = makeReq(validSuccessBody());
    const res = makeRes();
    await receiveCronjobResult(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// getCronjobStatus handler
// ────────────────────────────────────────────────────────────────────────────

describe("getCronjobStatus handler", () => {
  beforeEach(() => {
    jest.resetModules();
  });

  test("returns 200 with snapshot fields when execId is valid", async () => {
    mockGetExecutionSnapshot.mockResolvedValue(makeSnapshot("exec-001"));

    const { getCronjobStatus } = await import("../../controllers/cronjob-result.controller");
    const req = makeReq({}, { execId: "exec-001" });
    const res = makeRes();
    await getCronjobStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(true);
    expect(body.execId).toBe("exec-001");
    expect(body.status).toBe("DONE");
    expect(body.statusLabel).toBe("Done");
    expect(body.finished).toBe(true);
    expect(body.count).toBe(1);
    expect(Array.isArray(body.entries)).toBe(true);
  });

  test("returns 400 when execId param is absent", async () => {
    const { getCronjobStatus } = await import("../../controllers/cronjob-result.controller");
    const req = makeReq({}, {});
    const res = makeRes();
    await getCronjobStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(false);
    expect(body.error).toMatch(/execId/i);
  });

  test("returns 500 when getExecutionSnapshot throws", async () => {
    mockGetExecutionSnapshot.mockRejectedValue(new Error("snapshot not found"));

    const { getCronjobStatus } = await import("../../controllers/cronjob-result.controller");
    const req = makeReq({}, { execId: "exec-unknown" });
    const res = makeRes();
    await getCronjobStatus(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    const body = (res.json as jest.Mock).mock.calls[0][0];
    expect(body.ok).toBe(false);
  });
});
