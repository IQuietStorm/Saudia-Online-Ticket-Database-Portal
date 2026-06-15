-- SQL Query to Update User Role to Admin in Supabase
-- Use this in Supabase SQL Editor

-- 1. UPDATE SINGLE USER TO ADMIN by email
UPDATE public.profiles
SET 
  role = 'admin',
  user_role = 'admin'
WHERE LOWER(email) = LOWER('user@saudia.com')
RETURNING id, email, role, user_role;


-- 2. UPDATE SINGLE USER TO ADMIN by user ID
UPDATE public.profiles
SET 
  role = 'admin',
  user_role = 'admin'
WHERE id = 'USER_UUID_HERE'
RETURNING id, email, role, user_role;


-- 3. UPDATE MULTIPLE USERS TO ADMIN by email list
UPDATE public.profiles
SET 
  role = 'admin',
  user_role = 'admin'
WHERE LOWER(email) IN (
  'admin1@saudia.com',
  'admin2@saudia.com',
  'admin3@saudia.com'
)
RETURNING id, email, role, user_role;


-- 4. PROMOTE ALL SUPERVISORS TO ADMIN
UPDATE public.profiles
SET 
  role = 'admin',
  user_role = 'admin'
WHERE LOWER(role) = 'supervisor' OR LOWER(user_role) = 'supervisor'
RETURNING id, email, role, user_role;


-- 5. VIEW CURRENT ROLES (VERIFY BEFORE/AFTER)
SELECT 
  id, 
  email, 
  role, 
  user_role,
  created_at
FROM public.profiles
ORDER BY created_at DESC;


-- 6. BULK UPDATE: Set all users to a specific role (CAUTION: Use carefully!)
-- UPDATE public.profiles
-- SET role = 'admin', user_role = 'admin'
-- RETURNING id, email, role, user_role;




-- ============================================================================
-- TEMPORARY SUPERVISOR ROLE MANAGEMENT QUERIES
-- ============================================================================
-- Use these queries to manage temporary supervisor role assignments with
-- automatic expiration dates. Temporary supervisors retain full supervisor
-- privileges until their assigned end date.

-- 8. CREATE TEMPORARY SUPERVISOR (30 days from today)
-- Assigns supervisor role with automatic expiration in 30 days
UPDATE public.profiles
SET 
  role = 'supervisor',
  user_role = 'supervisor',
  temp_supervisor_start = NOW()::date,
  temp_supervisor_end = (NOW() + INTERVAL '30 days')::date,
  is_temporary = true,
  updated_at = NOW()
WHERE LOWER(email) = LOWER('username@saudia.com')
RETURNING id, email, role, temp_supervisor_start, temp_supervisor_end, is_temporary;


-- 9. CREATE TEMPORARY SUPERVISOR WITH CUSTOM TIMEFRAME
-- Assigns supervisor role for a specific date range
UPDATE public.profiles
SET 
  role = 'supervisor',
  user_role = 'supervisor',
  temp_supervisor_start = '2026-06-15'::date,
  temp_supervisor_end = '2026-07-15'::date,
  is_temporary = true,
  updated_at = NOW()
WHERE LOWER(email) = LOWER('username@saudia.com')
RETURNING id, email, role, temp_supervisor_start, temp_supervisor_end, is_temporary;


-- 10. CONVERT TEMPORARY SUPERVISOR TO PERMANENT
-- Removes expiration date from a temporary supervisor role
UPDATE public.profiles
SET 
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false,
  updated_at = NOW()
WHERE LOWER(email) = LOWER('username@saudia.com')
RETURNING id, email, role, temp_supervisor_start, temp_supervisor_end, is_temporary;


-- 11. EXTEND TEMPORARY SUPERVISOR EXPIRATION (Add 30 more days)
-- Extends the current supervisor role by an additional period
UPDATE public.profiles
SET 
  temp_supervisor_end = (temp_supervisor_end + INTERVAL '30 days')::date,
  updated_at = NOW()
WHERE LOWER(email) = LOWER('username@saudia.com') 
  AND is_temporary = true
