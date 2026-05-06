-- Migration 116: Order Lifecycle Analytics Alert Dispatch Analytics
-- Purpose:
-- Adds analytics tables, KPI snapshots, refresh functions, and dashboard views
-- for analytics alert notification dispatch performance.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Alert Dispatch Daily Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_dispatch_daily_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,
    channel_code TEXT NOT NULL,
    channel_type TEXT NOT NULL DEFAULT 'unknown',

    total_jobs INTEGER NOT NULL DEFAULT 0,
    pending_jobs INTEGER NOT NULL DEFAULT 0,
    locked_jobs INTEGER NOT NULL DEFAULT 0,
    sent_jobs INTEGER NOT NULL DEFAULT 0,
    failed_jobs INTEGER NOT NULL DEFAULT 0,
    cancelled_jobs INTEGER NOT NULL DEFAULT 0,
    skipped_jobs INTEGER NOT NULL DEFAULT 0,

    ready_jobs INTEGER NOT NULL DEFAULT 0,
    stale_lock_jobs INTEGER NOT NULL DEFAULT 0,
    dead_letter_jobs INTEGER NOT NULL DEFAULT 0,

    total_attempts INTEGER NOT NULL DEFAULT 0,
    sent_attempts INTEGER NOT NULL DEFAULT 0,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    cancelled_attempts INTEGER NOT NULL DEFAULT 0,
    skipped_attempts INTEGER NOT NULL DEFAULT 0,

    avg_attempt_count NUMERIC(12, 2) NOT NULL DEFAULT 0,
    success_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,
    failure_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,

    first_job_at TIMESTAMPTZ,
    last_job_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_dispatch_daily_analytics
    UNIQUE (analytics_date, channel_code)
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_dispatch_daily_analytics IS
'Stores daily analytics for analytics alert notification dispatch jobs by channel.';

