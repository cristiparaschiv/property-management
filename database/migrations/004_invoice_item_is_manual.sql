-- Distinguish manually-added invoice line items (corrections) from the
-- system-generated base lines. Only manual lines may be deleted.
ALTER TABLE `invoice_items`
  ADD COLUMN `is_manual` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '1 = added manually after generation (deletable); 0 = system-generated base line'
  AFTER `sort_order`;
