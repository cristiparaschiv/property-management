-- Migration 007: Add login_attempts table for rate limiting
-- This table tracks login attempts for brute force protection

CREATE TABLE IF NOT EXISTS login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45) NOT NULL,  -- IPv6 compatible
    username VARCHAR(255),
    is_successful BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_ip_created (ip_address, created_at),
    INDEX idx_ip_success_created (ip_address, is_successful, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