CREATE INDEX IF NOT EXISTS idx_oiaa_daily_date
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_daily_channel
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics(channel_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_daily_payload
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics USING GIN(analytics_payload);

-- ============================================================
-- 2. Analytics Alert Dispatch Worker Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_dispatch_worker_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,
    worker_id TEXT NOT NULL,
    channel_code TEXT NOT NULL DEFAULT 'all',

    total_locks INTEGER NOT NULL DEFAULT 0,
    active_locks INTEGER NOT NULL DEFAULT 0,
    completed_locks INTEGER NOT NULL DEFAULT 0,
    failed_locks INTEGER NOT NULL DEFAULT 0,
    expired_locks INTEGER NOT NULL DEFAULT 0,
    released_locks INTEGER NOT NULL DEFAULT 0,

    sent_jobs INTEGER NOT NULL DEFAULT 0,
    failed_jobs INTEGER NOT NULL DEFAULT 0,
    skipped_jobs INTEGER NOT NULL DEFAULT 0,

    avg_lock_duration_minutes NUMERIC(12, 2) NOT NULL DEFAULT 0,

    first_lock_at TIMESTAMPTZ,
    last_lock_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oiaa_dispatch_worker_analytics
    UNIQUE (analytics_date, worker_id, channel_code)
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_dispatch_worker_analytics IS
'Stores worker-level analytics for analytics alert notification dispatch locks and processing.';

CREATE INDEX IF NOT EXISTS idx_oiaa_worker_date
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_worker_id
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics(worker_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_worker_channel
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics(channel_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_worker_payload
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics USING GIN(analytics_payload);

-- ============================================================
-- 3. Analytics Alert Dispatch KPI Snapshots
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_code TEXT NOT NULL UNIQUE,
    snapshot_scope TEXT NOT NULL DEFAULT 'analytics_alert_dispatch',

    total_jobs INTEGER NOT NULL DEFAULT 0,
    pending_jobs INTEGER NOT NULL DEFAULT 0,
    locked_jobs INTEGER NOT NULL DEFAULT 0,
    sent_jobs INTEGER NOT NULL DEFAULT 0,
    failed_jobs INTEGER NOT NULL DEFAULT 0,
    cancelled_jobs INTEGER NOT NULL DEFAULT 0,
    skipped_jobs INTEGER NOT NULL DEFAULT 0,

    ready_jobs INTEGER NOT NULL DEFAULT 0,
    stale_lock_jobs INTEGER NOT NULL DEFAULT 0,
    dead_letter_jobs INTEGER NOT NULL DEFAULT 0,

    total_attempts INTEGER NOT NULL DEFAULT 0,
    sent_attempts INTEGER NOT NULL DEFAULT 0,
    failed_attempts INTEGER NOT NULL DEFAULT 0,

    success_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,
    failure_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,

    active_analytics_alert_incidents INTEGER NOT NULL DEFAULT 0,
    active_critical_analytics_alert_incidents INTEGER NOT NULL DEFAULT 0,

    snapshot_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots IS
'Stores point-in-time KPI snapshots for analytics alert notification dispatch performance.';

CREATE INDEX IF NOT EXISTS idx_oiaa_kpi_scope
ON public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots(snapshot_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_kpi_created
ON public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_kpi_payload
ON public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots USING GIN(snapshot_payload);

-- ============================================================
-- 4. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_dispatch_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_daily_analytics_updated_at
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics;

CREATE TRIGGER trg_oiaa_daily_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_dispatch_analytics_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_worker_analytics_updated_at
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics;

CREATE TRIGGER trg_oiaa_worker_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_dispatch_analytics_updated_at();

-- ============================================================
-- 5. Refresh Daily Analytics Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_dispatch_daily_analytics(
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

    WITH attempt_summary AS (
        SELECT
            job_id,
            COUNT(*)::INTEGER AS total_attempts,
            COUNT(*) FILTER (WHERE attempt_status = 'sent')::INTEGER AS sent_attempts,
            COUNT(*) FILTER (WHERE attempt_status = 'failed')::INTEGER AS failed_attempts,
            COUNT(*) FILTER (WHERE attempt_status = 'cancelled')::INTEGER AS cancelled_attempts,
            COUNT(*) FILTER (WHERE attempt_status = 'skipped')::INTEGER AS skipped_attempts
        FROM public.order_lifecycle_analytics_alert_notification_delivery_attempts
        GROUP BY job_id
    ),
    lock_summary AS (
        SELECT
            job_id,
            COUNT(*) FILTER (
                WHERE lock_status = 'active'
                AND locked_until < NOW()
            )::INTEGER AS stale_lock_count
        FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks
        GROUP BY job_id
    ),
    dead_letter_summary AS (
        SELECT
            job_id,
            COUNT(*)::INTEGER AS dead_letter_count
        FROM public.order_lifecycle_analytics_alert_notification_dead_letter_queue
        GROUP BY job_id
    )
    INSERT INTO public.order_lifecycle_analytics_alert_dispatch_daily_analytics (
        analytics_date,
        channel_code,
        channel_type,
        total_jobs,
        pending_jobs,
        locked_jobs,
        sent_jobs,
        failed_jobs,
        cancelled_jobs,
        skipped_jobs,
        ready_jobs,
        stale_lock_jobs,
        dead_letter_jobs,
        total_attempts,
        sent_attempts,
        failed_attempts,
        cancelled_attempts,
        skipped_attempts,
        avg_attempt_count,
        success_rate_percent,
        failure_rate_percent,
        first_job_at,
        last_job_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        j.created_at::DATE AS analytics_date,
        j.channel_code,
        COALESCE(c.channel_type, 'unknown') AS channel_type,

        COUNT(j.id)::INTEGER AS total_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'pending')::INTEGER AS pending_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'locked')::INTEGER AS locked_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::INTEGER AS sent_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::INTEGER AS failed_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'cancelled')::INTEGER AS cancelled_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'skipped')::INTEGER AS skipped_jobs,

        COUNT(j.id) FILTER (
            WHERE j.job_status = 'pending'
            AND j.scheduled_at <= NOW()
        )::INTEGER AS ready_jobs,

        COALESCE(SUM(l.stale_lock_count), 0)::INTEGER AS stale_lock_jobs,
        COALESCE(SUM(d.dead_letter_count), 0)::INTEGER AS dead_letter_jobs,

        COALESCE(SUM(a.total_attempts), 0)::INTEGER AS total_attempts,
        COALESCE(SUM(a.sent_attempts), 0)::INTEGER AS sent_attempts,
        COALESCE(SUM(a.failed_attempts), 0)::INTEGER AS failed_attempts,
        COALESCE(SUM(a.cancelled_attempts), 0)::INTEGER AS cancelled_attempts,
        COALESCE(SUM(a.skipped_attempts), 0)::INTEGER AS skipped_attempts,

        COALESCE(ROUND(AVG(j.attempt_count)::NUMERIC, 2), 0) AS avg_attempt_count,

        CASE
            WHEN COUNT(j.id) > 0 THEN
                ROUND(
                    (
                        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::NUMERIC
                        / COUNT(j.id)::NUMERIC
                    ) * 100,
                    2
                )
            ELSE 0
        END AS success_rate_percent,

        CASE
            WHEN COUNT(j.id) > 0 THEN
                ROUND(
                    (
                        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::NUMERIC
                        / COUNT(j.id)::NUMERIC
                    ) * 100,
                    2
                )
            ELSE 0
        END AS failure_rate_percent,

        MIN(j.created_at) AS first_job_at,
        MAX(j.created_at) AS last_job_at,

        jsonb_build_object(
            'analytics_date', j.created_at::DATE,
            'channel_code', j.channel_code,
            'channel_type', COALESCE(c.channel_type, 'unknown'),
            'generated_by', 'migration_116'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_analytics_alert_notification_jobs j
    LEFT JOIN public.order_lifecycle_notification_channels c
    ON c.channel_code = j.channel_code
    LEFT JOIN attempt_summary a
    ON a.job_id = j.id
    LEFT JOIN lock_summary l
    ON l.job_id = j.id
    LEFT JOIN dead_letter_summary d
    ON d.job_id = j.id
    WHERE j.created_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY
        j.created_at::DATE,
        j.channel_code,
        c.channel_type
    ON CONFLICT (analytics_date, channel_code) DO UPDATE
    SET
        channel_type = EXCLUDED.channel_type,
        total_jobs = EXCLUDED.total_jobs,
        pending_jobs = EXCLUDED.pending_jobs,
        locked_jobs = EXCLUDED.locked_jobs,
        sent_jobs = EXCLUDED.sent_jobs,
        failed_jobs = EXCLUDED.failed_jobs,
        cancelled_jobs = EXCLUDED.cancelled_jobs,
        skipped_jobs = EXCLUDED.skipped_jobs,
        ready_jobs = EXCLUDED.ready_jobs,
        stale_lock_jobs = EXCLUDED.stale_lock_jobs,
        dead_letter_jobs = EXCLUDED.dead_letter_jobs,
        total_attempts = EXCLUDED.total_attempts,
        sent_attempts = EXCLUDED.sent_attempts,
        failed_attempts = EXCLUDED.failed_attempts,
        cancelled_attempts = EXCLUDED.cancelled_attempts,
        skipped_attempts = EXCLUDED.skipped_attempts,
        avg_attempt_count = EXCLUDED.avg_attempt_count,
        success_rate_percent = EXCLUDED.success_rate_percent,
        failure_rate_percent = EXCLUDED.failure_rate_percent,
        first_job_at = EXCLUDED.first_job_at,
        last_job_at = EXCLUDED.last_job_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_analytics_alert_dispatch_daily_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_116'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6. Refresh Worker Analytics Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_oiaa_dispatch_worker_analytics(
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

    INSERT INTO public.order_lifecycle_analytics_alert_dispatch_worker_analytics (
        analytics_date,
        worker_id,
        channel_code,
        total_locks,
        active_locks,
        completed_locks,
        failed_locks,
        expired_locks,
        released_locks,
        sent_jobs,
        failed_jobs,
        skipped_jobs,
        avg_lock_duration_minutes,
        first_lock_at,
        last_lock_at,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        l.locked_at::DATE AS analytics_date,
        l.worker_id,
        COALESCE(j.channel_code, 'unknown') AS channel_code,

        COUNT(l.id)::INTEGER AS total_locks,
        COUNT(l.id) FILTER (WHERE l.lock_status = 'active')::INTEGER AS active_locks,
        COUNT(l.id) FILTER (WHERE l.lock_status = 'completed')::INTEGER AS completed_locks,
        COUNT(l.id) FILTER (WHERE l.lock_status = 'failed')::INTEGER AS failed_locks,
        COUNT(l.id) FILTER (WHERE l.lock_status = 'expired')::INTEGER AS expired_locks,
        COUNT(l.id) FILTER (WHERE l.lock_status = 'released')::INTEGER AS released_locks,

        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::INTEGER AS sent_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::INTEGER AS failed_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'skipped')::INTEGER AS skipped_jobs,

        COALESCE(
            ROUND(
                AVG(
                    EXTRACT(
                        EPOCH FROM (
                            COALESCE(l.completed_at, l.failed_at, l.released_at, NOW())
                            - l.locked_at
                        )
                    ) / 60
                )::NUMERIC,
                2
            ),
            0
        ) AS avg_lock_duration_minutes,

        MIN(l.locked_at) AS first_lock_at,
        MAX(l.locked_at) AS last_lock_at,

        jsonb_build_object(
            'analytics_date', l.locked_at::DATE,
            'worker_id', l.worker_id,
            'channel_code', COALESCE(j.channel_code, 'unknown'),
            'generated_by', 'migration_116'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks l
    LEFT JOIN public.order_lifecycle_analytics_alert_notification_jobs j
    ON j.id = l.job_id
    WHERE l.locked_at::DATE BETWEEN p_from_date AND p_to_date
    GROUP BY
        l.locked_at::DATE,
        l.worker_id,
        COALESCE(j.channel_code, 'unknown')
    ON CONFLICT (analytics_date, worker_id, channel_code) DO UPDATE
    SET
        total_locks = EXCLUDED.total_locks,
        active_locks = EXCLUDED.active_locks,
        completed_locks = EXCLUDED.completed_locks,
        failed_locks = EXCLUDED.failed_locks,
        expired_locks = EXCLUDED.expired_locks,
        released_locks = EXCLUDED.released_locks,
        sent_jobs = EXCLUDED.sent_jobs,
        failed_jobs = EXCLUDED.failed_jobs,
        skipped_jobs = EXCLUDED.skipped_jobs,
        avg_lock_duration_minutes = EXCLUDED.avg_lock_duration_minutes,
        first_lock_at = EXCLUDED.first_lock_at,
        last_lock_at = EXCLUDED.last_lock_at,
        analytics_payload = EXCLUDED.analytics_payload,
        generated_at = NOW(),
        updated_at = NOW();

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_analytics_alert_dispatch_worker_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_116'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Create KPI Snapshot Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_oiaa_dispatch_kpi_snapshot(
    p_snapshot_scope TEXT DEFAULT 'analytics_alert_dispatch'
)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_snapshot_code TEXT;
BEGIN
    v_snapshot_code := 'oiaa_dispatch_kpi_'
        || to_char(NOW(), 'YYYYMMDDHH24MISSMS')
        || '_'
        || replace(gen_random_uuid()::TEXT, '-', '');

    INSERT INTO public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots (
        snapshot_code,
        snapshot_scope,
        total_jobs,
        pending_jobs,
        locked_jobs,
        sent_jobs,
        failed_jobs,
        cancelled_jobs,
        skipped_jobs,
        ready_jobs,
        stale_lock_jobs,
        dead_letter_jobs,
        total_attempts,
        sent_attempts,
        failed_attempts,
        success_rate_percent,
        failure_rate_percent,
        active_analytics_alert_incidents,
        active_critical_analytics_alert_incidents,
        snapshot_payload,
        created_at
    )
    SELECT
        v_snapshot_code,
        COALESCE(p_snapshot_scope, 'analytics_alert_dispatch'),

        COUNT(j.id)::INTEGER AS total_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'pending')::INTEGER AS pending_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'locked')::INTEGER AS locked_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::INTEGER AS sent_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::INTEGER AS failed_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'cancelled')::INTEGER AS cancelled_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'skipped')::INTEGER AS skipped_jobs,

        COUNT(j.id) FILTER (
            WHERE j.job_status = 'pending'
            AND j.scheduled_at <= NOW()
        )::INTEGER AS ready_jobs,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks
            WHERE lock_status = 'active'
            AND locked_until < NOW()
        ) AS stale_lock_jobs,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_notification_dead_letter_queue
            WHERE reviewed_at IS NULL
        ) AS dead_letter_jobs,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_notification_delivery_attempts
        ) AS total_attempts,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_notification_delivery_attempts
            WHERE attempt_status = 'sent'
        ) AS sent_attempts,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_notification_delivery_attempts
            WHERE attempt_status = 'failed'
        ) AS failed_attempts,

        CASE
            WHEN COUNT(j.id) > 0 THEN
                ROUND(
                    (
                        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::NUMERIC
                        / COUNT(j.id)::NUMERIC
                    ) * 100,
                    2
                )
            ELSE 0
        END AS success_rate_percent,

        CASE
            WHEN COUNT(j.id) > 0 THEN
                ROUND(
                    (
                        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::NUMERIC
                        / COUNT(j.id)::NUMERIC
                    ) * 100,
                    2
                )
            ELSE 0
        END AS failure_rate_percent,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_incidents
            WHERE incident_status IN ('open', 'acknowledged')
        ) AS active_analytics_alert_incidents,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_analytics_alert_incidents
            WHERE incident_status IN ('open', 'acknowledged')
            AND severity = 'critical'
        ) AS active_critical_analytics_alert_incidents,

        jsonb_build_object(
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_dispatch'),
            'generated_by', 'migration_116',
            'generated_at', NOW()
        ) AS snapshot_payload,

        NOW()
    FROM public.order_lifecycle_analytics_alert_notification_jobs j
    RETURNING id INTO v_snapshot_id;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'create_analytics_alert_dispatch_kpi_snapshot',
        'completed',
        jsonb_build_object(
            'snapshot_id', v_snapshot_id,
            'snapshot_code', v_snapshot_code,
            'snapshot_scope', COALESCE(p_snapshot_scope, 'analytics_alert_dispatch'),
            'generated_by', 'migration_116'
        ),
        NOW()
    );

    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Refresh All Analytics Alert Dispatch Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_oiaa_dispatch_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_daily_count INTEGER := 0;
    v_worker_count INTEGER := 0;
    v_snapshot_id UUID;
    v_result JSONB;
