-- ============================================================================
-- TEMPORARY SUPERVISOR ROLE MANAGEMENT
-- ============================================================================
-- Quick reference SQL queries for managing temporary supervisor assignments
-- with automatic expiration dates in Supabase
--
-- SETUP REQUIRED:
-- Add these columns to your public.profiles table if they don't exist:
-- ALTER TABLE public.profiles ADD COLUMN temp_supervisor_start DATE;
-- ALTER TABLE public.profiles ADD COLUMN temp_supervisor_end DATE;
-- ALTER TABLE public.profiles ADD COLUMN is_temporary BOOLEAN DEFAULT false;
--
-- ============================================================================


-- ============================================================================
-- QUICK START EXAMPLES
-- ============================================================================

-- Assign temporary supervisor for 30 days (from today)
UPDATE public.profiles
SET 
  role = 'supervisor',
  user_role = 'supervisor',
  temp_supervisor_start = NOW()::date,
  temp_supervisor_end = (NOW() + INTERVAL '30 days')::date,
  is_temporary = true
WHERE LOWER(email) = LOWER('employee@saudia.com');

-- Assign temporary supervisor for specific dates (e.g., July 1 - August 15, 2026)
UPDATE public.profiles
SET 
  role = 'supervisor',
  user_role = 'supervisor',
  temp_supervisor_start = '2026-07-01'::date,
  temp_supervisor_end = '2026-08-15'::date,
  is_temporary = true
WHERE LOWER(email) = LOWER('employee@saudia.com');

-- Assign multiple temporary supervisors at once
UPDATE public.profiles
SET 
  role = 'supervisor',
  user_role = 'supervisor',
  temp_supervisor_start = NOW()::date,
  temp_supervisor_end = (NOW() + INTERVAL '60 days')::date,
  is_temporary = true
WHERE LOWER(email) IN (
  'supervisor1@saudia.com',
  'supervisor2@saudia.com',
  'supervisor3@saudia.com'
);


-- ============================================================================
-- MONITORING & REPORTING
-- ============================================================================

-- View all active temporary supervisors (still within assignment period)
SELECT 
  id,
  email,
  temp_supervisor_start,
  temp_supervisor_end,
  (temp_supervisor_end - NOW()::date) as days_remaining,
  created_at
FROM public.profiles
WHERE role = 'supervisor' 
  AND is_temporary = true
  AND temp_supervisor_end >= NOW()::date
ORDER BY temp_supervisor_end ASC;


-- View temporary supervisors expiring within 7 days (warning report)
SELECT 
  id,
  email,
  temp_supervisor_start,
  temp_supervisor_end,
  (temp_supervisor_end - NOW()::date) as days_remaining
FROM public.profiles
WHERE role = 'supervisor' 
  AND is_temporary = true
  AND temp_supervisor_end BETWEEN NOW()::date AND (NOW()::date + INTERVAL '7 days')
ORDER BY temp_supervisor_end ASC;


-- View expired temporary supervisors (need immediate reversion)
SELECT 
  id,
  email,
  temp_supervisor_end,
  (NOW()::date - temp_supervisor_end) as days_expired
FROM public.profiles
WHERE role = 'supervisor' 
  AND is_temporary = true
  AND temp_supervisor_end < NOW()::date
ORDER BY temp_supervisor_end DESC;


-- Dashboard: All supervisors with status
SELECT 
  email,
  role,
  is_temporary,
  temp_supervisor_start,
  temp_supervisor_end,
  CASE 
    WHEN is_temporary = false THEN 'Permanent'
    WHEN is_temporary = true AND temp_supervisor_end >= NOW()::date THEN 
      'Active (' || CAST(temp_supervisor_end - NOW()::date AS TEXT) || ' days)'
    WHEN is_temporary = true AND temp_supervisor_end < NOW()::date THEN 
      'EXPIRED (' || CAST(NOW()::date - temp_supervisor_end AS TEXT) || ' days ago)'
    ELSE 'Unknown'
  END as status,
  created_at,
  updated_at
