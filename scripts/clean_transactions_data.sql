-- Clean slate script for transactions table
-- This will delete ALL transaction data to ensure clean user isolation
-- Run this in your Supabase SQL Editor BEFORE running the user_id migration

-- WARNING: This will permanently delete all transaction/financial data
-- Make sure you have a backup if needed

-- Delete all transactions data
DELETE FROM transactions;