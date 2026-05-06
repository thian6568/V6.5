-- Migration 119: Order Lifecycle Analytics Alert Escalation Analytics
-- Purpose:
-- Adds escalation analytics tables, KPI snapshots, refresh functions,
-- dashboard views, and analytics health reporting for analytics alert escalation.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Escalation Daily Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_daily_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,

    total_escalations INTEGER NOT NULL DEFAULT 0,
    pending_escalations INTEGER NOT NULL DEFAULT 0,
    due_escalations INTEGER NOT NULL DEFAULT 0,
    notified_escalations INTEGER NOT NULL DEFAULT 0,
    resolved_escalations INTEGER NOT NULL DEFAULT 0,
    cancelled_escalations INTEGER NOT NULL DEFAULT 0,
    skipped_escalations INTEGER NOT NULL DEFAULT 0,

    low_escalations INTEGER NOT NULL DEFAULT 0,
    medium_escalations INTEGER NOT NULL DEFAULT 0,
    high_escalations INTEGER NOT NULL DEFAULT 0,
    critical_escalations INTEGER NOT NULL DEFAULT 0,

    active_escalations INTEGER NOT NULL DEFAULT 0,
    active_critical_escalations INTEGER NOT NULL DEFAULT 0,

    total_actions INTEGER NOT NULL DEFAULT 0,
    notify_actions INTEGER NOT NULL DEFAULT 0,
    resolve_actions INTEGER NOT NULL DEFAULT 0,

    avg_escalation_level NUMERIC(12, 2) NOT NULL DEFAULT 0,
    max_escalation_level_seen INTEGER NOT NULL DEFAULT 0,

    first_escalation_at TIMESTAMPTZ,
    last_escalation_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_escalation_daily_analytics
    UNIQUE (analytics_date)
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_daily_analytics IS
'Stores daily analytics for analytics alert escalation queue activity.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_daily_date
ON public.order_lifecycle_analytics_alert_escalation_daily_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_daily_payload
ON public.order_lifecycle_analytics_alert_escalation_daily_analytics USING GIN(analytics_payload);

-- ============================================================
-- 2. Escalation Policy Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_policy_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,
    policy_code TEXT NOT NULL,
    severity TEXT NOT NULL,

    total_escalations INTEGER NOT NULL DEFAULT 0,
    pending_escalations INTEGER NOT NULL DEFAULT 0,
    due_escalations INTEGER NOT NULL DEFAULT 0,
    notified_escalations INTEGER NOT NULL DEFAULT 0,
    resolved_escalations INTEGER NOT NULL DEFAULT 0,

    active_escalations INTEGER NOT NULL DEFAULT 0,

    total_actions INTEGER NOT NULL DEFAULT 0,
    notify_actions INTEGER NOT NULL DEFAULT 0,
    resolve_actions INTEGER NOT NULL DEFAULT 0,

    avg_escalation_level NUMERIC(12, 2) NOT NULL DEFAULT 0,
    max_escalation_level_seen INTEGER NOT NULL DEFAULT 0,

    first_escalation_at TIMESTAMPTZ,
    last_escalation_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_escalation_policy_analytics
    UNIQUE (analytics_date, policy_code),

    CONSTRAINT chk_oiaa_escalation_policy_analytics_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_policy_analytics IS
