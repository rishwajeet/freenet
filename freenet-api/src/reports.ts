import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";
import type { Env } from "./index";

const CONFIRMATION_THRESHOLD = 5;
const RATE_LIMIT_MAX = 100;

const reportSchema = z.object({
  domain: z.string().min(1).max(253),
  country: z.string().length(2),
  failureType: z.string().min(1).max(50),
  timestamp: z.string().datetime(),
  appVersion: z.string().min(1).max(20),
});

export const reports = new Hono<Env>();

/**
 * Hash an IP address for privacy-preserving rate limiting.
 * Uses a simple hash since we don't need cryptographic strength here —
 * just consistent bucketing. In production, rotate salt daily.
 */
function hashIP(ip: string): string {
  let hash = 0;
  for (let i = 0; i < ip.length; i++) {
    const char = ip.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return "ip_" + Math.abs(hash).toString(36);
}

function currentHourWindow(): string {
  const now = new Date();
  now.setMinutes(0, 0, 0);
  return now.toISOString();
}

// POST /api/reports — Receive a block report
reports.post("/", zValidator("json", reportSchema), async (c) => {
  const body = c.req.valid("json");
  const db = c.env.DB;

  const clientIP = c.req.header("cf-connecting-ip") || c.req.header("x-forwarded-for") || "unknown";
  const ipHash = hashIP(clientIP);
  const window = currentHourWindow();

  // Rate limit check
  const rateRow = await db
    .prepare("SELECT count FROM rate_limits WHERE ip_hash = ? AND window_start = ?")
    .bind(ipHash, window)
    .first<{ count: number }>();

  if (rateRow && rateRow.count >= RATE_LIMIT_MAX) {
    return c.json({ error: "Rate limit exceeded. Max 100 reports per hour." }, 429);
  }

  // Upsert rate limit counter
  await db
    .prepare(
      `INSERT INTO rate_limits (ip_hash, window_start, count)
       VALUES (?, ?, 1)
       ON CONFLICT(ip_hash, window_start) DO UPDATE SET count = count + 1`
    )
    .bind(ipHash, window)
    .run();

  // Insert report
  await db
    .prepare(
      `INSERT INTO reports (domain, country, failure_type, timestamp, app_version, ip_hash)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
    .bind(body.domain, body.country, body.failureType, body.timestamp, body.appVersion, ipHash)
    .run();

  // Check if domain has crossed confirmation threshold for this country
  await maybeConfirmDomain(db, body.domain, body.country, body.failureType);

  return c.json({ accepted: true }, 201);
});

/**
 * If a domain has enough reports from a country, add/update it in confirmed_domains.
 */
async function maybeConfirmDomain(
  db: D1Database,
  domain: string,
  country: string,
  failureType: string
): Promise<void> {
  // Count distinct IPs reporting this domain in this country
  const result = await db
    .prepare(
      `SELECT COUNT(DISTINCT ip_hash) as unique_reporters
       FROM reports
       WHERE domain = ? AND country = ?`
    )
    .bind(domain, country)
    .first<{ unique_reporters: number }>();

  if (!result || result.unique_reporters < CONFIRMATION_THRESHOLD) {
    return;
  }

  // Total report count across all countries
  const totalResult = await db
    .prepare("SELECT COUNT(*) as total FROM reports WHERE domain = ?")
    .bind(domain)
    .first<{ total: number }>();

  const totalReports = totalResult?.total ?? 0;

  // Gather all countries reporting this domain
  const countryRows = await db
    .prepare("SELECT DISTINCT country FROM reports WHERE domain = ?")
    .bind(domain)
    .all<{ country: string }>();

  const countries = countryRows.results.map((r) => r.country);

  // Confidence: ratio of unique reporters to threshold, capped at 1.0
  const uniqueGlobal = await db
    .prepare("SELECT COUNT(DISTINCT ip_hash) as cnt FROM reports WHERE domain = ?")
    .bind(domain)
    .first<{ cnt: number }>();

  const confidence = Math.min((uniqueGlobal?.cnt ?? 0) / (CONFIRMATION_THRESHOLD * 2), 1.0);

  // Upsert confirmed domain
  await db
    .prepare(
      `INSERT INTO confirmed_domains (domain, classification, failure_type, report_count, countries, confidence, confirmed_at, updated_at)
       VALUES (?, 'crowd-reported', ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(domain) DO UPDATE SET
         failure_type = excluded.failure_type,
         report_count = excluded.report_count,
         countries = excluded.countries,
         confidence = excluded.confidence,
         updated_at = datetime('now')`
    )
    .bind(domain, failureType, totalReports, JSON.stringify(countries), confidence)
    .run();

  // Bump blocklist version for affected countries
  for (const c of countries) {
    await db
      .prepare(
        `INSERT INTO blocklist_versions (country, version, updated_at)
         VALUES (?, 1, datetime('now'))
         ON CONFLICT(country) DO UPDATE SET
           version = version + 1,
           updated_at = datetime('now')`
      )
      .bind(c)
      .run();
  }
}
