-- ========================================
-- HYBRID SYNC DATABASE SCHEMA CHANGES
-- ========================================
-- This file contains all database changes needed for the hybrid sync solution
-- Run these commands in your Supabase SQL editor

-- Step 1: Create sync metadata table
CREATE TABLE IF NOT EXISTS sync_metadata (
  key TEXT PRIMARY KEY,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 2: Insert initial sync records
INSERT INTO sync_metadata (key, version)
VALUES ('orders_last_updated', 1)
ON CONFLICT (key) DO NOTHING;

-- Step 3: Create function to update sync timestamp
CREATE OR REPLACE FUNCTION update_orders_sync_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE sync_metadata
  SET
    last_updated = NOW(),
    version = version + 1
  WHERE key = 'orders_last_updated';

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create triggers for orders table
DROP TRIGGER IF EXISTS trigger_orders_sync ON orders;
CREATE TRIGGER trigger_orders_sync
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_orders_sync_timestamp();

-- Step 5: Create triggers for order_items table
DROP TRIGGER IF EXISTS trigger_order_items_sync ON order_items;
CREATE TRIGGER trigger_order_items_sync
  AFTER INSERT OR UPDATE OR DELETE ON order_items
  FOR EACH ROW EXECUTE FUNCTION update_orders_sync_timestamp();

-- Step 6: Add RPC functions for atomic operations
CREATE OR REPLACE FUNCTION rpc_get_sync_metadata(sync_key TEXT)
RETURNS TABLE(last_updated TIMESTAMPTZ, version INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT sm.last_updated, sm.version
  FROM sync_metadata sm
  WHERE sm.key = sync_key;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create RPC for atomic order item completion update
CREATE OR REPLACE FUNCTION rpc_update_order_item_completion(
  p_order_id TEXT,
  p_item_id TEXT,
  p_is_completed BOOLEAN
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  -- Update the order item
  UPDATE order_items
  SET
    is_completed = p_is_completed,
    completed_at = CASE
      WHEN p_is_completed THEN NOW()
      ELSE NULL
    END
  WHERE id = p_item_id::INTEGER
    AND order_id = p_order_id::INTEGER;

  -- Update the parent order's updated_at timestamp
  UPDATE orders
  SET updated_at = NOW()
  WHERE id = p_order_id::INTEGER;

  -- Return success result
  SELECT json_build_object(
    'success', true,
    'item_id', p_item_id,
    'order_id', p_order_id,
    'is_completed', p_is_completed,
    'updated_at', NOW()
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create RPC for batch order operations (future enhancement)
CREATE OR REPLACE FUNCTION rpc_batch_update_items(
  operations JSON
)
RETURNS JSON AS $$
DECLARE
  operation JSON;
  success_count INTEGER := 0;
  error_count INTEGER := 0;
  results JSON[] := '{}';
BEGIN
  -- Process each operation in the batch
  FOR operation IN SELECT * FROM json_array_elements(operations)
  LOOP
    BEGIN
      -- Handle item completion updates
      IF operation->>'type' = 'item_completion' THEN
        UPDATE order_items
        SET
          is_completed = (operation->>'is_completed')::BOOLEAN,
          completed_at = CASE
            WHEN (operation->>'is_completed')::BOOLEAN THEN NOW()
            ELSE NULL
          END
        WHERE id = (operation->>'item_id')::INTEGER;

        UPDATE orders
        SET updated_at = NOW()
        WHERE id = (operation->>'order_id')::INTEGER;

        success_count := success_count + 1;
      END IF;

    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      results := results || json_build_object(
        'operation', operation,
        'error', SQLERRM
      );
    END;
  END LOOP;

  RETURN json_build_object(
    'success_count', success_count,
    'error_count', error_count,
    'errors', results
  );
END;
$$ LANGUAGE plpgsql;

-- Step 9: Create index for performance
CREATE INDEX IF NOT EXISTS idx_sync_metadata_key ON sync_metadata(key);
CREATE INDEX IF NOT EXISTS idx_orders_updated_at ON orders(updated_at);
CREATE INDEX IF NOT EXISTS idx_order_items_completed ON order_items(is_completed, completed_at);

-- Step 10: Grant permissions (adjust as needed for your setup)
-- GRANT SELECT, UPDATE ON sync_metadata TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_get_sync_metadata(TEXT) TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_update_order_item_completion(TEXT, TEXT, BOOLEAN) TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_batch_update_items(JSON) TO authenticated;

-- Verification queries (run these to test)
-- SELECT * FROM sync_metadata;
-- SELECT rpc_get_sync_metadata('orders_last_updated');
-- SELECT rpc_update_order_item_completion('1', '1', true);