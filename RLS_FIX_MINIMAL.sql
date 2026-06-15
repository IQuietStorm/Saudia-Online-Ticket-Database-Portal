-- ============================================================================
-- MINIMAL FIX: Just copy and paste this entire script into Supabase SQL Editor
-- ============================================================================
-- This will fix: "new row violates row-level security policy for table "tickets""
-- Execution time: ~5 seconds
-- ============================================================================

-- Step 1: Drop old policies
DROP POLICY IF EXISTS "Allow authenticated insert" ON public.tickets;
DROP POLICY IF EXISTS "Allow authenticated select" ON public.tickets;
DROP POLICY IF EXISTS "Allow supervisor update" ON public.tickets;
DROP POLICY IF EXISTS "Allow supervisor delete" ON public.tickets;
DROP POLICY IF EXISTS "Users can insert own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can read own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can update own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can delete own tickets" ON public.tickets;

-- Step 2: Enable RLS
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

-- Step 3: Create new policies (simple, permissive)
CREATE POLICY "authenticated_insert" ON public.tickets FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated_select" ON public.tickets FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_update" ON public.tickets FOR UPDATE TO authenticated USING ((SELECT user_role FROM public.profiles WHERE id = auth.uid()) IN ('supervisor', 'admin')) WITH CHECK (true);
CREATE POLICY "authenticated_delete" ON public.tickets FOR DELETE TO authenticated USING ((SELECT user_role FROM public.profiles WHERE id = auth.uid()) IN ('supervisor', 'admin'));

-- Step 4: Grant permissions
GRANT INSERT, SELECT, UPDATE, DELETE ON public.tickets TO authenticated;

-- Done! Try saving a ticket now in your app.