FROM public.profiles
WHERE role = 'supervisor'
ORDER BY is_temporary DESC, temp_supervisor_end ASC;


-- ============================================================================
-- MANAGEMENT OPERATIONS
-- ============================================================================

-- Convert temporary supervisor to permanent (remove expiration)
UPDATE public.profiles
SET 
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false
WHERE LOWER(email) = LOWER('employee@saudia.com')
  AND is_temporary = true
RETURNING email, role, is_temporary;


-- Extend temporary supervisor by additional 30 days
UPDATE public.profiles
SET 
  temp_supervisor_end = (temp_supervisor_end + INTERVAL '30 days')::date
WHERE LOWER(email) = LOWER('employee@saudia.com') 
  AND is_temporary = true
RETURNING email, temp_supervisor_end, (temp_supervisor_end - NOW()::date) as days_remaining;


-- Revoke temporary supervisor role immediately (downgrade to user)
UPDATE public.profiles
SET 
  role = 'user',
  user_role = 'user',
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false
WHERE LOWER(email) = LOWER('employee@saudia.com')
  AND is_temporary = true
RETURNING email, role;


-- Revoke all expired temporary supervisor roles (batch operation)
-- Should be run as a scheduled job (e.g., daily)
UPDATE public.profiles
SET 
  role = 'user',
  user_role = 'user',
  temp_supervisor_start = NULL,
  temp_supervisor_end = NULL,
  is_temporary = false
WHERE is_temporary = true 
  AND temp_supervisor_end < NOW()::date
RETURNING id, email, role;


-- ============================================================================
-- SCHEDULED JOB: Auto-revert expired temporary supervisors
-- ============================================================================
-- Create this as a PostgreSQL function to be called on a schedule (e.g., via cron)
-- Usage: SELECT auto_revert_expired_supervisors();

CREATE OR REPLACE FUNCTION auto_revert_expired_supervisors()
RETURNS TABLE (reverted_count INT, reverted_users TEXT) AS $$
DECLARE
  v_count INT;
  v_users TEXT;
BEGIN
  -- Update expired temporary supervisors
  WITH updated AS (
    UPDATE public.profiles
    SET 
      role = 'user',
      user_role = 'user',
      temp_supervisor_start = NULL,
      temp_supervisor_end = NULL,
      is_temporary = false
    WHERE is_temporary = true 
      AND temp_supervisor_end < NOW()::date
    RETURNING email
  )
  SELECT COUNT(*), STRING_AGG(email, ', ') 
  INTO v_count, v_users
  FROM updated;
  
  RETURN QUERY SELECT v_count, COALESCE(v_users, 'None');
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- AUDIT & LOGGING
-- ============================================================================

-- View complete history of supervisor role changes
-- (Requires an audit log table - implement separately if needed)
SELECT 
  id,
  email,
  role,
  is_temporary,
  temp_supervisor_start,
  temp_supervisor_end,
  created_at,
  updated_at,
  CASE 
    WHEN is_temporary = true THEN 'Temporary Assignment'
    ELSE 'Permanent Role'
  END as assignment_type
FROM public.profiles
WHERE role IN ('supervisor', 'admin')
ORDER BY updated_at DESC;


-- ============================================================================
-- INTEGRATION WITH LOCAL STORAGE (Frontend)
-- ============================================================================
-- When storing users locally in JSON format, include:
-- {
--   "id": "uuid-here",
--   "name": "John Supervisor",
--   "email": "john@saudia.com",
--   "role": "supervisor",
--   "tempSupervisorStart": "2026-07-01",
--   "tempSupervisorEnd": "2026-08-15",
--   "isTemporary": true,
--   "createdAt": "2026-06-15T10:00:00Z"
-- }
--
-- The frontend JavaScript will automatically:
-- 1. Check if today's date > tempSupervisorEnd
-- 2. If expired, revert role to 'user'
-- 3. Display "⏳ X days remaining" in the UI
-- 4. Show "⚠️ Expired" for past assignments

-- ============================================================================
