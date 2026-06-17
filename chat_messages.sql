-- Create a chat stream with support for public, role-targeted, and user-targeted messages.
-- Run this in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id uuid,
    sender_name text,
    message text NOT NULL,
    recipient_ids uuid[] DEFAULT NULL,
    recipient_roles text[] DEFAULT NULL,
    is_private boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_select" ON public.chat_messages
  FOR SELECT
  USING (
      auth.role() = 'authenticated'
      AND (
          recipient_ids IS NULL
          AND recipient_roles IS NULL
          OR sender_id = auth.uid()
          OR (
              recipient_ids IS NOT NULL
              AND auth.uid() = ANY(recipient_ids)
          )
          OR (
              recipient_roles IS NOT NULL
              AND (
                  (SELECT user_role FROM public.profiles WHERE id = auth.uid()) = ANY(recipient_roles)
                  OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = ANY(recipient_roles)
              )
          )
      )
  );

CREATE POLICY "authenticated_insert" ON public.chat_messages
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- If you want to allow authenticated users to delete or update their own messages,
-- create separate policies below. By default, no one may modify or delete messages.
--
-- CREATE POLICY "authenticated_delete_own" ON public.chat_messages
--   FOR DELETE
--   USING (auth.role() = 'authenticated' AND sender_id = auth.uid());
--
-- CREATE POLICY "authenticated_update_own" ON public.chat_messages
--   FOR UPDATE
--   USING (auth.role() = 'authenticated' AND sender_id = auth.uid())
--   WITH CHECK (auth.role() = 'authenticated');
