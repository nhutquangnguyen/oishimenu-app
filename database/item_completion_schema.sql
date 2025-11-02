-- ========================================
-- ORDER ITEM COMPLETION STATUS SCHEMA
-- ========================================
-- This file adds item completion tracking to the existing order system
-- Run these commands in your Supabase SQL editor

-- Step 1: Add completion tracking columns to order_items table
ALTER TABLE public.order_items
ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT false NOT NULL,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES public.users(id);

-- Step 2: Create index for performance (if not already exists)
CREATE INDEX IF NOT EXISTS idx_order_items_completion
ON public.order_items(order_id, is_completed, completed_at);

-- Step 3: Create function to update order timestamp when items are completed
CREATE OR REPLACE FUNCTION update_order_on_item_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the parent order's updated_at timestamp when item completion changes
  UPDATE public.orders
  SET updated_at = NOW()
  WHERE id = NEW.order_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create trigger for automatic order timestamp update
DROP TRIGGER IF EXISTS trigger_update_order_on_item_completion ON public.order_items;
CREATE TRIGGER trigger_update_order_on_item_completion
  AFTER UPDATE OF is_completed ON public.order_items
  FOR EACH ROW
  WHEN (OLD.is_completed IS DISTINCT FROM NEW.is_completed)
  EXECUTE FUNCTION update_order_on_item_completion();

-- Step 5: Create improved RPC function for atomic item completion updates (fixes UUID casting bug)
CREATE OR REPLACE FUNCTION rpc_update_order_item_completion(
  p_order_id UUID,
  p_item_id UUID,
  p_is_completed BOOLEAN,
  p_completed_by UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  result JSON;
  item_exists BOOLEAN;
BEGIN
  -- Check if the item exists and belongs to the order
  SELECT EXISTS(
    SELECT 1 FROM public.order_items
    WHERE id = p_item_id AND order_id = p_order_id
  ) INTO item_exists;

  IF NOT item_exists THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order item not found or does not belong to the specified order',
      'item_id', p_item_id,
      'order_id', p_order_id
    );
  END IF;

  -- Update the order item completion status
  UPDATE public.order_items
  SET
    is_completed = p_is_completed,
    completed_at = CASE
      WHEN p_is_completed THEN NOW()
      ELSE NULL
    END,
    completed_by = CASE
      WHEN p_is_completed THEN p_completed_by
      ELSE NULL
    END
  WHERE id = p_item_id AND order_id = p_order_id;

  -- Return success result
  SELECT json_build_object(
    'success', true,
    'item_id', p_item_id,
    'order_id', p_order_id,
    'is_completed', p_is_completed,
    'completed_at', CASE WHEN p_is_completed THEN NOW() ELSE NULL END,
    'completed_by', CASE WHEN p_is_completed THEN p_completed_by ELSE NULL END
  ) INTO result;

  RETURN result;
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'item_id', p_item_id,
    'order_id', p_order_id
  );
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create function to get completion statistics for an order
CREATE OR REPLACE FUNCTION rpc_get_order_completion_stats(p_order_id UUID)
RETURNS JSON AS $$
DECLARE
  total_items INTEGER;
  completed_items INTEGER;
  completion_percentage DECIMAL(5,2);
  result JSON;
