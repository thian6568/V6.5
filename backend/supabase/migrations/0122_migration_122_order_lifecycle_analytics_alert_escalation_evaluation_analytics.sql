-- Migration 122: Order Lifecycle Analytics Alert Escalation Evaluation Analytics
-- Purpose:
-- Adds analytics tables, KPI snapshots, refresh functions, dashboard views,
-- and health reporting for analytics alert escalation scheduled evaluation.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Escalation Evaluation Daily Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_daily_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,

    total_runs INTEGER NOT NULL DEFAULT 0,
    created_runs INTEGER NOT NULL DEFAULT 0,
    running_runs INTEGER NOT NULL DEFAULT 0,
    completed_runs INTEGER NOT NULL DEFAULT 0,
    failed_runs INTEGER NOT NULL DEFAULT 0,
    cancelled_runs INTEGER NOT NULL DEFAULT 0,
    skipped_runs INTEGER NOT NULL DEFAULT 0,

    total_created_count INTEGER NOT NULL DEFAULT 0,
    total_due_count INTEGER NOT NULL DEFAULT 0,
    total_notified_count INTEGER NOT NULL DEFAULT 0,
    total_resolved_count INTEGER NOT NULL DEFAULT 0,

    total_steps INTEGER NOT NULL DEFAULT 0,
    completed_steps INTEGER NOT NULL DEFAULT 0,
    failed_steps INTEGER NOT NULL DEFAULT 0,
    skipped_steps INTEGER NOT NULL DEFAULT 0,

    avg_run_duration_seconds NUMERIC(12, 2) NOT NULL DEFAULT 0,

    first_run_at TIMESTAMPTZ,
    last_run_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_escalation_evaluation_daily_analytics
    UNIQUE (analytics_date)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_daily_analytics IS
'Stores daily analytics for analytics alert escalation scheduled evaluation runs.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_daily_date
ON public.oiaa_escalation_evaluation_daily_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_daily_payload
ON public.oiaa_escalation_evaluation_daily_analytics USING GIN(analytics_payload);

-- ============================================================
-- 2. Escalation Evaluation Schedule Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_schedule_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,
    schedule_code TEXT NOT NULL,
    evaluation_scope TEXT NOT NULL DEFAULT 'all',

    total_runs INTEGER NOT NULL DEFAULT 0,
    created_runs INTEGER NOT NULL DEFAULT 0,
    running_runs INTEGER NOT NULL DEFAULT 0,
    completed_runs INTEGER NOT NULL DEFAULT 0,
    failed_runs INTEGER NOT NULL DEFAULT 0,
    cancelled_runs INTEGER NOT NULL DEFAULT 0,
    skipped_runs INTEGER NOT NULL DEFAULT 0,

    total_created_count INTEGER NOT NULL DEFAULT 0,
    total_due_count INTEGER NOT NULL DEFAULT 0,
    total_notified_count INTEGER NOT NULL DEFAULT 0,
    total_resolved_count INTEGER NOT NULL DEFAULT 0,

    total_steps INTEGER NOT NULL DEFAULT 0,
    completed_steps INTEGER NOT NULL DEFAULT 0,
    failed_steps INTEGER NOT NULL DEFAULT 0,
    skipped_steps INTEGER NOT NULL DEFAULT 0,

    avg_run_duration_seconds NUMERIC(12, 2) NOT NULL DEFAULT 0,

    first_run_at TIMESTAMPTZ,
    last_run_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_escalation_evaluation_schedule_analytics
    UNIQUE (analytics_date, schedule_code)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_schedule_analytics IS
