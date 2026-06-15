-- ============================================================================
-- FIX: RLS POLICY ERROR - "new row violates row-level security policy"
-- ============================================================================
-- Run these queries in Supabase SQL Editor to fix the ticket insertion error
--
-- ISSUE: When saving new tickets, error appears:
--   "new row violates row-level security policy for table "tickets""
--
-- CAUSE: RLS policies on the tickets table are too restrictive or missing
--
-- ============================================================================


-- ============================================================================
-- STEP 1: DIAGNOSE - Check current RLS policies on tickets table
-- ============================================================================

-- View all RLS policies on tickets table
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'tickets'
ORDER BY policyname;

-- Check if RLS is enabled on tickets table
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'tickets';


-- ============================================================================
-- STEP 2: DISABLE RLS TEMPORARILY (for testing - NOT recommended for production)
-- ============================================================================

-- Disable Row-Level Security on tickets table (CAUTION: Not for production!)
-- ALTER TABLE public.tickets DISABLE ROW LEVEL SECURITY;

-- Re-enable Row-Level Security on tickets table
-- ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;


-- ============================================================================
-- STEP 3: CREATE/FIX RLS POLICIES - RECOMMENDED SOLUTION
-- ============================================================================

-- Drop existing problematic policies (if needed)
DROP POLICY IF EXISTS "Users can insert own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can read own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can update own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can delete own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Supervisors can manage any ticket" ON public.tickets;
DROP POLICY IF EXISTS "Admins can manage any ticket" ON public.tickets;
DROP POLICY IF EXISTS "Anyone can view tickets" ON public.tickets;


-- ============================================================================
-- OPTION A: PERMISSIVE - Open policy (for most users)
-- Allows authenticated users to insert tickets (MOST COMMON)
-- ============================================================================

-- Enable RLS on tickets table
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to INSERT tickets
CREATE POLICY "Authenticated users can insert tickets"
  ON public.tickets
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
  );

-- Allow users to READ all tickets (or modify as needed)
CREATE POLICY "Authenticated users can read tickets"
  ON public.tickets
  FOR SELECT
  USING (
    auth.role() = 'authenticated'
  );

-- Allow users to UPDATE their own tickets (if processed_by matches)
CREATE POLICY "Users can update their own tickets"
  ON public.tickets
  FOR UPDATE
  USING (
    auth.role() = 'authenticated'
    AND processed_by = (SELECT full_name FROM public.profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    auth.role() = 'authenticated'
  );

-- Allow supervisors/admins to DELETE tickets
CREATE POLICY "Supervisors and admins can delete tickets"
  ON public.tickets
  FOR DELETE
  USING (
    auth.role() = 'authenticated'
    AND (
      SELECT user_role FROM public.profiles WHERE id = auth.uid()
    ) IN ('supervisor', 'admin')
  );


-- ============================================================================
-- OPTION B: RESTRICTIVE - Role-based policy (for stricter control)
-- Separates permissions by user role
-- ============================================================================

-- Create separate policies for each action
-- (Uncomment if you prefer role-based access)

-- INSERT: Allow authenticated users and supervisors/admins
/*
CREATE POLICY "Insert tickets policy"
  ON public.tickets
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
  );
*/

-- SELECT: Allow authenticated users to view tickets
/*
CREATE POLICY "Select tickets policy"
  ON public.tickets
  FOR SELECT
  USING (
    auth.role() = 'authenticated'
  );
*/

-- UPDATE: Allow supervisors and admins to update any ticket
/*
CREATE POLICY "Update tickets policy"
  ON public.tickets
  FOR UPDATE
  USING (
    auth.role() = 'authenticated'
    AND (
      SELECT user_role FROM public.profiles WHERE id = auth.uid()
    ) IN ('supervisor', 'admin')
  )
  WITH CHECK (
    auth.role() = 'authenticated'
  );
*/

-- DELETE: Allow admins only to delete tickets
/*
CREATE POLICY "Delete tickets policy"
  ON public.tickets
  FOR DELETE
  USING (
    auth.role() = 'authenticated'
    AND (
      SELECT user_role FROM public.profiles WHERE id = auth.uid()
    ) = 'admin'
  );
*/


-- ============================================================================
-- STEP 4: VERIFY POLICIES ARE IN PLACE
-- ============================================================================

-- Check that policies were created successfully
SELECT
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'tickets'
ORDER BY policyname;

-- Verify tickets table has RLS enabled
SELECT
  schemaname,
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE tablename = 'tickets';


-- ============================================================================
-- STEP 5: TEST THE FIX
-- ============================================================================

-- As superuser, verify table structure
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'tickets'
ORDER BY ordinal_position;

-- Check if there are any constraint issues
SELECT
  constraint_name,
  constraint_type,
  table_name
FROM information_schema.table_constraints
WHERE table_name = 'tickets';


-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================

-- If you still get RLS errors after applying policies above, try:

-- 1. Check for missing columns that policies reference
SELECT column_name FROM information_schema.columns WHERE table_name = 'tickets';

-- 2. If 'processed_by' column doesn't exist, add it:
-- ALTER TABLE public.tickets ADD COLUMN processed_by TEXT;

-- 3. If 'full_name' doesn't exist in profiles table, check:
SELECT column_name FROM information_schema.columns WHERE table_name = 'profiles';

-- 4. Simplify to test - just allow all authenticated users to read/write:
-- CREATE POLICY "Allow all authenticated"
--   ON public.tickets
--   FOR ALL
--   USING (auth.role() = 'authenticated')
--   WITH CHECK (auth.role() = 'authenticated');

-- 5. Check JWT claims to verify authenticated user:
-- SELECT auth.uid(), auth.jwt();


-- ============================================================================
-- COMMON ISSUES & SOLUTIONS
-- ============================================================================

-- Issue 1: "Column does not exist"
-- Solution: Verify all referenced columns exist in tables
-- Example: processed_by in tickets, full_name in profiles

-- Issue 2: "new row violates row-level security policy"
-- Solution A: INSERT policy missing or too restrictive
-- Solution B: Column references in policy are NULL or incorrect
-- Solution C: WITH CHECK condition fails for new rows

-- Issue 3: Policy works for SELECT but not INSERT
-- Solution: Missing WITH CHECK clause for INSERT operation
-- Example: Need WITH CHECK to validate new row values

-- Issue 4: Supervisors can't edit tickets from users
-- Solution: Update policy should allow supervisors
-- Current policy only checks processed_by field
-- May need to add supervisor check: (SELECT user_role...) IN ('supervisor', 'admin')

-- ============================================================================
-- ADVANCED: Grant specific permissions
-- ============================================================================

-- If RLS policies still don't work, try granting explicit table permissions:

-- Grant authenticated users permission to insert
GRANT INSERT ON public.tickets TO authenticated;

-- Grant authenticated users permission to select
GRANT SELECT ON public.tickets TO authenticated;

-- Grant authenticated users permission to update
GRANT UPDATE ON public.tickets TO authenticated;

-- Grant authenticated users permission to delete (if supervisors/admins)
GRANT DELETE ON public.tickets TO authenticated;

-- ============================================================================
