-- Migration 105: Next Database Scope
-- Purpose:
-- Adds database support tables for tracking order retention, disposition,
-- export, and delivery lifecycle events after Migration 104.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Order Lifecycle Audit Events
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID,
    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'recorded',

    actor_id UUID,
    actor_type TEXT NOT NULL DEFAULT 'system',

    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    source_module TEXT NOT NULL DEFAULT 'migration_105',
    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_audit_events IS
'Stores audit events related to order retention, disposition, export, and delivery lifecycle tracking.';

COMMENT ON COLUMN public.order_lifecycle_audit_events.order_id IS
'Optional order reference. No foreign key is enforced here to keep the migration safe across environments.';

COMMENT ON COLUMN public.order_lifecycle_audit_events.event_type IS
'Type of lifecycle event, such as retention_checked, disposition_updated, export_generated, delivery_finalized.';

COMMENT ON COLUMN public.order_lifecycle_audit_events.event_status IS
'Current status of the lifecycle event.';

COMMENT ON COLUMN public.order_lifecycle_audit_events.event_payload IS
'Flexible JSON payload for storing event-specific details.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_audit_events_order_id
ON public.order_lifecycle_audit_events(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_audit_events_event_type
ON public.order_lifecycle_audit_events(event_type);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_audit_events_created_at
ON public.order_lifecycle_audit_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_audit_events_payload
ON public.order_lifecycle_audit_events USING GIN(event_payload);

-- ============================================================
-- 2. Order Export Delivery Checkpoints
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_export_delivery_checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID,
    export_reference TEXT,
    delivery_reference TEXT,

    checkpoint_type TEXT NOT NULL,
    checkpoint_status TEXT NOT NULL DEFAULT 'pending',

    checkpoint_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_export_delivery_checkpoints IS
'Tracks export and delivery checkpoints for order finalization workflows.';

COMMENT ON COLUMN public.order_export_delivery_checkpoints.checkpoint_type IS
'Checkpoint category such as export_created, export_verified, delivery_ready, delivery_completed.';

COMMENT ON COLUMN public.order_export_delivery_checkpoints.checkpoint_status IS
'Checkpoint status such as pending, passed, failed, cancelled, or completed.';

CREATE INDEX IF NOT EXISTS idx_order_export_delivery_checkpoints_order_id
ON public.order_export_delivery_checkpoints(order_id);

CREATE INDEX IF NOT EXISTS idx_order_export_delivery_checkpoints_export_reference
ON public.order_export_delivery_checkpoints(export_reference);

CREATE INDEX IF NOT EXISTS idx_order_export_delivery_checkpoints_delivery_reference
ON public.order_export_delivery_checkpoints(delivery_reference);

CREATE INDEX IF NOT EXISTS idx_order_export_delivery_checkpoints_status
ON public.order_export_delivery_checkpoints(checkpoint_status);

CREATE INDEX IF NOT EXISTS idx_order_export_delivery_checkpoints_payload
ON public.order_export_delivery_checkpoints USING GIN(checkpoint_payload);

-- ============================================================
-- 3. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_export_delivery_checkpoint_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_export_delivery_checkpoints_updated_at
ON public.order_export_delivery_checkpoints;

CREATE TRIGGER trg_order_export_delivery_checkpoints_updated_at
BEFORE UPDATE ON public.order_export_delivery_checkpoints
FOR EACH ROW
EXECUTE FUNCTION public.set_order_export_delivery_checkpoint_updated_at();

-- ============================================================
-- 4. Optional Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_export_delivery_checkpoints ENABLE ROW LEVEL SECURITY;

-- Service role full access policy
DROP POLICY IF EXISTS "Service role can manage order lifecycle audit events"
ON public.order_lifecycle_audit_events;

CREATE POLICY "Service role can manage order lifecycle audit events"
ON public.order_lifecycle_audit_events
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order export delivery checkpoints"
ON public.order_export_delivery_checkpoints;

CREATE POLICY "Service role can manage order export delivery checkpoints"
ON public.order_export_delivery_checkpoints
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 5. Migration Registry Marker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.schema_migration_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    migration_number INTEGER NOT NULL UNIQUE,
    migration_name TEXT NOT NULL,
    migration_scope TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.schema_migration_registry (
    migration_number,
    migration_name,
    migration_scope
)
VALUES (
    105,
    'migration_105_next_database_scope',
    'Adds order lifecycle audit events and export delivery checkpoints.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
