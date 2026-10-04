import express from "express";

const app = express();
const port = Number(process.env.PORT ?? 4100);
const host = process.env.HOST ?? "0.0.0.0";

app.use(express.json());

app.get("/health", (_request, response) => {
  response.json({ ok: true, service: "mock-ota" });
});

app.get("/status", (_request, response) => {
  response.json({ service: "mock-ota", connected: true });
});

app.post("/reservations", (request, response) => {
  response.status(201).json({
    service: "mock-ota",
    externalReservationId: `OTA-${Date.now()}`,
    received: request.body,
  });
});

app.listen(port, host, () => {
  console.log(`Mock OTA listening on http://${host}:${port}`);
});