BEGIN
    v_daily_count := public.refresh_oiaa_dispatch_daily_analytics(
        p_from_date,
        p_to_date
    );

    v_worker_count := public.refresh_oiaa_dispatch_worker_analytics(
        p_from_date,
        p_to_date
    );

    v_snapshot_id := public.create_oiaa_dispatch_kpi_snapshot(
        'analytics_alert_dispatch'
    );

    v_result := jsonb_build_object(
        'daily_analytics_rows', v_daily_count,
        'worker_analytics_rows', v_worker_count,
        'snapshot_id', v_snapshot_id,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'generated_by', 'migration_116'
    );

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_all_analytics_alert_dispatch_analytics',
        'completed',
        v_result,
        NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.oiaa_dispatch_daily_dashboard_view AS
SELECT
    a.id,
    a.analytics_date,
    a.channel_code,
    c.channel_name,
    a.channel_type,

    a.total_jobs,
    a.pending_jobs,
    a.locked_jobs,
    a.sent_jobs,
    a.failed_jobs,
    a.cancelled_jobs,
    a.skipped_jobs,

    a.ready_jobs,
    a.stale_lock_jobs,
    a.dead_letter_jobs,

    a.total_attempts,
    a.sent_attempts,
    a.failed_attempts,
    a.cancelled_attempts,
    a.skipped_attempts,

    a.avg_attempt_count,
    a.success_rate_percent,
    a.failure_rate_percent,

    CASE
        WHEN a.dead_letter_jobs > 0 THEN 'dead_letter_attention'
        WHEN a.stale_lock_jobs > 0 THEN 'stale_lock_attention'
        WHEN a.failed_jobs > 0 THEN 'delivery_issues'
        WHEN a.ready_jobs > 0 THEN 'ready'
        WHEN a.locked_jobs > 0 THEN 'in_progress'
        WHEN a.sent_jobs > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS analytics_dashboard_status,

    a.first_job_at,
    a.last_job_at,
    a.analytics_payload,
    a.generated_at,
    a.updated_at