'Stores daily analytics for analytics alert escalation policies.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policy_date
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policy_code
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics(policy_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policy_severity
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics(severity);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policy_payload
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics USING GIN(analytics_payload);

-- ============================================================
-- 3. Escalation KPI Snapshots
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_kpi_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_code TEXT NOT NULL UNIQUE,
    snapshot_scope TEXT NOT NULL DEFAULT 'analytics_alert_escalation',

    total_escalations INTEGER NOT NULL DEFAULT 0,
    pending_escalations INTEGER NOT NULL DEFAULT 0,
    due_escalations INTEGER NOT NULL DEFAULT 0,
    notified_escalations INTEGER NOT NULL DEFAULT 0,
    resolved_escalations INTEGER NOT NULL DEFAULT 0,

    active_escalations INTEGER NOT NULL DEFAULT 0,
    active_critical_escalations INTEGER NOT NULL DEFAULT 0,

    total_policies INTEGER NOT NULL DEFAULT 0,
    enabled_policies INTEGER NOT NULL DEFAULT 0,
    disabled_policies INTEGER NOT NULL DEFAULT 0,

    total_actions INTEGER NOT NULL DEFAULT 0,
    notify_actions INTEGER NOT NULL DEFAULT 0,
    resolve_actions INTEGER NOT NULL DEFAULT 0,

    avg_escalation_level NUMERIC(12, 2) NOT NULL DEFAULT 0,
    max_escalation_level_seen INTEGER NOT NULL DEFAULT 0,

    escalation_health_status TEXT NOT NULL DEFAULT 'unknown',

    snapshot_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_kpi_snapshots IS
'Stores point-in-time KPI snapshots for analytics alert escalation performance.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_kpi_scope
ON public.order_lifecycle_analytics_alert_escalation_kpi_snapshots(snapshot_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_kpi_created
ON public.order_lifecycle_analytics_alert_escalation_kpi_snapshots(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_kpi_payload
ON public.order_lifecycle_analytics_alert_escalation_kpi_snapshots USING GIN(snapshot_payload);

-- ============================================================
-- 4. Analytics Event Log
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'recorded',

    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_analytics_events IS
'Stores analytics refresh, KPI snapshot, and reporting event history for analytics alert escalation.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_events_type
ON public.order_lifecycle_analytics_alert_escalation_analytics_events(event_type);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_events_status
ON public.order_lifecycle_analytics_alert_escalation_analytics_events(event_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_events_created
ON public.order_lifecycle_analytics_alert_escalation_analytics_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_events_payload
ON public.order_lifecycle_analytics_alert_escalation_analytics_events USING GIN(event_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_escalation_daily_analytics_updated_at
ON public.order_lifecycle_analytics_alert_escalation_daily_analytics;

CREATE TRIGGER trg_oiaa_escalation_daily_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_escalation_daily_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_analytics_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_escalation_policy_analytics_updated_at
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics;

CREATE TRIGGER trg_oiaa_escalation_policy_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_escalation_policy_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_analytics_updated_at();

-- ============================================================
-- 6. Refresh Daily Escalation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_escalation_daily_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER AS $$
DECLARE
    v_row_count INTEGER := 0;
BEGIN
    IF p_from_date IS NULL THEN
        p_from_date := CURRENT_DATE - 30;
    END IF;

    IF p_to_date IS NULL THEN
        p_to_date := CURRENT_DATE;
    END IF;

    WITH action_summary AS (
        SELECT
            escalation_id,
            COUNT(*)::INTEGER AS total_actions,
            COUNT(*) FILTER (WHERE action_type = 'notify')::INTEGER AS notify_actions,
            COUNT(*) FILTER (WHERE action_type = 'resolve')::INTEGER AS resolve_actions
        FROM public.order_lifecycle_analytics_alert_escalation_actions
        GROUP BY escalation_id
    )
    INSERT INTO public.order_lifecycle_analytics_alert_escalation_daily_analytics (
        analytics_date,
        total_escalations,
        pending_escalations,
        due_escalations,
        notified_escalations,
        resolved_escalations,
        cancelled_escalations,
        skipped_escalations,
        low_escalations,
        medium_escalations,
        high_escalations,
        critical_escalations,
        active_escalations,
        active_critical_escalations,
        total_actions,
        notify_actions,
        resolve_actions,
        avg_escalation_level,
        max_escalation_level_seen,
        first_escalation_at,
        last_escalation_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        q.created_at::DATE AS analytics_date,

        COUNT(q.id)::INTEGER AS total_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'pending')::INTEGER AS pending_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'due')::INTEGER AS due_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'notified')::INTEGER AS notified_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'resolved')::INTEGER AS resolved_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'cancelled')::INTEGER AS cancelled_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'skipped')::INTEGER AS skipped_escalations,

        COUNT(q.id) FILTER (WHERE q.severity = 'low')::INTEGER AS low_escalations,
        COUNT(q.id) FILTER (WHERE q.severity = 'medium')::INTEGER AS medium_escalations,
        COUNT(q.id) FILTER (WHERE q.severity = 'high')::INTEGER AS high_escalations,
        COUNT(q.id) FILTER (WHERE q.severity = 'critical')::INTEGER AS critical_escalations,

        COUNT(q.id) FILTER (
            WHERE q.escalation_status IN ('pending', 'due', 'notified')
        )::INTEGER AS active_escalations,

        COUNT(q.id) FILTER (
            WHERE q.severity = 'critical'
            AND q.escalation_status IN ('pending', 'due', 'notified')
        )::INTEGER AS active_critical_escalations,

        COALESCE(SUM(a.total_actions), 0)::INTEGER AS total_actions,
        COALESCE(SUM(a.notify_actions), 0)::INTEGER AS notify_actions,
        COALESCE(SUM(a.resolve_actions), 0)::INTEGER AS resolve_actions,

        COALESCE(ROUND(AVG(q.escalation_level)::NUMERIC, 2), 0) AS avg_escalation_level,
        COALESCE(MAX(q.escalation_level), 0)::INTEGER AS max_escalation_level_seen,

        MIN(q.created_at) AS first_escalation_at,
        MAX(q.created_at) AS last_escalation_at,

        jsonb_build_object(
            'analytics_date', q.created_at::DATE,
            'generated_by', 'migration_119'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_analytics_alert_escalation_queue q
    LEFT JOIN action_summary a
    ON a.escalation_id = q.id
    WHERE q.created_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY q.created_at::DATE
    ON CONFLICT (analytics_date) DO UPDATE
    SET
        total_escalations = EXCLUDED.total_escalations,
        pending_escalations = EXCLUDED.pending_escalations,
        due_escalations = EXCLUDED.due_escalations,
        notified_escalations = EXCLUDED.notified_escalations,
        resolved_escalations = EXCLUDED.resolved_escalations,
        cancelled_escalations = EXCLUDED.cancelled_escalations,
        skipped_escalations = EXCLUDED.skipped_escalations,
        low_escalations = EXCLUDED.low_escalations,
        medium_escalations = EXCLUDED.medium_escalations,
        high_escalations = EXCLUDED.high_escalations,
        critical_escalations = EXCLUDED.critical_escalations,
        active_escalations = EXCLUDED.active_escalations,
        active_critical_escalations = EXCLUDED.active_critical_escalations,
        total_actions = EXCLUDED.total_actions,
        notify_actions = EXCLUDED.notify_actions,
        resolve_actions = EXCLUDED.resolve_actions,
        avg_escalation_level = EXCLUDED.avg_escalation_level,
        max_escalation_level_seen = EXCLUDED.max_escalation_level_seen,
        first_escalation_at = EXCLUDED.first_escalation_at,
        last_escalation_at = EXCLUDED.last_escalation_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_oiaa_escalation_daily_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_119'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Refresh Policy Escalation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_escalation_policy_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER AS $$
DECLARE
    v_row_count INTEGER := 0;
BEGIN
    IF p_from_date IS NULL THEN
        p_from_date := CURRENT_DATE - 30;
    END IF;

    IF p_to_date IS NULL THEN
        p_to_date := CURRENT_DATE;
    END IF;

    WITH action_summary AS (
        SELECT
            escalation_id,
            COUNT(*)::INTEGER AS total_actions,
            COUNT(*) FILTER (WHERE action_type = 'notify')::INTEGER AS notify_actions,
            COUNT(*) FILTER (WHERE action_type = 'resolve')::INTEGER AS resolve_actions
        FROM public.order_lifecycle_analytics_alert_escalation_actions
        GROUP BY escalation_id
    )
    INSERT INTO public.order_lifecycle_analytics_alert_escalation_policy_analytics (
        analytics_date,
        policy_code,
        severity,
        total_escalations,
        pending_escalations,
        due_escalations,
        notified_escalations,
        resolved_escalations,
        active_escalations,
        total_actions,
        notify_actions,
        resolve_actions,
        avg_escalation_level,
        max_escalation_level_seen,
        first_escalation_at,
        last_escalation_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        q.created_at::DATE AS analytics_date,
        q.policy_code,
        q.severity,

        COUNT(q.id)::INTEGER AS total_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'pending')::INTEGER AS pending_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'due')::INTEGER AS due_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'notified')::INTEGER AS notified_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'resolved')::INTEGER AS resolved_escalations,

        COUNT(q.id) FILTER (
            WHERE q.escalation_status IN ('pending', 'due', 'notified')
        )::INTEGER AS active_escalations,

        COALESCE(SUM(a.total_actions), 0)::INTEGER AS total_actions,
        COALESCE(SUM(a.notify_actions), 0)::INTEGER AS notify_actions,
        COALESCE(SUM(a.resolve_actions), 0)::INTEGER AS resolve_actions,

        COALESCE(ROUND(AVG(q.escalation_level)::NUMERIC, 2), 0) AS avg_escalation_level,
        COALESCE(MAX(q.escalation_level), 0)::INTEGER AS max_escalation_level_seen,

        MIN(q.created_at) AS first_escalation_at,
        MAX(q.created_at) AS last_escalation_at,

        jsonb_build_object(
            'analytics_date', q.created_at::DATE,
            'policy_code', q.policy_code,
            'severity', q.severity,
            'generated_by', 'migration_119'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_analytics_alert_escalation_queue q
    LEFT JOIN action_summary a
    ON a.escalation_id = q.id
    WHERE q.created_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY
        q.created_at::DATE,
        q.policy_code,
        q.severity
    ON CONFLICT (analytics_date, policy_code) DO UPDATE
    SET
        severity = EXCLUDED.severity,
        total_escalations = EXCLUDED.total_escalations,
        pending_escalations = EXCLUDED.pending_escalations,
        due_escalations = EXCLUDED.due_escalations,
        notified_escalations = EXCLUDED.notified_escalations,
        resolved_escalations = EXCLUDED.resolved_escalations,
        active_escalations = EXCLUDED.active_escalations,
        total_actions = EXCLUDED.total_actions,
        notify_actions = EXCLUDED.notify_actions,
        resolve_actions = EXCLUDED.resolve_actions,
        avg_escalation_level = EXCLUDED.avg_escalation_level,
        max_escalation_level_seen = EXCLUDED.max_escalation_level_seen,
        first_escalation_at = EXCLUDED.first_escalation_at,
        last_escalation_at = EXCLUDED.last_escalation_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_oiaa_escalation_policy_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_119'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Create Escalation KPI Snapshot
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_oiaa_escalation_kpi_snapshot(
    p_snapshot_scope TEXT DEFAULT 'analytics_alert_escalation'
)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_snapshot_code TEXT;
    v_health_status TEXT;
BEGIN
    v_snapshot_code := 'oiaa_escalation_kpi_'
        || to_char(NOW(), 'YYYYMMDDHH24MISSMS')
        || '_'
        || replace(gen_random_uuid()::TEXT, '-', '');

    SELECT
        CASE
            WHEN COUNT(*) = 0 THEN 'no_escalations'
            WHEN COUNT(*) FILTER (
                WHERE severity = 'critical'
                AND escalation_status IN ('pending', 'due', 'notified')
            ) > 0 THEN 'critical_attention'
            WHEN COUNT(*) FILTER (WHERE escalation_status = 'due') > 0 THEN 'due'
            WHEN COUNT(*) FILTER (WHERE escalation_status IN ('pending', 'notified')) > 0 THEN 'active'
            ELSE 'healthy'
        END
    INTO v_health_status
    FROM public.order_lifecycle_analytics_alert_escalation_queue;

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_kpi_snapshots (
        snapshot_code,
        snapshot_scope,
        total_escalations,
        pending_escalations,
        due_escalations,
        notified_escalations,
        resolved_escalations,
        active_escalations,
        active_critical_escalations,
        total_policies,
        enabled_policies,
        disabled_policies,
        total_actions,
        notify_actions,
        resolve_actions,
        avg_escalation_level,
        max_escalation_level_seen,
        escalation_health_status,
        snapshot_payload,
        created_at
    )
    SELECT
        v_snapshot_code,
        COALESCE(p_snapshot_scope, 'analytics_alert_escalation'),

        COUNT(q.id)::INTEGER AS total_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'pending')::INTEGER AS pending_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'due')::INTEGER AS due_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'notified')::INTEGER AS notified_escalations,
        COUNT(q.id) FILTER (WHERE q.escalation_status = 'resolved')::INTEGER AS resolved_escalations,

        COUNT(q.id) FILTER (
            WHERE q.escalation_status IN ('pending', 'due', 'notified')
        )::INTEGER AS active_escalations,

        COUNT(q.id) FILTER (
            WHERE q.severity = 'critical'
            AND q.escalation_status IN ('pending', 'due', 'notified')
        )::INTEGER AS active_critical_escalations,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_policies
        ) AS total_policies,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_policies
            WHERE is_enabled = TRUE
        ) AS enabled_policies,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_policies
            WHERE is_enabled = FALSE
        ) AS disabled_policies,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_actions
        ) AS total_actions,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_actions
            WHERE action_type = 'notify'
        ) AS notify_actions,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_escalation_actions
            WHERE action_type = 'resolve'
        ) AS resolve_actions,

        COALESCE(ROUND(AVG(q.escalation_level)::NUMERIC, 2), 0) AS avg_escalation_level,
        COALESCE(MAX(q.escalation_level), 0)::INTEGER AS max_escalation_level_seen,

        COALESCE(v_health_status, 'unknown') AS escalation_health_status,

        jsonb_build_object(
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_escalation'),
            'escalation_health_status', COALESCE(v_health_status, 'unknown'),
            'generated_by', 'migration_119',
            'generated_at', NOW()
        ) AS snapshot_payload,

        NOW()
    FROM public.order_lifecycle_analytics_alert_escalation_queue q
    RETURNING id INTO v_snapshot_id;

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'create_oiaa_escalation_kpi_snapshot',
        'completed',
        jsonb_build_object(
            'snapshot_id', v_snapshot_id,
            'snapshot_code', v_snapshot_code,
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_escalation'),
            'generated_by', 'migration_119'
        ),
        NOW()
    );

    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Refresh All Escalation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_oiaa_escalation_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_daily_count INTEGER := 0;
    v_policy_count INTEGER := 0;
    v_snapshot_id UUID;
    v_result JSONB;
