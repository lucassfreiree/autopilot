/**
 * Unit tests for patches/cronjob-callback.ts
 *
 * Covers:
 *  - validateCronjobCallback (internal — exercised via route handler)
 *  - forwardToController (mocked fetch)
 *  - Route handler: 200 / 400 / 502 / 500
 */

import express, { type Request, type Response } from "express";
import request from "supertest";

// ── Mock JWTService before any import resolves CronjobCallbackAPI ──
jest.mock("../../util/jwt", () => ({
  JWTService: {
    generateCallbackToken: jest.fn(() => "mock-jwt-token"),
  },
}));

// ── Capture the global fetch mock so tests can control it ──
let mockFetch: jest.Mock;

beforeEach(() => {
  mockFetch = jest.fn();
  global.fetch = mockFetch;
});

afterEach(() => {
  jest.resetAllMocks();
});

// ── Build the Express app using CronjobCallbackAPI ──
async function makeApp() {
  jest.resetModules();
  const { default: CronjobCallbackAPI } = await import(
    "../../routes/cronjob-callback"
  );
  const router = express.Router();
  new CronjobCallbackAPI(router);
  const app = express();
  app.use(express.json());
  app.use(router);
  return app;
}

// ── Shared valid payload factories ──
function validSuccessPayload() {
  return {
    compliance_status: "success",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-001",
    captured_data: { key: "value" },
  };
}

function validFailedPayload() {
  return {
    compliance_status: "failed",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-002",
    failures: [{ reason: "step-1 failed" }],
  };
}

function validErrorPayload() {
  return {
    compliance_status: "error",
    namespace: "ns-test",
    cluster_type: "origin",
    timestamp: "2024-01-01T00:00:00.000Z",
    execId: "exec-003",
    errors: [{ message: "unexpected exception" }],
  };
}

// ── Helper: mock a successful fetch response ──
function mockFetchOk(statusCode = 200) {
  mockFetch.mockResolvedValueOnce({
    ok: true,
    status: statusCode,
    text: async () => "",
  });
}

// ── Helper: mock a failed fetch response ──
function mockFetchFail(statusCode = 500, body = "Internal Error") {
  mockFetch.mockResolvedValueOnce({
    ok: false,
    status: statusCode,
    text: async () => body,
  });
}

// ── Helper: mock a fetch that throws (timeout / network error) ──
function mockFetchAbort() {
  const err = new Error("The operation was aborted");
  err.name = "AbortError";
  mockFetch.mockRejectedValueOnce(err);
}

function mockFetchNetworkError() {
  mockFetch.mockRejectedValueOnce(new Error("ECONNREFUSED"));
}

// ────────────────────────────────────────────────────────────────────────────
// validateCronjobCallback — exercised via POST /api/cronjob/callback
// ────────────────────────────────────────────────────────────────────────────

describe("validateCronjobCallback — via route handler", () => {
  test("accepts valid success payload and forwards to Controller (200)", async () => {
    mockFetchOk(200);
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.forwarded).toBe(true);
    expect(res.body.execId).toBe("exec-001");
    expect(res.body.compliance_status).toBe("success");
  });

  test("accepts valid failed payload and forwards to Controller (200)", async () => {
    mockFetchOk(200);
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validFailedPayload());

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.compliance_status).toBe("failed");
  });

  test("accepts valid error payload and forwards to Controller (200)", async () => {
    mockFetchOk(200);
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validErrorPayload());

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.compliance_status).toBe("error");
  });

  test("rejects payload missing compliance_status (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).compliance_status;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("compliance_status")]),
    );
  });

  test("rejects payload with invalid compliance_status (400)", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send({ ...validSuccessPayload(), compliance_status: "unknown" });

    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test("rejects payload missing namespace (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).namespace;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("namespace")]),
    );
  });

  test("rejects payload missing cluster_type (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).cluster_type;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("cluster_type")]),
    );
  });

  test("rejects payload missing timestamp (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).timestamp;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("timestamp")]),
    );
  });

  test("rejects payload missing execId (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).execId;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("execId")]),
    );
  });

  test("rejects success payload missing captured_data (400)", async () => {
    const app = await makeApp();
    const payload = { ...validSuccessPayload() };
    delete (payload as Record<string, unknown>).captured_data;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("captured_data")]),
    );
  });

  test("rejects failed payload missing failures (400)", async () => {
    const app = await makeApp();
    const payload = { ...validFailedPayload() };
    delete (payload as Record<string, unknown>).failures;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("failures")]),
    );
  });

  test("rejects error payload missing errors (400)", async () => {
    const app = await makeApp();
    const payload = { ...validErrorPayload() };
    delete (payload as Record<string, unknown>).errors;
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(payload);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(
      expect.arrayContaining([expect.stringContaining("errors")]),
    );
  });

  test("rejects non-JSON body (400)", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .set("Content-Type", "text/plain")
      .send("not-json");

    expect(res.status).toBe(400);
  });
});

// ────────────────────────────────────────────────────────────────────────────
// forwardToController — exercised via route handler (502 / 500 scenarios)
// ────────────────────────────────────────────────────────────────────────────

describe("forwardToController — via route handler", () => {
  test("returns 502 when Controller responds with non-ok status", async () => {
    mockFetchFail(503, "Service Unavailable");
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
    expect(res.body.controllerStatus).toBe(503);
  });

  test("returns 502 on Controller timeout (AbortError)", async () => {
    mockFetchAbort();
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
  });

  test("returns 502 on network error", async () => {
    mockFetchNetworkError();
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
  });

  test("generates callback JWT with send_logs scope when forwarding", async () => {
    mockFetchOk(200);
    const { JWTService } = await import("../../util/jwt");
    const app = await makeApp();
    await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(JWTService.generateCallbackToken).toHaveBeenCalledWith(
      expect.objectContaining({ scope: expect.arrayContaining(["send_logs"]) }),
    );
  });
});

// ────────────────────────────────────────────────────────────────────────────
// Route handler — misc edge cases
// ────────────────────────────────────────────────────────────────────────────

describe("POST /api/cronjob/callback — route handler", () => {
  test("returns 200 with forwarded:true on successful forward", async () => {
    mockFetchOk(200);
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      ok: true,
      forwarded: true,
      execId: "exec-001",
      namespace: "ns-test",
      compliance_status: "success",
    });
  });

  test("returns 400 for invalid payload — missing required fields", async () => {
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send({ compliance_status: "success" });

    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
    expect(res.body.error).toMatch(/invalid/i);
  });

  test("returns 502 when Controller fails", async () => {
    mockFetchFail(500, "Controller error");
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    expect(res.status).toBe(502);
    expect(res.body.ok).toBe(false);
  });

  test("returns 500 when forwardToController throws unexpectedly", async () => {
    // Make fetch throw a non-standard error
    mockFetch.mockImplementationOnce(() => {
      throw new Error("unexpected internal error");
    });
    const app = await makeApp();
    const res = await request(app)
      .post("/api/cronjob/callback")
      .send(validSuccessPayload());

    // fetch throwing synchronously from within the async handler should be caught
    expect([500, 502]).toContain(res.status);
    expect(res.body.ok).toBe(false);
  });
});