BEGIN
  -- Get total and completed item counts
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE is_completed = true)
  INTO total_items, completed_items
  FROM public.order_items
  WHERE order_id = p_order_id;

  -- Calculate completion percentage
  completion_percentage := CASE
    WHEN total_items = 0 THEN 0
    ELSE ROUND((completed_items::DECIMAL / total_items) * 100, 2)
  END;

  SELECT json_build_object(
    'order_id', p_order_id,
    'total_items', total_items,
    'completed_items', completed_items,
    'remaining_items', total_items - completed_items,
    'completion_percentage', completion_percentage,
    'is_fully_completed', (completed_items = total_items AND total_items > 0)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create function for batch item completion updates
CREATE OR REPLACE FUNCTION rpc_batch_update_item_completion(
  operations JSON,
  p_completed_by UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  operation JSON;
  success_count INTEGER := 0;
  error_count INTEGER := 0;
  errors JSON[] := '{}';
  total_operations INTEGER;
BEGIN
  -- Count total operations
  SELECT json_array_length(operations) INTO total_operations;

  -- Process each operation in the batch
  FOR operation IN SELECT * FROM json_array_elements(operations)
  LOOP
    BEGIN
      -- Handle item completion updates
      IF operation->>'type' = 'item_completion' THEN
        UPDATE public.order_items
        SET
          is_completed = (operation->>'is_completed')::BOOLEAN,
          completed_at = CASE
            WHEN (operation->>'is_completed')::BOOLEAN THEN NOW()
            ELSE NULL
          END,
          completed_by = CASE
            WHEN (operation->>'is_completed')::BOOLEAN THEN p_completed_by
            ELSE NULL
          END
        WHERE id = (operation->>'item_id')::UUID
          AND order_id = (operation->>'order_id')::UUID;

        IF FOUND THEN
          success_count := success_count + 1;
        ELSE
          error_count := error_count + 1;
          errors := errors || json_build_object(
            'operation', operation,
            'error', 'Order item not found'
          );
        END IF;
      ELSE
        error_count := error_count + 1;
        errors := errors || json_build_object(
          'operation', operation,
          'error', 'Unknown operation type'
        );
      END IF;

    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      errors := errors || json_build_object(
        'operation', operation,
        'error', SQLERRM
      );
    END;
  END LOOP;

  RETURN json_build_object(
    'total_operations', total_operations,
    'success_count', success_count,
    'error_count', error_count,
    'success_rate', CASE
      WHEN total_operations = 0 THEN 0
      ELSE ROUND((success_count::DECIMAL / total_operations) * 100, 2)
    END,
    'errors', errors
  );
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create a view for easy querying of order completion status
CREATE OR REPLACE VIEW order_completion_summary AS
SELECT
  o.id as order_id,
  o.order_number,
  o.status as order_status,
  COUNT(oi.id) as total_items,
  COUNT(oi.id) FILTER (WHERE oi.is_completed = true) as completed_items,
  COUNT(oi.id) FILTER (WHERE oi.is_completed = false) as remaining_items,
  CASE
    WHEN COUNT(oi.id) = 0 THEN 0
    ELSE ROUND((COUNT(oi.id) FILTER (WHERE oi.is_completed = true)::DECIMAL / COUNT(oi.id)) * 100, 2)
  END as completion_percentage,
  (COUNT(oi.id) FILTER (WHERE oi.is_completed = true) = COUNT(oi.id) AND COUNT(oi.id) > 0) as is_fully_completed,
  MAX(oi.completed_at) as last_item_completed_at,
  o.created_at,
  o.updated_at
FROM public.orders o
LEFT JOIN public.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, o.status, o.created_at, o.updated_at;

-- Step 9: Update existing hybrid sync triggers to include item completion changes
-- (The existing triggers in hybrid_sync_schema.sql will automatically handle this)

-- Step 10: Grant permissions for the new functions
-- Uncomment and customize these based on your authentication setup
-- GRANT EXECUTE ON FUNCTION rpc_update_order_item_completion(UUID, UUID, BOOLEAN, UUID) TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_get_order_completion_stats(UUID) TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_batch_update_item_completion(JSON, UUID) TO authenticated;
-- GRANT SELECT ON order_completion_summary TO authenticated;

-- Step 11: Create some useful indexes for performance
CREATE INDEX IF NOT EXISTS idx_order_items_completed_by ON public.order_items(completed_by);
CREATE INDEX IF NOT EXISTS idx_order_items_completed_at ON public.order_items(completed_at);

-- ========================================
-- VERIFICATION QUERIES
-- ========================================
-- Run these queries to verify the schema was applied correctly:

-- 1. Check if columns were added
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'order_items' AND table_schema = 'public'
-- ORDER BY ordinal_position;

-- 2. Test the completion update function
-- SELECT rpc_update_order_item_completion(
--   (SELECT id FROM orders LIMIT 1),
--   (SELECT id FROM order_items LIMIT 1),
--   true,
--   (SELECT id FROM users LIMIT 1)
-- );

-- 3. Test the completion stats function
-- SELECT rpc_get_order_completion_stats((SELECT id FROM orders LIMIT 1));

-- 4. Check the completion summary view
-- SELECT * FROM order_completion_summary LIMIT 5;

-- ========================================
-- SAMPLE DATA FOR TESTING
-- ========================================
-- Uncomment these lines if you want to create sample data for testing:

-- Update some random order items to be completed for testing
-- UPDATE public.order_items
-- SET
--   is_completed = true,
--   completed_at = NOW(),
--   completed_by = (SELECT id FROM public.users LIMIT 1)
-- WHERE id IN (
--   SELECT id FROM public.order_items
--   ORDER BY RANDOM()
--   LIMIT 3
-- );