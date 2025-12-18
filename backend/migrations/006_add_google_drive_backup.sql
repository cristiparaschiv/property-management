-- ============================================================================
-- Migration: Add Google Drive Backup Integration
-- ============================================================================
-- Creates tables for Google Drive OAuth configuration and backup history

-- Google Drive Configuration Table (single row - app-wide config)
CREATE TABLE IF NOT EXISTS google_drive_config (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    access_token TEXT NULL,
    refresh_token TEXT NULL,
    token_expiry DATETIME NULL,
    folder_id VARCHAR(255) NULL COMMENT 'Google Drive folder ID for backups',
    folder_name VARCHAR(255) NULL,
    connected_email VARCHAR(255) NULL,
    connected_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backup History Table
CREATE TABLE IF NOT EXISTS backup_history (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    drive_file_id VARCHAR(255) NULL COMMENT 'Google Drive file ID',
    file_size BIGINT UNSIGNED NULL,
    status ENUM('pending', 'creating', 'uploading', 'completed', 'failed') NOT NULL DEFAULT 'pending',
    error_message TEXT NULL,
    backup_type ENUM('manual', 'scheduled') NOT NULL DEFAULT 'manual',
    created_by INT UNSIGNED NULL,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_backup_status (status),
    INDEX idx_backup_created (created_at),

    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert initial empty config row
INSERT INTO google_drive_config (id) VALUES (1);
