-- Allow authenticated users to read all profiles so every account can appear as a chat member.
-- Run this in Supabase SQL Editor.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_select" ON public.profiles;
CREATE POLICY "authenticated_select" ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.role() = 'authenticated'
  );
