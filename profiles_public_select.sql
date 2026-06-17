-- Chat members directory: every authenticated user can see all accounts.
-- Run this entire script in Supabase SQL Editor.
--
-- Why users only saw themselves before:
-- profiles RLS usually allows SELECT on your own row only. The chat UI then
-- falls back to adding the signed-in user, so the Members list shows count (1).

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Remove every existing SELECT policy on profiles (avoids conflicting rules).
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

-- Any signed-in user may read all profile rows (for chat @mentions + members list).
CREATE POLICY "authenticated_select" ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.role() = 'authenticated');

-- Reliable chat directory: lists every auth account, even if profile row is missing.
-- SECURITY DEFINER bypasses restrictive profile RLS for this read-only listing.
CREATE OR REPLACE FUNCTION public.list_chat_members()
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  role text,
  user_role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    COALESCE(
      NULLIF(trim(p.full_name), ''),
      NULLIF(trim(u.raw_user_meta_data->>'full_name'), ''),
      NULLIF(trim(u.raw_user_meta_data->>'fullName'), ''),
      split_part(u.email, '@', 1)
    )::text AS full_name,
    u.email::text,
    COALESCE(NULLIF(lower(trim(p.role)), ''), 'user')::text AS role,
    COALESCE(
      NULLIF(lower(trim(p.user_role)), ''),
      NULLIF(lower(trim(p.role)), ''),
      'user'
    )::text AS user_role
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  ORDER BY full_name NULLS LAST, u.email;
END;
$$;

REVOKE ALL ON FUNCTION public.list_chat_members() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_chat_members() TO authenticated;
