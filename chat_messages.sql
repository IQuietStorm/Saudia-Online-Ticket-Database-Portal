-- Create table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id uuid,
    sender_name text,
    message text NOT NULL,
    recipient_ids uuid[] DEFAULT NULL,
    recipient_roles text[] DEFAULT NULL,
    is_private boolean NOT NULL DEFAULT false,
    reply_to uuid DEFAULT NULL,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- Ensure columns added after initial deploy exist on older databases
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS reply_to uuid DEFAULT NULL;

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Remove existing policies so the script can be run multiple times
DROP POLICY IF EXISTS "authenticated_select" ON public.chat_messages;
DROP POLICY IF EXISTS "authenticated_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "authenticated_delete_own" ON public.chat_messages;
DROP POLICY IF EXISTS "admin_delete_any" ON public.chat_messages;

-- Team/public messages (is_private = false) are visible to every signed-in user.
-- Private DMs and role-targeted messages stay restricted to participants.
CREATE POLICY "authenticated_select" ON public.chat_messages
  FOR SELECT
  USING (
      auth.role() = 'authenticated'
      AND (
          NOT is_private
          OR sender_id = auth.uid()
          OR (
              recipient_ids IS NOT NULL
              AND cardinality(recipient_ids) > 0
              AND auth.uid() = ANY(recipient_ids)
          )
          OR (
              recipient_roles IS NOT NULL
              AND cardinality(recipient_roles) > 0
              AND EXISTS (
                  SELECT 1
                  FROM public.profiles p
                  WHERE p.id = auth.uid()
                    AND (
                      lower(COALESCE(p.role, '')) = ANY(recipient_roles)
                      OR lower(COALESCE(p.user_role, '')) = ANY(recipient_roles)
                    )
              )
          )
      )
  );

-- Recreate INSERT policy
CREATE POLICY "authenticated_insert" ON public.chat_messages
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Allow users to permanently delete their own messages
CREATE POLICY "authenticated_delete_own" ON public.chat_messages
  FOR DELETE
  USING (
    auth.role() = 'authenticated'
    AND sender_id = auth.uid()
  );

-- Allow admins to permanently delete any message
CREATE POLICY "admin_delete_any" ON public.chat_messages
  FOR DELETE
  USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND (
          LOWER(COALESCE(p.role, '')) = 'admin'
          OR LOWER(COALESCE(p.user_role, '')) = 'admin'
        )
    )
  );

-- Realtime: other members only receive live INSERT events when the table is published.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END $$;
