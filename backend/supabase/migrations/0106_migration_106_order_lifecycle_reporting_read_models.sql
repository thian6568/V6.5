-- Migration 106: Order Lifecycle Reporting Read Models
-- Purpose:
-- Adds reporting read-model support for order lifecycle audit events
-- and export/delivery checkpoints created in Migration 105.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Order Lifecycle Reporting Read Model Table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_reporting_read_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID NOT NULL UNIQUE,

    latest_event_type TEXT,
    latest_event_status TEXT,

    latest_checkpoint_type TEXT,
    latest_checkpoint_status TEXT,

    export_reference TEXT,
    delivery_reference TEXT,

    total_lifecycle_events INTEGER NOT NULL DEFAULT 0,
    total_checkpoints INTEGER NOT NULL DEFAULT 0,
    completed_checkpoints INTEGER NOT NULL DEFAULT 0,
    pending_checkpoints INTEGER NOT NULL DEFAULT 0,
    failed_checkpoints INTEGER NOT NULL DEFAULT 0,

    first_event_at TIMESTAMPTZ,
    last_event_at TIMESTAMPTZ,
    last_checkpoint_at TIMESTAMPTZ,

    report_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_reporting_read_models IS
'Stores cached reporting read-model data for order lifecycle, retention, disposition, export, and delivery tracking.';

COMMENT ON COLUMN public.order_lifecycle_reporting_read_models.order_id IS
'Order identifier used to group lifecycle events and delivery checkpoints.';

