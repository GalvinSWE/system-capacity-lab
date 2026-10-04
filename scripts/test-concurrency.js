const baseUrl = process.env.BASE_URL ?? "http://127.0.0.1:4000";
const competitors = Number(process.env.COMPETITORS ?? 50);

await fetch(`${baseUrl}/reservations`, { method: "DELETE" });

const startedAt = performance.now();
const results = await Promise.all(
  Array.from({ length: competitors }, async (_, index) => {
    const response = await fetch(`${baseUrl}/reservations`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        unitId: 1,
        guestName: `Guest ${index + 1}`,
        checkIn: "2027-01-10",
        checkOut: "2027-01-15",
        idempotencyKey: `concurrency-${Date.now()}-${index}`,
      }),
    });
    return response.status;
  }),
);

const counts = results.reduce((summary, status) => {
  summary[status] = (summary[status] ?? 0) + 1;
  return summary;
}, {});

const elapsed = Math.round(performance.now() - startedAt);
console.log(`Đã gửi ${competitors} request đồng thời trong ${elapsed} ms`);
console.log("Kết quả theo HTTP status:", counts);

if (counts[201] !== 1 || counts[409] !== competitors - 1) {
  console.error("FAIL: invariant chống double booking không được bảo vệ");
  process.exit(1);
}

console.log("PASS: chỉ một booking thành công, các request còn lại bị từ chối");
