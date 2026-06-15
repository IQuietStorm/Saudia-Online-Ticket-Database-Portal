-- ============================================================================
-- QUICK FIX: RLS Policy Error - Row-Level Security Violation
-- ============================================================================
-- Copy and run these exact queries in Supabase SQL Editor (in order)
-- 
-- ERROR: "new row violates row-level security policy for table "tickets""
--
-- ============================================================================


-- ============================================================================
-- STEP 1: DIAGNOSE CURRENT POLICIES (RUN FIRST)
-- ============================================================================

-- Check what RLS policies currently exist on tickets table
SELECT
  policyname,
  permissive,
  roles,
  qual as "SELECT condition",
  with_check as "INSERT/UPDATE condition"
FROM pg_policies
WHERE tablename = 'tickets'
ORDER BY policyname;


-- ============================================================================
-- STEP 2: DELETE OLD/CONFLICTING POLICIES (if needed)
-- ============================================================================

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Users can insert own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can read own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can update own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can delete own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Supervisors can manage any ticket" ON public.tickets;
DROP POLICY IF EXISTS "Admins can manage any ticket" ON public.tickets;
DROP POLICY IF EXISTS "Authenticated users can insert tickets" ON public.tickets;
DROP POLICY IF EXISTS "Authenticated users can read tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can update their own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Supervisors and admins can delete tickets" ON public.tickets;


-- ============================================================================
-- STEP 3: ENABLE RLS (ensure it's turned on)
-- ============================================================================

ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;


-- ============================================================================
-- STEP 4: CREATE NEW POLICIES - PERMISSIVE (Recommended)
-- ============================================================================

-- Policy 1: Allow authenticated users to INSERT new tickets
CREATE POLICY "Allow authenticated insert"
  ON public.tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy 2: Allow authenticated users to SELECT (view) tickets
CREATE POLICY "Allow authenticated select"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy 3: Allow supervisors/admins to UPDATE tickets
CREATE POLICY "Allow supervisor update"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid()) 
    IN ('supervisor', 'admin', 'superuser')
  )
  WITH CHECK (true);

-- Policy 4: Allow supervisors/admins to DELETE tickets
CREATE POLICY "Allow supervisor delete"
  ON public.tickets
  FOR DELETE
  TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid()) 
    IN ('supervisor', 'admin', 'superuser')
  );


-- ============================================================================
-- STEP 5: VERIFY POLICIES WERE CREATED
-- ============================================================================

-- Confirm policies are now in place
SELECT
  policyname,
  permissive,
  roles,
  qual as "SELECT condition",
  with_check as "INSERT/UPDATE condition"
FROM pg_policies
WHERE tablename = 'tickets'
ORDER BY policyname;

-- Confirm RLS is enabled
SELECT
  schemaname,
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE tablename = 'tickets';


-- ============================================================================
-- STEP 6: GRANT PERMISSIONS (if needed)
-- ============================================================================

-- Grant authenticated role permissions on tickets table
GRANT INSERT ON public.tickets TO authenticated;
GRANT SELECT ON public.tickets TO authenticated;
GRANT UPDATE ON public.tickets TO authenticated;
GRANT DELETE ON public.tickets TO authenticated;


-- ============================================================================
-- STEP 7: TEST - Verify insert works (optional)
-- ============================================================================

-- Check table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'tickets'
ORDER BY ordinal_position;

-- Test insert (as authenticated user - replace with actual values):
-- INSERT INTO public.tickets (ticket_num, type, status, issue_date, processed_by)
-- VALUES ('1234567890123', 'Fresh Issue', 'Flown', '2026-06-15', 'John Doe')
-- RETURNING id, ticket_num, created_at;


-- ============================================================================
-- IF ISSUE PERSISTS: Nuclear Option (last resort)
-- ============================================================================

-- Disable RLS entirely (NOT RECOMMENDED - Security risk!)
-- ALTER TABLE public.tickets DISABLE ROW LEVEL SECURITY;

-- Re-enable and apply anonymous access (for testing only):
-- CREATE POLICY "Allow all"
--   ON public.tickets
--   FOR ALL
--   TO anon, authenticated
--   USING (true)
--   WITH CHECK (true);


-- ============================================================================
-- DEBUGGING: Check if required columns exist
-- ============================================================================

-- Verify 'processed_by' column exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'tickets' AND column_name = 'processed_by'
) as "processed_by exists";

-- Verify 'user_role' column exists in profiles
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'profiles' AND column_name = 'user_role'
) as "user_role exists";

-- If columns missing, add them:
-- ALTER TABLE public.tickets ADD COLUMN processed_by TEXT;
-- ALTER TABLE public.profiles ADD COLUMN user_role TEXT DEFAULT 'user';


-- ============================================================================
