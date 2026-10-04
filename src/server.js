import express from "express";
import pg from "pg";

const { Pool } = pg;
const port = Number(process.env.PORT ?? 4000);
const host = process.env.HOST ?? "127.0.0.1";
const instanceId = process.env.INSTANCE_ID ?? `local-${process.pid}`;
const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ??
    "postgres://lab:lab@127.0.0.1:55432/capacity_lab",
  max: Number(process.env.DB_POOL_SIZE ?? 20),
});

const app = express();
app.use(express.json());
app.use((_request, response, next) => {
  response.setHeader("x-instance-id", instanceId);
  next();
});

app.get("/health", (_request, response) => {
  response.json({ ok: true, instanceId });
});

app.get("/properties/:id", async (request, response, next) => {
  try {
    const result = await pool.query(
      "SELECT id, name, city, nightly_price FROM properties WHERE id = $1",
      [request.params.id],
    );

    if (result.rowCount === 0) {
      return response.status(404).json({ error: "Property not found" });
    }

    return response.json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
});

app.get("/search", async (request, response, next) => {
  try {
    const city = String(request.query.city ?? "HCM");
    const limit = Math.min(Number(request.query.limit ?? 20), 100);
    const result = await pool.query(
      `SELECT id, name, city, nightly_price
       FROM properties
       WHERE city = $1
       ORDER BY nightly_price, id
       LIMIT $2`,
      [city, limit],
    );
    return response.json({ count: result.rowCount, items: result.rows });
  } catch (error) {
    return next(error);
  }
});

app.delete("/reservations", async (_request, response, next) => {
  try {
    await pool.query("TRUNCATE reservations RESTART IDENTITY");
    return response.status(204).send();
  } catch (error) {
    return next(error);
  }
});

app.post("/reservations", async (request, response, next) => {
  const { unitId, guestName, checkIn, checkOut, idempotencyKey } = request.body;

  if (!unitId || !guestName || !checkIn || !checkOut || !idempotencyKey) {
    return response.status(400).json({ error: "Missing required fields" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO reservations
         (unit_id, guest_name, stay, idempotency_key)
       VALUES ($1, $2, daterange($3::date, $4::date, '[)'), $5)
       RETURNING id, unit_id, guest_name, stay, status, created_at`,
      [unitId, guestName, checkIn, checkOut, idempotencyKey],
    );
    return response.status(201).json(result.rows[0]);
  } catch (error) {
    if (error.code === "23P01") {
      return response.status(409).json({ error: "Room is already booked" });
    }
    if (error.code === "23505") {
      return response.status(409).json({ error: "Request already processed" });
    }
    return next(error);
  }
});

app.get("/stats", async (_request, response, next) => {
  try {
    const [database, reservations] = await Promise.all([
      pool.query(
        `SELECT numbackends, xact_commit, xact_rollback,
                blks_read, blks_hit, tup_returned, tup_fetched
         FROM pg_stat_database WHERE datname = current_database()`,
      ),
      pool.query("SELECT count(*)::int AS total FROM reservations"),
    ]);
    return response.json({
      application: {
        pid: process.pid,
        uptimeSeconds: Math.round(process.uptime()),
        memoryMB: Math.round(process.memoryUsage().rss / 1024 / 1024),
        pool: {
          total: pool.totalCount,
          idle: pool.idleCount,
          waiting: pool.waitingCount,
        },
      },
      database: database.rows[0],
      reservations: reservations.rows[0].total,
    });
  } catch (error) {
    return next(error);
  }
});

app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({ error: "Internal server error" });
});

const server = app.listen(port, host, () => {
  console.log(`Capacity lab ${instanceId} listening on http://${host}:${port}`);
});

let shuttingDown = false;

async function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;

  server.close();
  await pool.end();
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
