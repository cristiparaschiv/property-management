-- ============================================================================
-- Search Performance Indexes
-- ============================================================================
--
-- These indexes optimize the global search endpoint performance
-- Endpoint: GET /api/search?q={query}
--
-- Run this script after implementing the search endpoint:
--   mysql -u user -p database_name < sql/search-indexes.sql
--
-- Or manually create indexes using your database management tool
-- ============================================================================

-- Tenants table indexes
-- Improves search performance on: name, email, phone
CREATE INDEX IF NOT EXISTS idx_tenants_name ON tenants(name);
CREATE INDEX IF NOT EXISTS idx_tenants_email ON tenants(email);
CREATE INDEX IF NOT EXISTS idx_tenants_phone ON tenants(phone);

-- Invoices table indexes
-- Improves search performance on: invoice_number, client_name
-- Also adds index on invoice_date for result ordering
CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_client_name ON invoices(client_name);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(invoice_date);

-- Utility Providers table indexes
-- Improves search performance on: name, account_number
CREATE INDEX IF NOT EXISTS idx_utility_providers_name ON utility_providers(name);
CREATE INDEX IF NOT EXISTS idx_utility_providers_account ON utility_providers(account_number);

-- ============================================================================
-- Verify Indexes
-- ============================================================================
--
-- To verify indexes were created, run:
--
-- MySQL:
--   SHOW INDEX FROM tenants WHERE Key_name LIKE 'idx_%';
--   SHOW INDEX FROM invoices WHERE Key_name LIKE 'idx_%';
--   SHOW INDEX FROM utility_providers WHERE Key_name LIKE 'idx_%';
--
-- PostgreSQL:
--   \di tenants
--   \di invoices
--   \di utility_providers
--
-- SQLite:
--   .indices tenants
--   .indices invoices
--   .indices utility_providers
--
-- ============================================================================

-- ============================================================================
-- Performance Notes
-- ============================================================================
--
-- 1. LIKE queries with leading wildcards (%value%) cannot use indexes
--    efficiently, but these indexes still help with query optimization
--
-- 2. For better performance with LIKE queries, consider:
--    - Full-text search (MySQL FULLTEXT, PostgreSQL FTS)
--    - Specialized search engines (Elasticsearch, Solr)
--    - Trigram indexes (PostgreSQL pg_trgm extension)
--
-- 3. Monitor query performance with:
--    - EXPLAIN SELECT queries
--    - Slow query logs
--    - Database performance monitoring tools
--
-- 4. Index maintenance:
--    - Indexes are automatically maintained by the database
--    - Rebuild indexes periodically if fragmentation occurs
--    - Monitor index usage and remove unused indexes
--
-- ============================================================================

-- ============================================================================
-- Alternative: Full-Text Search (MySQL)
-- ============================================================================
--
-- For better search performance with large datasets, consider full-text search:
--
-- ALTER TABLE tenants ADD FULLTEXT INDEX ft_tenants_search (name, email, phone);
-- ALTER TABLE invoices ADD FULLTEXT INDEX ft_invoices_search (invoice_number, client_name);
-- ALTER TABLE utility_providers ADD FULLTEXT INDEX ft_providers_search (name, account_number);
--
-- Then modify search queries to use MATCH() AGAINST():
-- SELECT * FROM tenants WHERE MATCH(name, email, phone) AGAINST('search_term' IN NATURAL LANGUAGE MODE);
--
-- ============================================================================

-- ============================================================================
-- Alternative: Trigram Indexes (PostgreSQL)
-- ============================================================================
--
-- For PostgreSQL with pg_trgm extension (better LIKE '%...%' performance):
--
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
--
-- CREATE INDEX idx_tenants_name_trgm ON tenants USING gin(name gin_trgm_ops);
-- CREATE INDEX idx_tenants_email_trgm ON tenants USING gin(email gin_trgm_ops);
-- CREATE INDEX idx_tenants_phone_trgm ON tenants USING gin(phone gin_trgm_ops);
--
-- CREATE INDEX idx_invoices_number_trgm ON invoices USING gin(invoice_number gin_trgm_ops);
-- CREATE INDEX idx_invoices_client_trgm ON invoices USING gin(client_name gin_trgm_ops);
--
-- CREATE INDEX idx_providers_name_trgm ON utility_providers USING gin(name gin_trgm_ops);
-- CREATE INDEX idx_providers_account_trgm ON utility_providers USING gin(account_number gin_trgm_ops);
--
-- ============================================================================

-- End of search-indexes.sql
