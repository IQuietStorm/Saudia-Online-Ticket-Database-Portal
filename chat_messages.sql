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

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Remove existing policies so the script can be run multiple times
DROP POLICY IF EXISTS "authenticated_select" ON public.chat_messages;
DROP POLICY IF EXISTS "authenticated_insert" ON public.chat_messages;

-- Recreate SELECT policy
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
                  (SELECT role FROM public.profiles WHERE id = auth.uid()) = ANY(recipient_roles)
              )
          )
      )
  );

-- Recreate INSERT policy
CREATE POLICY "authenticated_insert" ON public.chat_messages
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');
