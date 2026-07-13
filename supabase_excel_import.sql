-- Supabase SQL to support Excel/CSV ticket imports and chat notifications
-- Run this in the Supabase SQL Editor.

-- 1) Ensure the tickets table has the columns used by the portal
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS issuer_name text,
  ADD COLUMN IF NOT EXISTS flight_date date,
  ADD COLUMN IF NOT EXISTS route text,
  ADD COLUMN IF NOT EXISTS flight_type text,
  ADD COLUMN IF NOT EXISTS issue_period_from date,
  ADD COLUMN IF NOT EXISTS issue_period_to date,
  ADD COLUMN IF NOT EXISTS reissue_reason text,
  ADD COLUMN IF NOT EXISTS rebook_reason text,
  ADD COLUMN IF NOT EXISTS emd_reason text,
  ADD COLUMN IF NOT EXISTS previous_ticket_num text,
  ADD COLUMN IF NOT EXISTS ticket_value_naira numeric,
  ADD COLUMN IF NOT EXISTS refund_tax numeric,
  ADD COLUMN IF NOT EXISTS refund_status text,
  ADD COLUMN IF NOT EXISTS refund_value_naira numeric,
  ADD COLUMN IF NOT EXISTS refund_by text,
  ADD COLUMN IF NOT EXISTS refund_reason text,
  ADD COLUMN IF NOT EXISTS refund_recipient text,
  ADD COLUMN IF NOT EXISTS refund_date date,
  ADD COLUMN IF NOT EXISTS refund_amount_naira numeric,
  ADD COLUMN IF NOT EXISTS status_comment text;

-- 2) Make sure the table can be written by authenticated users (RLS)
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_tickets_select" ON public.tickets;
DROP POLICY IF EXISTS "authenticated_tickets_insert" ON public.tickets;
DROP POLICY IF EXISTS "authenticated_tickets_update" ON public.tickets;
DROP POLICY IF EXISTS "authenticated_tickets_delete" ON public.tickets;

CREATE POLICY "authenticated_tickets_select"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated_tickets_insert"
  ON public.tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated_tickets_update"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "authenticated_tickets_delete"
  ON public.tickets
  FOR DELETE
  TO authenticated
  USING (true);

-- 3) Ensure chat_messages table is available and published for Realtime
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid,
  sender_name text,
  message text NOT NULL,
  recipient_ids text[] DEFAULT '{}',
  recipient_roles text[] DEFAULT '{}',
  is_private boolean NOT NULL DEFAULT false,
  reply_to uuid DEFAULT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_select" ON public.chat_messages;
DROP POLICY IF EXISTS "authenticated_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "authenticated_delete_own" ON public.chat_messages;
DROP POLICY IF EXISTS "admin_delete_any" ON public.chat_messages;

CREATE POLICY "authenticated_select"
  ON public.chat_messages
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated_insert"
  ON public.chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated_delete_own"
  ON public.chat_messages
  FOR DELETE
  TO authenticated
  USING (sender_id = auth.uid());

CREATE POLICY "admin_delete_any"
  ON public.chat_messages
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND lower(coalesce(p.role, p.user_role, 'user')) = 'admin'
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END $$;

-- 4) Optional helper RPC for membership lookups used by the chat UI
CREATE OR REPLACE FUNCTION public.list_chat_members()
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  role text,
  user_role text
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT p.id, p.full_name, p.email, p.role, p.user_role
  FROM public.profiles p
  WHERE p.id IS NOT NULL
  ORDER BY coalesce(p.full_name, p.email, p.id::text);
$$;

GRANT EXECUTE ON FUNCTION public.list_chat_members() TO authenticated;
