const [url, concurrencyInput = "50", durationInput = "10"] = process.argv.slice(2);

if (!url) {
  console.error("Usage: node scripts/load.js <url> [concurrency] [duration-seconds]");
  process.exit(1);
}

const concurrency = Number(concurrencyInput);
const durationSeconds = Number(durationInput);

if (!Number.isInteger(concurrency) || concurrency < 1) {
  throw new Error("Concurrency must be a positive integer");
}

if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
  throw new Error("Duration must be greater than zero");
}

const deadline = performance.now() + durationSeconds * 1_000;
const latencies = [];
let successfulRequests = 0;
let failedRequests = 0;

async function runWorker() {
  while (performance.now() < deadline) {
    const startedAt = performance.now();

    try {
      const response = await fetch(url);
      await response.arrayBuffer();

      if (response.ok) successfulRequests += 1;
      else failedRequests += 1;
    } catch {
      failedRequests += 1;
    } finally {
      latencies.push(performance.now() - startedAt);
    }
  }
}

const testStartedAt = performance.now();
await Promise.all(Array.from({ length: concurrency }, () => runWorker()));
const elapsedSeconds = (performance.now() - testStartedAt) / 1_000;

latencies.sort((left, right) => left - right);

function percentile(value) {
  if (latencies.length === 0) return 0;
  const index = Math.min(
    latencies.length - 1,
    Math.ceil((value / 100) * latencies.length) - 1,
  );
  return latencies[index];
}

const totalRequests = successfulRequests + failedRequests;
const result = {
  url,
  concurrency,
  durationSeconds: Number(elapsedSeconds.toFixed(2)),
  totalRequests,
  successfulRequests,
  failedRequests,
  requestsPerSecond: Number((totalRequests / elapsedSeconds).toFixed(2)),
  latencyMs: {
    p50: Number(percentile(50).toFixed(2)),
    p95: Number(percentile(95).toFixed(2)),
    p99: Number(percentile(99).toFixed(2)),
  },
};

console.log(JSON.stringify(result, null, 2));

if (failedRequests > 0) {
  process.exitCode = 1;
}