FROM public.order_lifecycle_analytics_alert_dispatch_daily_analytics a
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = a.channel_code;

COMMENT ON VIEW public.oiaa_dispatch_daily_dashboard_view IS
'Admin dashboard view for analytics alert notification dispatch daily analytics.';

CREATE OR REPLACE VIEW public.oiaa_dispatch_worker_dashboard_view AS
SELECT
    id,
    analytics_date,
    worker_id,
    channel_code,

    total_locks,
    active_locks,
    completed_locks,
    failed_locks,
    expired_locks,
    released_locks,

    sent_jobs,
    failed_jobs,
    skipped_jobs,

    avg_lock_duration_minutes,

    CASE
        WHEN expired_locks > 0 THEN 'lock_expiry_attention'
        WHEN failed_locks > 0 THEN 'worker_failure_attention'
        WHEN active_locks > 0 THEN 'active'
        WHEN completed_locks > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS worker_dashboard_status,

    first_lock_at,
    last_lock_at,
    analytics_payload,
    generated_at,
    updated_at
FROM public.order_lifecycle_analytics_alert_dispatch_worker_analytics;

COMMENT ON VIEW public.oiaa_dispatch_worker_dashboard_view IS
'Admin dashboard view for analytics alert notification dispatch worker analytics.';

CREATE OR REPLACE VIEW public.oiaa_dispatch_latest_kpi_view AS
SELECT
    *