BEGIN
    v_daily_count := public.refresh_oiaa_escalation_daily_analytics(
        p_from_date,
        p_to_date
    );

    v_policy_count := public.refresh_oiaa_escalation_policy_analytics(
        p_from_date,
        p_to_date
    );

    v_snapshot_id := public.create_oiaa_escalation_kpi_snapshot(
        'analytics_alert_escalation'
    );

    v_result := jsonb_build_object(
        'daily_analytics_rows', v_daily_count,
        'policy_analytics_rows', v_policy_count,
        'snapshot_id', v_snapshot_id,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'generated_by', 'migration_119'
    );

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_all_oiaa_escalation_analytics',
        'completed',
        v_result,
        NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.oiaa_escalation_daily_analytics_dashboard_view AS
SELECT
    id,
    analytics_date,
    total_escalations,
    pending_escalations,
    due_escalations,
    notified_escalations,
    resolved_escalations,
    cancelled_escalations,
    skipped_escalations,
    low_escalations,
    medium_escalations,
    high_escalations,
    critical_escalations,
    active_escalations,
    active_critical_escalations,
    total_actions,
    notify_actions,
    resolve_actions,
    avg_escalation_level,
    max_escalation_level_seen,
    CASE
        WHEN active_critical_escalations > 0 THEN 'critical_attention'
        WHEN due_escalations > 0 THEN 'due'
        WHEN active_escalations > 0 THEN 'active'
        WHEN resolved_escalations > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS analytics_dashboard_status,
    first_escalation_at,
    last_escalation_at,
    analytics_payload,
    generated_at,
    updated_at
