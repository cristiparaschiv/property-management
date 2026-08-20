-- Migration 008: Personal loans ledger
--
-- Tracks money lent to a person and paid back in instalments, with an optional
-- monthly offset (e.g. accounting services credited against the debt).
--
-- Sign convention: amount < 0 is money advanced, amount > 0 is money repaid.
-- The outstanding balance is therefore the negated sum of loan_entries.amount.
--
-- Re-runnable: deploy applies every *.sql on each release, so the tables use
-- IF NOT EXISTS and the seed rows use INSERT IGNORE against unique keys.

CREATE TABLE IF NOT EXISTS loans (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    person       VARCHAR(255) NOT NULL COMMENT 'Who owes the money',
    currency     CHAR(3) NOT NULL DEFAULT 'RON',
    offset_label VARCHAR(100) NULL COMMENT 'Name of the monthly offset, e.g. Servicii contabile',
    offset_rate  DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT 'Monthly amount credited against the debt; 0 disables',
    offset_start DATE NULL COMMENT 'First month the offset accrues',
    notes        TEXT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_loan_person (person),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS loan_entries (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    loan_id    INT UNSIGNED NOT NULL,
    entry_date DATE NOT NULL,
    label      VARCHAR(255) NOT NULL COMMENT 'Cash, Revolut, invoice number...',
    amount     DECIMAL(12,2) NOT NULL COMMENT 'Negative = advanced, positive = repaid',
    note       TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    -- Also what makes the seed below safe to re-apply.
    UNIQUE KEY uq_loan_entry (loan_id, entry_date, label, amount),
    INDEX idx_loan_date (loan_id, entry_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Seed: the Sile ledger as at 03.07.2026
-- 5 advances totalling 236.918,00 and 11 repayments totalling 120.000,00,
-- leaving 116.918,00 outstanding before the accounting-services offset.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO loans (person, currency, offset_label, offset_rate, offset_start, notes)
VALUES ('Sile', 'RON', 'Servicii contabile', 700.00, '2025-01-01',
        'Împrumut acordat prin facturi CPPI24, rambursat în tranșe.');

INSERT IGNORE INTO loan_entries (loan_id, entry_date, label, amount)
SELECT l.id, d.entry_date, d.label, d.amount
FROM loans l
JOIN (
    SELECT '2024-09-20' AS entry_date, 'FF CPPI24 0055' AS label, -125000.00 AS amount
    UNION ALL SELECT '2024-09-26', 'FF CPPI24 0059',  -19653.00
    UNION ALL SELECT '2024-10-16', 'FF CPPI24 0060',  -35365.00
    UNION ALL SELECT '2024-10-28', 'FF CPPI24 0061',  -11900.00
    UNION ALL SELECT '2024-11-28', 'FF CPPI24 0062',  -45000.00
    UNION ALL SELECT '2025-05-06', 'Cash',             20000.00
    UNION ALL SELECT '2025-05-06', 'Revolut',           5000.00
    UNION ALL SELECT '2025-08-01', 'Revolut',          15000.00
    UNION ALL SELECT '2025-10-08', 'Cash',             10000.00
    UNION ALL SELECT '2025-12-29', 'Cash',              5000.00
    UNION ALL SELECT '2026-03-20', 'Cash',             10000.00
    UNION ALL SELECT '2026-04-06', 'Cash',             10000.00
    UNION ALL SELECT '2026-05-06', 'Cash',             10000.00
    UNION ALL SELECT '2026-05-18', 'Cash',             10000.00
    UNION ALL SELECT '2026-06-18', 'Cash',             15000.00
    UNION ALL SELECT '2026-07-03', 'Cash',             10000.00
) AS d
WHERE l.person = 'Sile';