'Stores daily analytics for analytics alert escalation evaluation schedules.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedule_date
ON public.oiaa_escalation_evaluation_schedule_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedule_code
ON public.oiaa_escalation_evaluation_schedule_analytics(schedule_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedule_scope
ON public.oiaa_escalation_evaluation_schedule_analytics(evaluation_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedule_payload
ON public.oiaa_escalation_evaluation_schedule_analytics USING GIN(analytics_payload);

-- ============================================================
-- 3. Escalation Evaluation KPI Snapshots
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_kpi_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_code TEXT NOT NULL UNIQUE,
    snapshot_scope TEXT NOT NULL DEFAULT 'analytics_alert_escalation_evaluation',

    total_schedules INTEGER NOT NULL DEFAULT 0,
    enabled_schedules INTEGER NOT NULL DEFAULT 0,
    disabled_schedules INTEGER NOT NULL DEFAULT 0,
    due_schedules INTEGER NOT NULL DEFAULT 0,

    total_runs INTEGER NOT NULL DEFAULT 0,
    completed_runs INTEGER NOT NULL DEFAULT 0,
    failed_runs INTEGER NOT NULL DEFAULT 0,
    skipped_runs INTEGER NOT NULL DEFAULT 0,

    total_created_count INTEGER NOT NULL DEFAULT 0,
    total_due_count INTEGER NOT NULL DEFAULT 0,
    total_notified_count INTEGER NOT NULL DEFAULT 0,
    total_resolved_count INTEGER NOT NULL DEFAULT 0,

    total_steps INTEGER NOT NULL DEFAULT 0,
    completed_steps INTEGER NOT NULL DEFAULT 0,
    failed_steps INTEGER NOT NULL DEFAULT 0,

    latest_run_at TIMESTAMPTZ,
    latest_run_status TEXT,

    evaluation_health_status TEXT NOT NULL DEFAULT 'unknown',

    snapshot_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_kpi_snapshots IS
'Stores point-in-time KPI snapshots for analytics alert escalation scheduled evaluation performance.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_kpi_scope
ON public.oiaa_escalation_evaluation_kpi_snapshots(snapshot_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_kpi_created
ON public.oiaa_escalation_evaluation_kpi_snapshots(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_kpi_payload
ON public.oiaa_escalation_evaluation_kpi_snapshots USING GIN(snapshot_payload);

-- ============================================================
-- 4. Escalation Evaluation Analytics Events
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'recorded',

    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_analytics_events IS
'Stores analytics refresh, KPI snapshot, and reporting event history for analytics alert escalation scheduled evaluation.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_events_type
ON public.oiaa_escalation_evaluation_analytics_events(event_type);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_events_status
ON public.oiaa_escalation_evaluation_analytics_events(event_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_events_created
ON public.oiaa_escalation_evaluation_analytics_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_events_payload
ON public.oiaa_escalation_evaluation_analytics_events USING GIN(event_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_evaluation_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_escalation_eval_daily_analytics_updated_at
ON public.oiaa_escalation_evaluation_daily_analytics;

CREATE TRIGGER trg_oiaa_escalation_eval_daily_analytics_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_daily_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_analytics_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_escalation_eval_schedule_analytics_updated_at
ON public.oiaa_escalation_evaluation_schedule_analytics;

CREATE TRIGGER trg_oiaa_escalation_eval_schedule_analytics_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_schedule_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_analytics_updated_at();

-- ============================================================
-- 6. Refresh Daily Evaluation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_escalation_evaluation_daily_analytics(
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

    WITH step_summary AS (
        SELECT
            evaluation_run_id,
            COUNT(*)::INTEGER AS total_steps,
            COUNT(*) FILTER (WHERE step_status = 'completed')::INTEGER AS completed_steps,
            COUNT(*) FILTER (WHERE step_status = 'failed')::INTEGER AS failed_steps,
            COUNT(*) FILTER (WHERE step_status = 'skipped')::INTEGER AS skipped_steps
        FROM public.oiaa_escalation_evaluation_run_steps
        GROUP BY evaluation_run_id
    )
    INSERT INTO public.oiaa_escalation_evaluation_daily_analytics (
        analytics_date,
        total_runs,
        created_runs,
        running_runs,
        completed_runs,
        failed_runs,
        cancelled_runs,
        skipped_runs,
        total_created_count,
        total_due_count,
        total_notified_count,
        total_resolved_count,
        total_steps,
        completed_steps,
        failed_steps,
        skipped_steps,
        avg_run_duration_seconds,
        first_run_at,
        last_run_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        r.created_at::DATE AS analytics_date,

        COUNT(r.id)::INTEGER AS total_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'created')::INTEGER AS created_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'running')::INTEGER AS running_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'completed')::INTEGER AS completed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'failed')::INTEGER AS failed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'cancelled')::INTEGER AS cancelled_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'skipped')::INTEGER AS skipped_runs,

        COALESCE(SUM(r.created_count), 0)::INTEGER AS total_created_count,
        COALESCE(SUM(r.due_count), 0)::INTEGER AS total_due_count,
        COALESCE(SUM(r.notified_count), 0)::INTEGER AS total_notified_count,
        COALESCE(SUM(r.resolved_count), 0)::INTEGER AS total_resolved_count,

        COALESCE(SUM(s.total_steps), 0)::INTEGER AS total_steps,
        COALESCE(SUM(s.completed_steps), 0)::INTEGER AS completed_steps,
        COALESCE(SUM(s.failed_steps), 0)::INTEGER AS failed_steps,
        COALESCE(SUM(s.skipped_steps), 0)::INTEGER AS skipped_steps,

        COALESCE(
            ROUND(
                AVG(
                    EXTRACT(
                        EPOCH FROM (
                            COALESCE(r.completed_at, r.failed_at, NOW())
                            - COALESCE(r.started_at, r.created_at)
                        )
                    )
                )::NUMERIC,
                2
            ),
            0
        ) AS avg_run_duration_seconds,

        MIN(r.created_at) AS first_run_at,
        MAX(r.created_at) AS last_run_at,

        jsonb_build_object(
            'analytics_date', r.created_at::DATE,
            'generated_by', 'migration_122'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.oiaa_escalation_evaluation_runs r
    LEFT JOIN step_summary s
    ON s.evaluation_run_id = r.id
    WHERE r.created_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY r.created_at::DATE
    ON CONFLICT (analytics_date) DO UPDATE
    SET
        total_runs = EXCLUDED.total_runs,
        created_runs = EXCLUDED.created_runs,
        running_runs = EXCLUDED.running_runs,
        completed_runs = EXCLUDED.completed_runs,
        failed_runs = EXCLUDED.failed_runs,
        cancelled_runs = EXCLUDED.cancelled_runs,
        skipped_runs = EXCLUDED.skipped_runs,
        total_created_count = EXCLUDED.total_created_count,
        total_due_count = EXCLUDED.total_due_count,
        total_notified_count = EXCLUDED.total_notified_count,
        total_resolved_count = EXCLUDED.total_resolved_count,
        total_steps = EXCLUDED.total_steps,
        completed_steps = EXCLUDED.completed_steps,
        failed_steps = EXCLUDED.failed_steps,
        skipped_steps = EXCLUDED.skipped_steps,
        avg_run_duration_seconds = EXCLUDED.avg_run_duration_seconds,
        first_run_at = EXCLUDED.first_run_at,
        last_run_at = EXCLUDED.last_run_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_oiaa_escalation_evaluation_daily_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_122'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Refresh Schedule Evaluation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_escalation_evaluation_schedule_analytics(
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

    WITH step_summary AS (
        SELECT
            evaluation_run_id,
            COUNT(*)::INTEGER AS total_steps,
            COUNT(*) FILTER (WHERE step_status = 'completed')::INTEGER AS completed_steps,
            COUNT(*) FILTER (WHERE step_status = 'failed')::INTEGER AS failed_steps,
            COUNT(*) FILTER (WHERE step_status = 'skipped')::INTEGER AS skipped_steps
        FROM public.oiaa_escalation_evaluation_run_steps
        GROUP BY evaluation_run_id
    )
    INSERT INTO public.oiaa_escalation_evaluation_schedule_analytics (
        analytics_date,
        schedule_code,
        evaluation_scope,
        total_runs,
        created_runs,
        running_runs,
        completed_runs,
        failed_runs,
        cancelled_runs,
        skipped_runs,
        total_created_count,
        total_due_count,
        total_notified_count,
        total_resolved_count,
        total_steps,
        completed_steps,
        failed_steps,
        skipped_steps,
        avg_run_duration_seconds,
        first_run_at,
        last_run_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        r.created_at::DATE AS analytics_date,
        COALESCE(r.schedule_code, 'manual') AS schedule_code,
        COALESCE(r.evaluation_scope, 'all') AS evaluation_scope,

        COUNT(r.id)::INTEGER AS total_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'created')::INTEGER AS created_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'running')::INTEGER AS running_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'completed')::INTEGER AS completed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'failed')::INTEGER AS failed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'cancelled')::INTEGER AS cancelled_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'skipped')::INTEGER AS skipped_runs,

        COALESCE(SUM(r.created_count), 0)::INTEGER AS total_created_count,
        COALESCE(SUM(r.due_count), 0)::INTEGER AS total_due_count,
        COALESCE(SUM(r.notified_count), 0)::INTEGER AS total_notified_count,
        COALESCE(SUM(r.resolved_count), 0)::INTEGER AS total_resolved_count,

        COALESCE(SUM(s.total_steps), 0)::INTEGER AS total_steps,
        COALESCE(SUM(s.completed_steps), 0)::INTEGER AS completed_steps,
        COALESCE(SUM(s.failed_steps), 0)::INTEGER AS failed_steps,
        COALESCE(SUM(s.skipped_steps), 0)::INTEGER AS skipped_steps,

        COALESCE(
            ROUND(
                AVG(
                    EXTRACT(
                        EPOCH FROM (
                            COALESCE(r.completed_at, r.failed_at, NOW())
                            - COALESCE(r.started_at, r.created_at)
                        )
                    )
                )::NUMERIC,
                2
            ),
            0
        ) AS avg_run_duration_seconds,

        MIN(r.created_at) AS first_run_at,
        MAX(r.created_at) AS last_run_at,

        jsonb_build_object(
            'analytics_date', r.created_at::DATE,
            'schedule_code', COALESCE(r.schedule_code, 'manual'),
            'evaluation_scope', COALESCE(r.evaluation_scope, 'all'),
            'generated_by', 'migration_122'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.oiaa_escalation_evaluation_runs r
    LEFT JOIN step_summary s
    ON s.evaluation_run_id = r.id
    WHERE r.created_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY
        r.created_at::DATE,
        COALESCE(r.schedule_code, 'manual'),
        COALESCE(r.evaluation_scope, 'all')
    ON CONFLICT (analytics_date, schedule_code) DO UPDATE
    SET
        evaluation_scope = EXCLUDED.evaluation_scope,
        total_runs = EXCLUDED.total_runs,
        created_runs = EXCLUDED.created_runs,
        running_runs = EXCLUDED.running_runs,
        completed_runs = EXCLUDED.completed_runs,
        failed_runs = EXCLUDED.failed_runs,
        cancelled_runs = EXCLUDED.cancelled_runs,
        skipped_runs = EXCLUDED.skipped_runs,
        total_created_count = EXCLUDED.total_created_count,
        total_due_count = EXCLUDED.total_due_count,
        total_notified_count = EXCLUDED.total_notified_count,
        total_resolved_count = EXCLUDED.total_resolved_count,
        total_steps = EXCLUDED.total_steps,
        completed_steps = EXCLUDED.completed_steps,
        failed_steps = EXCLUDED.failed_steps,
        skipped_steps = EXCLUDED.skipped_steps,
        avg_run_duration_seconds = EXCLUDED.avg_run_duration_seconds,
        first_run_at = EXCLUDED.first_run_at,
        last_run_at = EXCLUDED.last_run_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_oiaa_escalation_evaluation_schedule_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_122'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Create Evaluation KPI Snapshot
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_oiaa_escalation_evaluation_kpi_snapshot(
    p_snapshot_scope TEXT DEFAULT 'analytics_alert_escalation_evaluation'
)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_snapshot_code TEXT;
    v_latest_run_at TIMESTAMPTZ;
    v_latest_run_status TEXT;
    v_health_status TEXT;
BEGIN
    v_snapshot_code := 'oiaa_escalation_eval_kpi_'
        || to_char(NOW(), 'YYYYMMDDHH24MISSMS')
        || '_'
        || replace(gen_random_uuid()::TEXT, '-', '');

    SELECT
        created_at,
        run_status
    INTO
        v_latest_run_at,
        v_latest_run_status
    FROM public.oiaa_escalation_evaluation_runs
    ORDER BY created_at DESC
    LIMIT 1;

    SELECT
        CASE
            WHEN COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at <= NOW()) > 0 THEN 'due'
            WHEN v_latest_run_at IS NULL THEN 'not_started'
            WHEN v_latest_run_status = 'failed' THEN 'attention_required'
            WHEN v_latest_run_at < NOW() - INTERVAL '1 hour' THEN 'stale'
            ELSE 'healthy'
        END
    INTO v_health_status
    FROM public.oiaa_escalation_evaluation_schedules;

    INSERT INTO public.oiaa_escalation_evaluation_kpi_snapshots (
        snapshot_code,
        snapshot_scope,
        total_schedules,
        enabled_schedules,
        disabled_schedules,
        due_schedules,
        total_runs,
        completed_runs,
        failed_runs,
        skipped_runs,
        total_created_count,
        total_due_count,
        total_notified_count,
        total_resolved_count,
        total_steps,
        completed_steps,
        failed_steps,
        latest_run_at,
        latest_run_status,
        evaluation_health_status,
        snapshot_payload,
        created_at
    )
    SELECT
        v_snapshot_code,
        COALESCE(p_snapshot_scope, 'analytics_alert_escalation_evaluation'),

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_schedules
        ) AS total_schedules,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_schedules
            WHERE is_enabled = TRUE
        ) AS enabled_schedules,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_schedules
            WHERE is_enabled = FALSE
        ) AS disabled_schedules,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_schedules
            WHERE is_enabled = TRUE
            AND next_run_at <= NOW()
        ) AS due_schedules,

        COUNT(r.id)::INTEGER AS total_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'completed')::INTEGER AS completed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'failed')::INTEGER AS failed_runs,
        COUNT(r.id) FILTER (WHERE r.run_status = 'skipped')::INTEGER AS skipped_runs,

        COALESCE(SUM(r.created_count), 0)::INTEGER AS total_created_count,
        COALESCE(SUM(r.due_count), 0)::INTEGER AS total_due_count,
        COALESCE(SUM(r.notified_count), 0)::INTEGER AS total_notified_count,
        COALESCE(SUM(r.resolved_count), 0)::INTEGER AS total_resolved_count,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_run_steps
        ) AS total_steps,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_run_steps
            WHERE step_status = 'completed'
        ) AS completed_steps,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.oiaa_escalation_evaluation_run_steps
            WHERE step_status = 'failed'
        ) AS failed_steps,

        v_latest_run_at,
        v_latest_run_status,
        COALESCE(v_health_status, 'unknown') AS evaluation_health_status,

        jsonb_build_object(
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_escalation_evaluation'),
            'latest_run_status', v_latest_run_status,
            'evaluation_health_status', COALESCE(v_health_status, 'unknown'),
            'generated_by', 'migration_122',
            'generated_at', NOW()
        ) AS snapshot_payload,

        NOW()
    FROM public.oiaa_escalation_evaluation_runs r
    RETURNING id INTO v_snapshot_id;

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'create_oiaa_escalation_evaluation_kpi_snapshot',
        'completed',
        jsonb_build_object(
            'snapshot_id', v_snapshot_id,
            'snapshot_code', v_snapshot_code,
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_escalation_evaluation'),
            'generated_by', 'migration_122'
        ),
        NOW()
    );

    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Refresh All Evaluation Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_oiaa_escalation_evaluation_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_daily_count INTEGER := 0;
    v_schedule_count INTEGER := 0;
    v_snapshot_id UUID;
    v_result JSONB;