FROM public.order_lifecycle_analytics_alert_escalation_daily_analytics;

COMMENT ON VIEW public.oiaa_escalation_daily_analytics_dashboard_view IS
'Admin dashboard view for daily analytics alert escalation analytics.';

CREATE OR REPLACE VIEW public.oiaa_escalation_policy_analytics_dashboard_view AS
SELECT
    a.id,
    a.analytics_date,
    a.policy_code,
    p.policy_name,
    a.severity,
    a.total_escalations,
    a.pending_escalations,
    a.due_escalations,
    a.notified_escalations,
    a.resolved_escalations,
    a.active_escalations,
    a.total_actions,
    a.notify_actions,
    a.resolve_actions,
    a.avg_escalation_level,
    a.max_escalation_level_seen,
    CASE
        WHEN a.severity = 'critical' AND a.active_escalations > 0 THEN 'critical_attention'
        WHEN a.due_escalations > 0 THEN 'due'
        WHEN a.active_escalations > 0 THEN 'active'
        WHEN a.resolved_escalations > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS policy_analytics_status,
    a.first_escalation_at,
    a.last_escalation_at,
    a.analytics_payload,
    a.generated_at,
    a.updated_at
FROM public.order_lifecycle_analytics_alert_escalation_policy_analytics a
LEFT JOIN public.order_lifecycle_analytics_alert_escalation_policies p
ON p.policy_code = a.policy_code;