COMMENT ON COLUMN public.order_lifecycle_reporting_read_models.report_payload IS
'Flexible reporting payload for dashboard, admin, export, and analytics use.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_reporting_order_id
ON public.order_lifecycle_reporting_read_models(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_reporting_latest_event_status
ON public.order_lifecycle_reporting_read_models(latest_event_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_reporting_latest_checkpoint_status
ON public.order_lifecycle_reporting_read_models(latest_checkpoint_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_reporting_updated_at
ON public.order_lifecycle_reporting_read_models(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_reporting_payload
ON public.order_lifecycle_reporting_read_models USING GIN(report_payload);

-- ============================================================
-- 2. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_reporting_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_reporting_updated_at
ON public.order_lifecycle_reporting_read_models;

CREATE TRIGGER trg_order_lifecycle_reporting_updated_at
BEFORE UPDATE ON public.order_lifecycle_reporting_read_models
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_reporting_updated_at();

-- ============================================================
-- 3. Refresh Single Order Reporting Read Model
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_order_lifecycle_reporting_read_model(
    p_order_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_latest_event_type TEXT;
    v_latest_event_status TEXT;

    v_latest_checkpoint_type TEXT;
    v_latest_checkpoint_status TEXT;
    v_export_reference TEXT;
    v_delivery_reference TEXT;

    v_total_lifecycle_events INTEGER := 0;
    v_total_checkpoints INTEGER := 0;
    v_completed_checkpoints INTEGER := 0;
    v_pending_checkpoints INTEGER := 0;
    v_failed_checkpoints INTEGER := 0;

    v_first_event_at TIMESTAMPTZ;
    v_last_event_at TIMESTAMPTZ;
    v_last_checkpoint_at TIMESTAMPTZ;
BEGIN
    IF p_order_id IS NULL THEN
        RETURN;
    END IF;

    SELECT
        event_type,
        event_status
    INTO
        v_latest_event_type,
        v_latest_event_status
    FROM public.order_lifecycle_audit_events
    WHERE order_id = p_order_id
    ORDER BY created_at DESC
    LIMIT 1;

    SELECT
        checkpoint_type,
        checkpoint_status,
        export_reference,
        delivery_reference,
        COALESCE(verified_at, updated_at, created_at)
    INTO
        v_latest_checkpoint_type,
        v_latest_checkpoint_status,
        v_export_reference,
        v_delivery_reference,
        v_last_checkpoint_at
    FROM public.order_export_delivery_checkpoints
    WHERE order_id = p_order_id
    ORDER BY COALESCE(verified_at, updated_at, created_at) DESC
    LIMIT 1;

    SELECT
        COUNT(*)::INTEGER,
        MIN(created_at),
        MAX(created_at)
    INTO
        v_total_lifecycle_events,
        v_first_event_at,
        v_last_event_at
    FROM public.order_lifecycle_audit_events
    WHERE order_id = p_order_id;

    SELECT
        COUNT(*)::INTEGER,
        COUNT(*) FILTER (
            WHERE checkpoint_status IN ('completed', 'passed')
        )::INTEGER,
        COUNT(*) FILTER (
            WHERE checkpoint_status = 'pending'
        )::INTEGER,
        COUNT(*) FILTER (
            WHERE checkpoint_status IN ('failed', 'cancelled')
        )::INTEGER,
        MAX(COALESCE(verified_at, updated_at, created_at))
    INTO
        v_total_checkpoints,
        v_completed_checkpoints,
        v_pending_checkpoints,
        v_failed_checkpoints,
        v_last_checkpoint_at
    FROM public.order_export_delivery_checkpoints
    WHERE order_id = p_order_id;

    INSERT INTO public.order_lifecycle_reporting_read_models (
        order_id,
        latest_event_type,
        latest_event_status,
        latest_checkpoint_type,
        latest_checkpoint_status,
        export_reference,
        delivery_reference,
        total_lifecycle_events,
        total_checkpoints,
        completed_checkpoints,
        pending_checkpoints,
        failed_checkpoints,
        first_event_at,
        last_event_at,
        last_checkpoint_at,
        report_payload,
        generated_at,
        updated_at
    )
    VALUES (
        p_order_id,
        v_latest_event_type,
        v_latest_event_status,
        v_latest_checkpoint_type,
        v_latest_checkpoint_status,
        v_export_reference,
        v_delivery_reference,
        COALESCE(v_total_lifecycle_events, 0),
        COALESCE(v_total_checkpoints, 0),
        COALESCE(v_completed_checkpoints, 0),
        COALESCE(v_pending_checkpoints, 0),
        COALESCE(v_failed_checkpoints, 0),
        v_first_event_at,
        v_last_event_at,
        v_last_checkpoint_at,
        jsonb_build_object(
            'order_id', p_order_id,
            'latest_event_type', v_latest_event_type,
            'latest_event_status', v_latest_event_status,
            'latest_checkpoint_type', v_latest_checkpoint_type,
            'latest_checkpoint_status', v_latest_checkpoint_status,
            'export_reference', v_export_reference,
            'delivery_reference', v_delivery_reference,
            'total_lifecycle_events', COALESCE(v_total_lifecycle_events, 0),
            'total_checkpoints', COALESCE(v_total_checkpoints, 0),
            'completed_checkpoints', COALESCE(v_completed_checkpoints, 0),
            'pending_checkpoints', COALESCE(v_pending_checkpoints, 0),
            'failed_checkpoints', COALESCE(v_failed_checkpoints, 0),
            'generated_by', 'migration_106'
        ),
        NOW(),
        NOW()
    )
    ON CONFLICT (order_id) DO UPDATE
    SET
        latest_event_type = EXCLUDED.latest_event_type,
        latest_event_status = EXCLUDED.latest_event_status,
        latest_checkpoint_type = EXCLUDED.latest_checkpoint_type,
        latest_checkpoint_status = EXCLUDED.latest_checkpoint_status,
        export_reference = EXCLUDED.export_reference,
        delivery_reference = EXCLUDED.delivery_reference,
        total_lifecycle_events = EXCLUDED.total_lifecycle_events,
        total_checkpoints = EXCLUDED.total_checkpoints,
        completed_checkpoints = EXCLUDED.completed_checkpoints,
        pending_checkpoints = EXCLUDED.pending_checkpoints,
        failed_checkpoints = EXCLUDED.failed_checkpoints,
        first_event_at = EXCLUDED.first_event_at,
        last_event_at = EXCLUDED.last_event_at,
        last_checkpoint_at = EXCLUDED.last_checkpoint_at,
        report_payload = EXCLUDED.report_payload,
        generated_at = NOW(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. Refresh All Reporting Read Models
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_order_lifecycle_reporting_read_models()
RETURNS INTEGER AS $$
DECLARE
    v_order RECORD;
    v_refreshed_count INTEGER := 0;
BEGIN
    FOR v_order IN
        SELECT DISTINCT order_id
        FROM (
            SELECT order_id
            FROM public.order_lifecycle_audit_events
            WHERE order_id IS NOT NULL

            UNION

            SELECT order_id
            FROM public.order_export_delivery_checkpoints
            WHERE order_id IS NOT NULL
        ) AS combined_order_ids
    LOOP
        PERFORM public.refresh_order_lifecycle_reporting_read_model(v_order.order_id);
        v_refreshed_count := v_refreshed_count + 1;
    END LOOP;

    RETURN v_refreshed_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. Auto-Refresh Trigger For Source Tables
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_order_lifecycle_reporting_read_model_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.order_id IS NOT NULL THEN
            PERFORM public.refresh_order_lifecycle_reporting_read_model(OLD.order_id);
        END IF;

        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.order_id IS DISTINCT FROM NEW.order_id AND OLD.order_id IS NOT NULL THEN
            PERFORM public.refresh_order_lifecycle_reporting_read_model(OLD.order_id);
        END IF;

        IF NEW.order_id IS NOT NULL THEN
            PERFORM public.refresh_order_lifecycle_reporting_read_model(NEW.order_id);
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.order_id IS NOT NULL THEN
            PERFORM public.refresh_order_lifecycle_reporting_read_model(NEW.order_id);
        END IF;

        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_audit_events_refresh_reporting
ON public.order_lifecycle_audit_events;

CREATE TRIGGER trg_order_lifecycle_audit_events_refresh_reporting
AFTER INSERT OR UPDATE OR DELETE ON public.order_lifecycle_audit_events
FOR EACH ROW
EXECUTE FUNCTION public.refresh_order_lifecycle_reporting_read_model_trigger();

DROP TRIGGER IF EXISTS trg_order_export_delivery_checkpoints_refresh_reporting
ON public.order_export_delivery_checkpoints;

CREATE TRIGGER trg_order_export_delivery_checkpoints_refresh_reporting
AFTER INSERT OR UPDATE OR DELETE ON public.order_export_delivery_checkpoints
FOR EACH ROW
EXECUTE FUNCTION public.refresh_order_lifecycle_reporting_read_model_trigger();

-- ============================================================
-- 6. Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_reporting_dashboard_view AS
SELECT
    order_id,
    latest_event_type,
    latest_event_status,
    latest_checkpoint_type,
    latest_checkpoint_status,
    export_reference,
    delivery_reference,
    total_lifecycle_events,
    total_checkpoints,
    completed_checkpoints,
    pending_checkpoints,
    failed_checkpoints,
    first_event_at,
    last_event_at,
    last_checkpoint_at,
    CASE
        WHEN failed_checkpoints > 0 THEN 'attention_required'
        WHEN pending_checkpoints > 0 THEN 'in_progress'
        WHEN total_checkpoints > 0
             AND completed_checkpoints = total_checkpoints THEN 'completed'
        WHEN total_lifecycle_events > 0 THEN 'recorded'
        ELSE 'not_started'
    END AS reporting_status,
    report_payload,
    generated_at,
    updated_at
FROM public.order_lifecycle_reporting_read_models;

COMMENT ON VIEW public.order_lifecycle_reporting_dashboard_view IS
'Dashboard-ready view for order lifecycle reporting, export status, and delivery checkpoint status.';

-- ============================================================
-- 7. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_reporting_read_models ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle reporting read models"
ON public.order_lifecycle_reporting_read_models;

CREATE POLICY "Service role can manage order lifecycle reporting read models"
ON public.order_lifecycle_reporting_read_models
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 8. Migration Registry Marker
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
    106,
    'migration_106_order_lifecycle_reporting_read_models',
    'Adds cached reporting read models and dashboard view for order lifecycle, export, and delivery checkpoint tracking.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