BEGIN
    v_daily_count := public.refresh_oiaa_escalation_evaluation_daily_analytics(
        p_from_date,
        p_to_date
    );

    v_schedule_count := public.refresh_oiaa_escalation_evaluation_schedule_analytics(
        p_from_date,
        p_to_date
    );

    v_snapshot_id := public.create_oiaa_escalation_evaluation_kpi_snapshot(
        'analytics_alert_escalation_evaluation'
    );

    v_result := jsonb_build_object(
        'daily_analytics_rows', v_daily_count,
        'schedule_analytics_rows', v_schedule_count,
        'snapshot_id', v_snapshot_id,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'generated_by', 'migration_122'
    );

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_all_oiaa_escalation_evaluation_analytics',
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

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_daily_dashboard_view AS
SELECT
    id,
    analytics_date,
    total_runs,
    created_runs,
    running_runs,
    completed_runs,
    failed_runs,
    cancelled_runs,
    skipped_runs,
    total_created_count,
    total_due_count,
    total_notified_count,
    total_resolved_count,
    total_steps,
    completed_steps,
    failed_steps,
    skipped_steps,
    avg_run_duration_seconds,
    CASE
        WHEN failed_runs > 0 THEN 'attention_required'
        WHEN running_runs > 0 THEN 'running'
        WHEN completed_runs > 0 AND total_notified_count > 0 THEN 'notifications_created'
        WHEN completed_runs > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS analytics_dashboard_status,
    first_run_at,
    last_run_at,
    analytics_payload,
    generated_at,
    updated_at