COMMENT ON VIEW public.oiaa_escalation_policy_analytics_dashboard_view IS
'Admin dashboard view for escalation analytics by policy.';

CREATE OR REPLACE VIEW public.oiaa_escalation_latest_kpi_view AS
SELECT
    *
FROM public.order_lifecycle_analytics_alert_escalation_kpi_snapshots
WHERE created_at = (
    SELECT MAX(created_at)
    FROM public.order_lifecycle_analytics_alert_escalation_kpi_snapshots
);

COMMENT ON VIEW public.oiaa_escalation_latest_kpi_view IS
'Shows the latest analytics alert escalation KPI snapshot.';

CREATE OR REPLACE VIEW public.oiaa_escalation_analytics_health_view AS
SELECT
    'daily_escalation_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_escalation_daily_analytics

UNION ALL

SELECT
    'policy_escalation_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_escalation_policy_analytics

UNION ALL

SELECT
    'escalation_kpi_snapshots' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(created_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(created_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_escalation_kpi_snapshots;

COMMENT ON VIEW public.oiaa_escalation_analytics_health_view IS
'Shows freshness and health status for analytics alert escalation analytics datasets.';

-- ============================================================
-- 11. Initial Backfill
-- ============================================================

SELECT public.refresh_all_oiaa_escalation_analytics(
    CURRENT_DATE - 30,
    CURRENT_DATE
);

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_escalation_daily_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_escalation_policy_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_escalation_kpi_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_escalation_analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_daily_analytics"
ON public.order_lifecycle_analytics_alert_escalation_daily_analytics;

CREATE POLICY "svc_manage_oiaa_escalation_daily_analytics"
ON public.order_lifecycle_analytics_alert_escalation_daily_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_policy_analytics"
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics;

CREATE POLICY "svc_manage_oiaa_escalation_policy_analytics"
ON public.order_lifecycle_analytics_alert_escalation_policy_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_kpi_snapshots"
ON public.order_lifecycle_analytics_alert_escalation_kpi_snapshots;

CREATE POLICY "svc_manage_oiaa_escalation_kpi_snapshots"
ON public.order_lifecycle_analytics_alert_escalation_kpi_snapshots
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_analytics_events"
ON public.order_lifecycle_analytics_alert_escalation_analytics_events;

CREATE POLICY "svc_manage_oiaa_escalation_analytics_events"
ON public.order_lifecycle_analytics_alert_escalation_analytics_events
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 13. Migration Registry Marker
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
    119,
    'migration_119_order_lifecycle_analytics_alert_escalation_analytics',
    'Adds escalation analytics tables, KPI snapshots, refresh functions, dashboard views, and analytics health reporting for analytics alert escalation.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
