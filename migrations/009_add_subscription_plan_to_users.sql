-- Migration 009: Add subscription_plan to users table
-- This adds subscription plan functionality at the user level

-- Add subscription_plan column to users table
ALTER TABLE users ADD COLUMN subscription_plan TEXT DEFAULT 'free' CHECK (subscription_plan IN ('free', 'basic', 'premium', 'enterprise'));

-- Create index for subscription_plan queries
CREATE INDEX IF NOT EXISTS idx_users_subscription_plan ON users(subscription_plan);

-- Update SQLite schema version to 9 (will be handled in database_helper.dart)