FROM public.oiaa_escalation_evaluation_daily_analytics;

COMMENT ON VIEW public.oiaa_escalation_evaluation_daily_dashboard_view IS
'Admin dashboard view for daily analytics alert escalation evaluation analytics.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_schedule_dashboard_view AS
SELECT
    a.id,
    a.analytics_date,
    a.schedule_code,
    s.schedule_name,
    a.evaluation_scope,
    a.total_runs,
    a.created_runs,
    a.running_runs,
    a.completed_runs,
    a.failed_runs,
    a.cancelled_runs,
    a.skipped_runs,
    a.total_created_count,
    a.total_due_count,
    a.total_notified_count,
    a.total_resolved_count,
    a.total_steps,
    a.completed_steps,
    a.failed_steps,
    a.skipped_steps,
    a.avg_run_duration_seconds,
    CASE
        WHEN a.failed_runs > 0 THEN 'attention_required'
        WHEN a.running_runs > 0 THEN 'running'
        WHEN a.completed_runs > 0 AND a.total_notified_count > 0 THEN 'notifications_created'
        WHEN a.completed_runs > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS schedule_analytics_status,
    a.first_run_at,
    a.last_run_at,
    a.analytics_payload,
    a.generated_at,
    a.updated_at
FROM public.oiaa_escalation_evaluation_schedule_analytics a
LEFT JOIN public.oiaa_escalation_evaluation_schedules s
ON s.schedule_code = a.schedule_code;

