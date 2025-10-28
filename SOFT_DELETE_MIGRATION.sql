-- 📋 Soft Delete Migration for Menu Items
-- This script adds the deleted_at column to enable soft delete functionality

-- Add deleted_at column to menu_items table
ALTER TABLE menu_items
ADD COLUMN deleted_at TIMESTAMPTZ NULL;

-- Add an index on deleted_at for better query performance
CREATE INDEX idx_menu_items_deleted_at ON menu_items(deleted_at);

-- Add a comment to document the column
COMMENT ON COLUMN menu_items.deleted_at IS 'Timestamp when the menu item was soft deleted. NULL means item is active.';

-- Optional: Add a check constraint to ensure soft-deleted items are unavailable
-- ALTER TABLE menu_items
-- ADD CONSTRAINT chk_soft_deleted_unavailable
-- CHECK (deleted_at IS NULL OR available_status = 0);

-- Verify the column was added successfully
\d menu_items;