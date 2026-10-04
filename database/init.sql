CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS properties (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  nightly_price INTEGER NOT NULL CHECK (nightly_price >= 0)
);

CREATE INDEX IF NOT EXISTS properties_city_idx ON properties(city);

INSERT INTO properties (name, city, nightly_price)
SELECT
  'Property ' || number,
  CASE number % 3 WHEN 0 THEN 'HCM' WHEN 1 THEN 'HANOI' ELSE 'DANANG' END,
  500000 + (number % 30) * 100000
FROM generate_series(1, 100000) AS number
WHERE NOT EXISTS (SELECT 1 FROM properties LIMIT 1);

CREATE TABLE IF NOT EXISTS units (
  id BIGSERIAL PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id),
  name TEXT NOT NULL
);

INSERT INTO units (property_id, name)
SELECT id, 'Room 101'
FROM properties
WHERE id <= 100
  AND NOT EXISTS (SELECT 1 FROM units LIMIT 1);

CREATE TABLE IF NOT EXISTS reservations (
  id BIGSERIAL PRIMARY KEY,
  unit_id BIGINT NOT NULL REFERENCES units(id),
  guest_name TEXT NOT NULL,
  stay DATERANGE NOT NULL,
  status TEXT NOT NULL DEFAULT 'CONFIRMED',
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  EXCLUDE USING gist (
    unit_id WITH =,
    stay WITH &&
  ) WHERE (status IN ('PENDING', 'CONFIRMED', 'CHECKED_IN'))
);