COMMENT ON VIEW public.oiaa_escalation_evaluation_schedule_dashboard_view IS
'Admin dashboard view for analytics alert escalation evaluation analytics by schedule.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_latest_kpi_view AS
SELECT
    *
FROM public.oiaa_escalation_evaluation_kpi_snapshots
WHERE created_at = (
    SELECT MAX(created_at)
    FROM public.oiaa_escalation_evaluation_kpi_snapshots
);

COMMENT ON VIEW public.oiaa_escalation_evaluation_latest_kpi_view IS
'Shows the latest analytics alert escalation evaluation KPI snapshot.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_analytics_health_view AS
SELECT
    'daily_evaluation_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.oiaa_escalation_evaluation_daily_analytics

UNION ALL

SELECT
    'schedule_evaluation_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.oiaa_escalation_evaluation_schedule_analytics

UNION ALL

SELECT
    'evaluation_kpi_snapshots' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(created_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(created_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.oiaa_escalation_evaluation_kpi_snapshots;

COMMENT ON VIEW public.oiaa_escalation_evaluation_analytics_health_view IS
'Shows freshness and health status for analytics alert escalation evaluation analytics datasets.';

-- ============================================================
-- 11. Initial Backfill
-- ============================================================

SELECT public.refresh_all_oiaa_escalation_evaluation_analytics(
    CURRENT_DATE - 30,
    CURRENT_DATE
);

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.oiaa_escalation_evaluation_daily_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_schedule_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_kpi_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_eval_daily_analytics"
ON public.oiaa_escalation_evaluation_daily_analytics;

CREATE POLICY "svc_manage_oiaa_escalation_eval_daily_analytics"
ON public.oiaa_escalation_evaluation_daily_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_eval_schedule_analytics"
ON public.oiaa_escalation_evaluation_schedule_analytics;

CREATE POLICY "svc_manage_oiaa_escalation_eval_schedule_analytics"
ON public.oiaa_escalation_evaluation_schedule_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_eval_kpi_snapshots"
ON public.oiaa_escalation_evaluation_kpi_snapshots;

CREATE POLICY "svc_manage_oiaa_escalation_eval_kpi_snapshots"
ON public.oiaa_escalation_evaluation_kpi_snapshots
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_eval_analytics_events"
ON public.oiaa_escalation_evaluation_analytics_events;

CREATE POLICY "svc_manage_oiaa_escalation_eval_analytics_events"
ON public.oiaa_escalation_evaluation_analytics_events
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
    122,
    'migration_122_order_lifecycle_analytics_alert_escalation_evaluation_analytics',
    'Adds analytics tables, KPI snapshots, refresh functions, dashboard views, and health reporting for analytics alert escalation scheduled evaluation.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