RETURNING id, email, role, temp_supervisor_start, temp_supervisor_end;


-- 12. VIEW ALL ACTIVE TEMPORARY SUPERVISORS
-- Shows all temporary supervisors who are still within their assignment period
SELECT 
  id,
  email,
  role,
  temp_supervisor_start,
  temp_supervisor_end,
  (temp_supervisor_end - NOW()::date) as days_remaining,
  is_temporary,
  created_at,
  updated_at
FROM public.profiles
WHERE role = 'supervisor' 
  AND is_temporary = true
  AND temp_supervisor_end >= NOW()::date
ORDER BY temp_supervisor_end ASC;


-- 13. VIEW ALL EXPIRED TEMPORARY SUPERVISORS
-- Shows temporary supervisors whose role assignment has expired
SELECT 
  id,
  email,
  role,
  temp_supervisor_start,
  temp_supervisor_end,
  (NOW()::date - temp_supervisor_end) as days_since_expiration,
  is_temporary,
  created_at,
  updated_at
FROM public.profiles
WHERE role = 'supervisor' 
  AND is_temporary = true
  AND temp_supervisor_end < NOW()::date
ORDER BY temp_supervisor_end DESC;


-- 14. AUTO-REVERT EXPIRED TEMPORARY SUPERVISORS TO USER ROLE
-- This query should be run daily via database function or scheduled job
-- to automatically downgrade expired temporary supervisors
UPDATE public.profiles
SET 
  role = 'user',
  user_role = 'user',
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false,
  updated_at = NOW()
WHERE is_temporary = true 
  AND temp_supervisor_end < NOW()::date
RETURNING id, email, role, updated_at;


-- 15. REVOKE TEMPORARY SUPERVISOR ROLE IMMEDIATELY
-- Immediately downgrades a temporary supervisor back to user
UPDATE public.profiles
SET 
  role = 'user',
  user_role = 'user',
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false,
  updated_at = NOW()
WHERE LOWER(email) = LOWER('username@saudia.com')
  AND is_temporary = true
RETURNING id, email, role, updated_at;


-- 16. VIEW SUPERVISOR ROLE STATUS WITH DETAILS
-- Comprehensive view of all supervisors (permanent and temporary) with status
SELECT 
  id,
  email,
  role,
  CASE 
    WHEN is_temporary = true THEN 'Temporary (' || COALESCE(CAST(temp_supervisor_end - NOW()::date AS TEXT), 'N/A') || ' days remaining)'
    ELSE 'Permanent'
  END as supervisor_status,
  temp_supervisor_start,
  temp_supervisor_end,
  created_at,
  updated_at
FROM public.profiles
WHERE role = 'supervisor'
ORDER BY is_temporary DESC, temp_supervisor_end ASC NULLS LAST;


-- - Replace 'user@saudia.com' with actual email
-- - Replace 'USER_UUID_HERE' with actual UUID from auth.users table
-- - Both 'role' and 'user_role' columns must be updated to keep them in sync
-- - Always verify with query #5 before and after updates
-- - Use LOWER() for case-insensitive email matching
-- - RETURNING clause shows updated records for verification

-- TEMPORARY SUPERVISOR ROLE NOTES:
-- - Temporary supervisors have full supervisor privileges until expiration
-- - Query #12 shows all active temporary supervisors within their timeframe
-- - Query #13 shows expired temporary supervisors (should be reverted)
-- - Query #14 can be automated as a scheduled job to auto-revert expired roles
-- - Query #16 provides a unified view of all supervisors with status indicators
-- - Column mappings:
--   * temp_supervisor_start: DATE when the temporary assignment begins
--   * temp_supervisor_end: DATE when the temporary assignment ends
--   * is_temporary: BOOLEAN flag (true = temporary role, false/null = permanent)
-- - Set temp_supervisor_start and temp_supervisor_end to NULL to make permanent
-- - Use INTERVAL syntax for relative date calculations (e.g., '30 days', '1 month')
-- - Consider creating a database trigger or scheduled function for auto-reversion
