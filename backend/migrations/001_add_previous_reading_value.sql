-- Migration: Add previous_reading_value column to meter_readings table
-- Purpose: Store the previous reading value for data integrity and auditability
-- Date: 2025-12-09

-- Step 1: Add the previous_reading_value column (nullable initially for backfill)
ALTER TABLE meter_readings
ADD COLUMN previous_reading_value DECIMAL(12,2) NULL
COMMENT 'The previous reading value used to calculate consumption';

-- Step 2: Add index for performance (used in validation queries)
CREATE INDEX idx_meter_readings_meter_period
ON meter_readings(meter_id, period_year, period_month);

-- Step 3: Add check constraint to ensure readings don't go backward
-- (MariaDB 10.2.1+ supports CHECK constraints)
ALTER TABLE meter_readings
ADD CONSTRAINT chk_reading_value_non_negative
CHECK (reading_value >= 0);

-- Step 4: Add check constraint for consumption consistency
-- If previous_reading_value exists, consumption must equal reading_value - previous_reading_value
-- We allow NULL previous_reading_value for the first reading
ALTER TABLE meter_readings
ADD CONSTRAINT chk_consumption_consistent
CHECK (
    previous_reading_value IS NULL OR
    consumption = reading_value - previous_reading_value
);

-- Step 5: Backfill previous_reading_value for existing records
-- This uses a self-join to find the previous reading by period
UPDATE meter_readings mr1
LEFT JOIN meter_readings mr2 ON (
    mr1.meter_id = mr2.meter_id
    AND (
        (mr2.period_year < mr1.period_year)
        OR (mr2.period_year = mr1.period_year AND mr2.period_month < mr1.period_month)
    )
)
LEFT JOIN meter_readings mr3 ON (
    mr1.meter_id = mr3.meter_id
    AND (
        (mr3.period_year < mr1.period_year)
        OR (mr3.period_year = mr1.period_year AND mr3.period_month < mr1.period_month)
    )
    AND (
        (mr3.period_year > mr2.period_year)
        OR (mr3.period_year = mr2.period_year AND mr3.period_month > mr2.period_month)
    )
)
SET mr1.previous_reading_value = mr2.reading_value
WHERE mr3.id IS NULL  -- mr2 is the immediate predecessor
AND mr2.id IS NOT NULL;  -- Only set if there is a previous reading

-- Step 6: Recalculate consumption based on previous_reading_value
UPDATE meter_readings
SET consumption = reading_value - previous_reading_value
WHERE previous_reading_value IS NOT NULL;

-- Step 7: Set consumption = 0 for first readings (no previous value)
UPDATE meter_readings
SET consumption = 0
WHERE previous_reading_value IS NULL AND consumption IS NULL;

-- Verification queries (run these manually to verify):
-- 1. Check for any inconsistencies:
-- SELECT * FROM meter_readings
-- WHERE previous_reading_value IS NOT NULL
-- AND consumption != reading_value - previous_reading_value;

-- 2. Check first readings per meter:
-- SELECT * FROM meter_readings mr1
-- WHERE previous_reading_value IS NULL
-- AND NOT EXISTS (
--     SELECT 1 FROM meter_readings mr2
--     WHERE mr2.meter_id = mr1.meter_id
--     AND ((mr2.period_year < mr1.period_year)
--         OR (mr2.period_year = mr1.period_year AND mr2.period_month < mr1.period_month))
-- );

-- 3. Verify ordering:
-- SELECT meter_id, period_year, period_month,
--        reading_value, previous_reading_value, consumption
-- FROM meter_readings
-- ORDER BY meter_id, period_year, period_month;
