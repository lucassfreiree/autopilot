import type { Request, Response } from "express";
import os from "os";
import fs from "fs";
import path from "path";
import { timestampSP } from "../util/time";
import { notifyTraceChanged } from "../util/s3logger";

type Locals = { requestId?: string };

let appVersion = "0.0.0";
try {
  const pkgRaw = fs.readFileSync(path.join(process.cwd(), "package.json"), "utf-8");
  const pkg = JSON.parse(pkgRaw) as { version?: string };
  if (pkg.version) appVersion = pkg.version;
} catch {
  // fallback to default
}

export async function getInfo(_req: Request, res: Response): Promise<void> {
  const id = `info-${Date.now().toString(36)}`;
  try {
    const requestId = String((res.locals as unknown as Locals).requestId || "");
    console.log("[info] id=%s requestId=%s", id, requestId);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[info] log-error: %s", msg);
  }

  notifyTraceChanged();

  res.status(200).json({
    ok: true,
    success: true,
    id,
    service: "psc-sre-automacao-controller",
    version: appVersion,
    hostname: os.hostname(),
    now: timestampSP(),
    timezone: "America/Sao_Paulo",
    note: "All endpoints return an id field.",
  });
}