FROM public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots
WHERE created_at = (
    SELECT MAX(created_at)
    FROM public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots
);

COMMENT ON VIEW public.oiaa_dispatch_latest_kpi_view IS
'Shows the latest analytics alert notification dispatch KPI snapshot.';

CREATE OR REPLACE VIEW public.oiaa_dispatch_analytics_health_view AS
SELECT
    'daily_dispatch_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_dispatch_daily_analytics

UNION ALL

SELECT
    'worker_dispatch_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_dispatch_worker_analytics

UNION ALL

SELECT
    'dispatch_kpi_snapshots' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(created_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(created_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots;

COMMENT ON VIEW public.oiaa_dispatch_analytics_health_view IS
'Shows freshness and health status for analytics alert notification dispatch analytics datasets.';

-- ============================================================
-- 10. Initial Backfill
-- ============================================================

SELECT public.refresh_all_oiaa_dispatch_analytics(
    CURRENT_DATE - 30,
    CURRENT_DATE
);

-- ============================================================
-- 11. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_dispatch_daily_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_dispatch_worker_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_daily_analytics"
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics;

CREATE POLICY "svc_manage_oiaa_daily_analytics"
ON public.order_lifecycle_analytics_alert_dispatch_daily_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_worker_analytics"
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics;

CREATE POLICY "svc_manage_oiaa_worker_analytics"
ON public.order_lifecycle_analytics_alert_dispatch_worker_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_kpi_snapshots"
ON public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots;

CREATE POLICY "svc_manage_oiaa_kpi_snapshots"
ON public.order_lifecycle_analytics_alert_dispatch_kpi_snapshots
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 12. Migration Registry Marker
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
    116,
    'migration_116_order_lifecycle_analytics_alert_dispatch_analytics',
    'Adds analytics tables, KPI snapshots, refresh functions, and dashboard views for analytics alert notification dispatch performance.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
