-- Migration 111: Order Lifecycle Notification Dispatch Analytics
-- Purpose:
-- Adds analytics tables, KPI snapshots, refresh functions, dashboard views,
-- and reporting support for order lifecycle notification dispatch performance.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Daily Dispatch Channel Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_daily_analytics (
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

    total_attempts INTEGER NOT NULL DEFAULT 0,
    sent_attempts INTEGER NOT NULL DEFAULT 0,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    cancelled_attempts INTEGER NOT NULL DEFAULT 0,
    skipped_attempts INTEGER NOT NULL DEFAULT 0,

    dead_letter_jobs INTEGER NOT NULL DEFAULT 0,

    avg_attempt_count NUMERIC(12, 2) NOT NULL DEFAULT 0,
    success_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,
    failure_rate_percent NUMERIC(12, 2) NOT NULL DEFAULT 0,

    first_job_at TIMESTAMPTZ,
    last_job_at TIMESTAMPTZ,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_order_lifecycle_dispatch_daily_analytics
    UNIQUE (analytics_date, channel_code),

    CONSTRAINT chk_order_lifecycle_dispatch_daily_analytics_counts
    CHECK (
        total_jobs >= 0
        AND pending_jobs >= 0
        AND locked_jobs >= 0
        AND sent_jobs >= 0
        AND failed_jobs >= 0
        AND cancelled_jobs >= 0
        AND skipped_jobs >= 0
        AND ready_jobs >= 0
        AND stale_lock_jobs >= 0
        AND total_attempts >= 0
        AND sent_attempts >= 0
        AND failed_attempts >= 0
        AND cancelled_attempts >= 0
        AND skipped_attempts >= 0
        AND dead_letter_jobs >= 0
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_daily_analytics IS
'Stores daily analytics for order lifecycle notification dispatch jobs by channel.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_daily_date
ON public.order_lifecycle_notification_dispatch_daily_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_daily_channel
ON public.order_lifecycle_notification_dispatch_daily_analytics(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_daily_payload
ON public.order_lifecycle_notification_dispatch_daily_analytics USING GIN(analytics_payload);

-- ============================================================
-- 2. Worker Dispatch Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_worker_analytics (
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

    CONSTRAINT uq_order_lifecycle_dispatch_worker_analytics
    UNIQUE (analytics_date, worker_id, channel_code)
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_worker_analytics IS
'Stores worker-level analytics for notification dispatch locking and processing.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_worker_date
ON public.order_lifecycle_notification_dispatch_worker_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_worker_id
ON public.order_lifecycle_notification_dispatch_worker_analytics(worker_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_worker_channel
ON public.order_lifecycle_notification_dispatch_worker_analytics(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_worker_payload
ON public.order_lifecycle_notification_dispatch_worker_analytics USING GIN(analytics_payload);

-- ============================================================
-- 3. Exception Notification Analytics
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_exception_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    analytics_date DATE NOT NULL,
    severity TEXT NOT NULL,
    exception_type TEXT NOT NULL,

    total_exceptions INTEGER NOT NULL DEFAULT 0,
    open_exceptions INTEGER NOT NULL DEFAULT 0,
    in_review_exceptions INTEGER NOT NULL DEFAULT 0,
    escalated_exceptions INTEGER NOT NULL DEFAULT 0,
    resolved_exceptions INTEGER NOT NULL DEFAULT 0,
    ignored_exceptions INTEGER NOT NULL DEFAULT 0,

    total_notification_jobs INTEGER NOT NULL DEFAULT 0,
    pending_notification_jobs INTEGER NOT NULL DEFAULT 0,
    sent_notification_jobs INTEGER NOT NULL DEFAULT 0,
    failed_notification_jobs INTEGER NOT NULL DEFAULT 0,

    dead_letter_jobs INTEGER NOT NULL DEFAULT 0,

    analytics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_order_lifecycle_notification_exception_analytics
    UNIQUE (analytics_date, severity, exception_type),

    CONSTRAINT chk_order_lifecycle_notification_exception_analytics_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE public.order_lifecycle_notification_exception_analytics IS
'Stores daily analytics for exception notification workload by severity and exception type.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_exception_date
ON public.order_lifecycle_notification_exception_analytics(analytics_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_exception_severity
ON public.order_lifecycle_notification_exception_analytics(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_exception_type
ON public.order_lifecycle_notification_exception_analytics(exception_type);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_exception_payload
ON public.order_lifecycle_notification_exception_analytics USING GIN(analytics_payload);

-- ============================================================
-- 4. Dispatch KPI Snapshots
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_kpi_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_code TEXT NOT NULL UNIQUE,
    snapshot_scope TEXT NOT NULL DEFAULT 'global',

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

    open_critical_exceptions INTEGER NOT NULL DEFAULT 0,
    breached_sla_count INTEGER NOT NULL DEFAULT 0,

    snapshot_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_kpi_snapshots IS
'Stores point-in-time KPI snapshots for order lifecycle notification dispatch performance.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_kpi_scope
ON public.order_lifecycle_notification_dispatch_kpi_snapshots(snapshot_scope);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_kpi_created_at
ON public.order_lifecycle_notification_dispatch_kpi_snapshots(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_kpi_payload
ON public.order_lifecycle_notification_dispatch_kpi_snapshots USING GIN(snapshot_payload);

-- ============================================================
-- 5. Analytics Event Log
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'recorded',

    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_analytics_events IS
'Stores analytics refresh, KPI snapshot, and reporting event history.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_analytics_events_type
ON public.order_lifecycle_notification_dispatch_analytics_events(event_type);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_analytics_events_status
ON public.order_lifecycle_notification_dispatch_analytics_events(event_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_analytics_events_created_at
ON public.order_lifecycle_notification_dispatch_analytics_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_analytics_events_payload
ON public.order_lifecycle_notification_dispatch_analytics_events USING GIN(event_payload);

-- ============================================================
-- 6. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_notification_dispatch_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_dispatch_daily_analytics_updated_at
ON public.order_lifecycle_notification_dispatch_daily_analytics;

CREATE TRIGGER trg_order_lifecycle_dispatch_daily_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dispatch_daily_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_analytics_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_dispatch_worker_analytics_updated_at
ON public.order_lifecycle_notification_dispatch_worker_analytics;

CREATE TRIGGER trg_order_lifecycle_dispatch_worker_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dispatch_worker_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_analytics_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_notification_exception_analytics_updated_at
ON public.order_lifecycle_notification_exception_analytics;

CREATE TRIGGER trg_order_lifecycle_notification_exception_analytics_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_exception_analytics
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_analytics_updated_at();

-- ============================================================
-- 7. Refresh Daily Dispatch Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_order_lifecycle_notification_dispatch_daily_analytics(
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
        FROM public.order_lifecycle_sla_notification_delivery_attempts
        GROUP BY job_id
    ),
    dead_letter_summary AS (
        SELECT
            job_id,
            COUNT(*)::INTEGER AS dead_letter_count
        FROM public.order_lifecycle_notification_dead_letter_queue
        GROUP BY job_id
    )
    INSERT INTO public.order_lifecycle_notification_dispatch_daily_analytics (
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
        total_attempts,
        sent_attempts,
        failed_attempts,
        cancelled_attempts,
        skipped_attempts,
        dead_letter_jobs,
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

        COUNT(j.id) FILTER (
            WHERE j.job_status = 'locked'
            AND j.locked_at IS NOT NULL
            AND j.locked_at < NOW() - INTERVAL '30 minutes'
        )::INTEGER AS stale_lock_jobs,

        COALESCE(SUM(a.total_attempts), 0)::INTEGER AS total_attempts,
        COALESCE(SUM(a.sent_attempts), 0)::INTEGER AS sent_attempts,
        COALESCE(SUM(a.failed_attempts), 0)::INTEGER AS failed_attempts,
        COALESCE(SUM(a.cancelled_attempts), 0)::INTEGER AS cancelled_attempts,
        COALESCE(SUM(a.skipped_attempts), 0)::INTEGER AS skipped_attempts,

        COALESCE(SUM(d.dead_letter_count), 0)::INTEGER AS dead_letter_jobs,

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
            'generated_by', 'migration_111'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_sla_notification_jobs j
    LEFT JOIN public.order_lifecycle_notification_channels c
    ON c.channel_code = j.channel_code
    LEFT JOIN attempt_summary a
    ON a.job_id = j.id
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
        total_attempts = EXCLUDED.total_attempts,
        sent_attempts = EXCLUDED.sent_attempts,
        failed_attempts = EXCLUDED.failed_attempts,
        cancelled_attempts = EXCLUDED.cancelled_attempts,
        skipped_attempts = EXCLUDED.skipped_attempts,
        dead_letter_jobs = EXCLUDED.dead_letter_jobs,
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
        'refresh_daily_dispatch_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_111'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Refresh Worker Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_order_lifecycle_notification_dispatch_worker_analytics(
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

    INSERT INTO public.order_lifecycle_notification_dispatch_worker_analytics (
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
            'generated_by', 'migration_111'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_notification_dispatch_locks l
    LEFT JOIN public.order_lifecycle_sla_notification_jobs j
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
        'refresh_worker_dispatch_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_111'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Refresh Exception Notification Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_order_lifecycle_notification_exception_analytics(
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

    WITH dead_letter_summary AS (
        SELECT
            job_id,
            COUNT(*)::INTEGER AS dead_letter_count
        FROM public.order_lifecycle_notification_dead_letter_queue
        GROUP BY job_id
    )
    INSERT INTO public.order_lifecycle_notification_exception_analytics (
        analytics_date,
        severity,
        exception_type,
        total_exceptions,
        open_exceptions,
        in_review_exceptions,
        escalated_exceptions,
        resolved_exceptions,
        ignored_exceptions,
        total_notification_jobs,
        pending_notification_jobs,
        sent_notification_jobs,
        failed_notification_jobs,
        dead_letter_jobs,
        analytics_payload,
        generated_at,
        updated_at
    )
    SELECT
        COALESCE(j.created_at::DATE, q.created_at::DATE) AS analytics_date,
        q.severity,
        q.exception_type,

        COUNT(DISTINCT q.id)::INTEGER AS total_exceptions,
        COUNT(DISTINCT q.id) FILTER (WHERE q.queue_status = 'open')::INTEGER AS open_exceptions,
        COUNT(DISTINCT q.id) FILTER (WHERE q.queue_status = 'in_review')::INTEGER AS in_review_exceptions,
        COUNT(DISTINCT q.id) FILTER (WHERE q.queue_status = 'escalated')::INTEGER AS escalated_exceptions,
        COUNT(DISTINCT q.id) FILTER (WHERE q.queue_status = 'resolved')::INTEGER AS resolved_exceptions,
        COUNT(DISTINCT q.id) FILTER (WHERE q.queue_status = 'ignored')::INTEGER AS ignored_exceptions,

        COUNT(j.id)::INTEGER AS total_notification_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'pending')::INTEGER AS pending_notification_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'sent')::INTEGER AS sent_notification_jobs,
        COUNT(j.id) FILTER (WHERE j.job_status = 'failed')::INTEGER AS failed_notification_jobs,

        COALESCE(SUM(d.dead_letter_count), 0)::INTEGER AS dead_letter_jobs,

        jsonb_build_object(
            'analytics_date', COALESCE(j.created_at::DATE, q.created_at::DATE),
            'severity', q.severity,
            'exception_type', q.exception_type,
            'generated_by', 'migration_111'
        ) AS analytics_payload,

        NOW(),
        NOW()
    FROM public.order_lifecycle_exception_queue q
    LEFT JOIN public.order_lifecycle_sla_notification_jobs j
    ON j.exception_id = q.id
    LEFT JOIN dead_letter_summary d
    ON d.job_id = j.id
    WHERE COALESCE(j.created_at::DATE, q.created_at::DATE) BETWEEN p_from_date AND p_to_date
    GROUP BY
        COALESCE(j.created_at::DATE, q.created_at::DATE),
        q.severity,
        q.exception_type
    ON CONFLICT (analytics_date, severity, exception_type) DO UPDATE
    SET
        total_exceptions = EXCLUDED.total_exceptions,
        open_exceptions = EXCLUDED.open_exceptions,
        in_review_exceptions = EXCLUDED.in_review_exceptions,
        escalated_exceptions = EXCLUDED.escalated_exceptions,
        resolved_exceptions = EXCLUDED.resolved_exceptions,
        ignored_exceptions = EXCLUDED.ignored_exceptions,
        total_notification_jobs = EXCLUDED.total_notification_jobs,
        pending_notification_jobs = EXCLUDED.pending_notification_jobs,
        sent_notification_jobs = EXCLUDED.sent_notification_jobs,
        failed_notification_jobs = EXCLUDED.failed_notification_jobs,
        dead_letter_jobs = EXCLUDED.dead_letter_jobs,
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
        'refresh_exception_notification_analytics',
        'completed',
        jsonb_build_object(
            'from_date', p_from_date,
            'to_date', p_to_date,
            'affected_rows', v_row_count,
            'generated_by', 'migration_111'
        ),
        NOW()
    );

    RETURN v_row_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Create KPI Snapshot
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_lifecycle_notification_dispatch_kpi_snapshot(
    p_snapshot_scope TEXT DEFAULT 'global'
)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_snapshot_code TEXT;
BEGIN
    v_snapshot_code := 'dispatch_kpi_'
        || to_char(NOW(), 'YYYYMMDDHH24MISSMS')
        || '_'
        || replace(gen_random_uuid()::TEXT, '-', '');

    INSERT INTO public.order_lifecycle_notification_dispatch_kpi_snapshots (
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
        open_critical_exceptions,
        breached_sla_count,
        snapshot_payload,
        created_at
    )
    SELECT
        v_snapshot_code,
        COALESCE(p_snapshot_scope, 'global'),

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

        COUNT(j.id) FILTER (
            WHERE j.job_status = 'locked'
            AND j.locked_at IS NOT NULL
            AND j.locked_at < NOW() - INTERVAL '30 minutes'
        )::INTEGER AS stale_lock_jobs,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_notification_dead_letter_queue
            WHERE reviewed_at IS NULL
        ) AS dead_letter_jobs,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_sla_notification_delivery_attempts
        ) AS total_attempts,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_sla_notification_delivery_attempts
            WHERE attempt_status = 'sent'
        ) AS sent_attempts,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_sla_notification_delivery_attempts
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
            FROM public.order_lifecycle_exception_queue
            WHERE severity = 'critical'
            AND queue_status IN ('open', 'in_review', 'escalated')
        ) AS open_critical_exceptions,

        (
            SELECT COUNT(*)::INTEGER
            FROM public.order_lifecycle_exception_sla_tracking
            WHERE sla_status = 'breached'
            OR response_breached = TRUE
            OR resolution_breached = TRUE
            OR escalation_breached = TRUE
        ) AS breached_sla_count,

        jsonb_build_object(
            'snapshot_scope', COALESCE(p_snapshot_scope, 'global'),
            'generated_by', 'migration_111',
            'generated_at', NOW()
        ) AS snapshot_payload,

        NOW()
    FROM public.order_lifecycle_sla_notification_jobs j
    RETURNING id INTO v_snapshot_id;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'create_dispatch_kpi_snapshot',
        'completed',
        jsonb_build_object(
            'snapshot_id', v_snapshot_id,
            'snapshot_code', v_snapshot_code,
            'snapshot_scope', COALESCE(p_snapshot_scope, 'global'),
            'generated_by', 'migration_111'
        ),
        NOW()
    );

    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. Refresh All Notification Dispatch Analytics
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_order_lifecycle_notification_dispatch_analytics(
    p_from_date DATE DEFAULT (CURRENT_DATE - 30),
    p_to_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_daily_count INTEGER := 0;
    v_worker_count INTEGER := 0;
    v_exception_count INTEGER := 0;
    v_snapshot_id UUID;
    v_result JSONB;
BEGIN
    v_daily_count := public.refresh_order_lifecycle_notification_dispatch_daily_analytics(
        p_from_date,
        p_to_date
    );

    v_worker_count := public.refresh_order_lifecycle_notification_dispatch_worker_analytics(
        p_from_date,
        p_to_date
    );

    v_exception_count := public.refresh_order_lifecycle_notification_exception_analytics(
        p_from_date,
        p_to_date
    );

    v_snapshot_id := public.create_order_lifecycle_notification_dispatch_kpi_snapshot('global');

    v_result := jsonb_build_object(
        'daily_analytics_rows', v_daily_count,
        'worker_analytics_rows', v_worker_count,
        'exception_analytics_rows', v_exception_count,
        'snapshot_id', v_snapshot_id,
        'from_date', p_from_date,
        'to_date', p_to_date,
        'generated_by', 'migration_111'
    );

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'refresh_all_dispatch_analytics',
        'completed',
        v_result,
        NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 12. Daily Analytics Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_dispatch_analytics_dashboard_view AS
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

    a.total_attempts,
    a.sent_attempts,
    a.failed_attempts,
    a.cancelled_attempts,
    a.skipped_attempts,

    a.dead_letter_jobs,

    a.avg_attempt_count,
    a.success_rate_percent,
    a.failure_rate_percent,

    CASE
        WHEN a.dead_letter_jobs > 0 THEN 'attention_required'
        WHEN a.stale_lock_jobs > 0 THEN 'stale_locks'
        WHEN a.failed_jobs > 0 THEN 'delivery_issues'
        WHEN a.pending_jobs > 0 OR a.locked_jobs > 0 THEN 'in_progress'
        WHEN a.sent_jobs > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS analytics_dashboard_status,

    a.first_job_at,
    a.last_job_at,
    a.analytics_payload,
    a.generated_at,
    a.updated_at
FROM public.order_lifecycle_notification_dispatch_daily_analytics a
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = a.channel_code;

COMMENT ON VIEW public.order_lifecycle_notification_dispatch_analytics_dashboard_view IS
'Admin dashboard view for daily notification dispatch analytics by channel.';

-- ============================================================
-- 13. Worker Analytics Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_dispatch_worker_dashboard_view AS
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
        WHEN failed_locks > 0 THEN 'worker_delivery_issues'
        WHEN active_locks > 0 THEN 'active'
        WHEN completed_locks > 0 THEN 'healthy'
        ELSE 'no_activity'
    END AS worker_dashboard_status,

    first_lock_at,
    last_lock_at,
    analytics_payload,
    generated_at,
    updated_at
FROM public.order_lifecycle_notification_dispatch_worker_analytics;

COMMENT ON VIEW public.order_lifecycle_notification_dispatch_worker_dashboard_view IS
'Admin dashboard view for dispatch worker analytics and lock health.';

-- ============================================================
-- 14. Latest KPI Snapshot View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_dispatch_latest_kpi_view AS
SELECT
    *
FROM public.order_lifecycle_notification_dispatch_kpi_snapshots
WHERE created_at = (
    SELECT MAX(created_at)
    FROM public.order_lifecycle_notification_dispatch_kpi_snapshots
);

COMMENT ON VIEW public.order_lifecycle_notification_dispatch_latest_kpi_view IS
'Shows the latest notification dispatch KPI snapshot.';

-- ============================================================
-- 15. Analytics Health View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_dispatch_analytics_health_view AS
SELECT
    'daily_channel_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_notification_dispatch_daily_analytics

UNION ALL

SELECT
    'worker_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_notification_dispatch_worker_analytics

UNION ALL

SELECT
    'exception_notification_analytics' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(generated_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(generated_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_notification_exception_analytics

UNION ALL

SELECT
    'kpi_snapshots' AS analytics_area,
    COUNT(*)::INTEGER AS record_count,
    MAX(created_at) AS latest_generated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_started'
        WHEN MAX(created_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'fresh'
    END AS analytics_health_status
FROM public.order_lifecycle_notification_dispatch_kpi_snapshots;

COMMENT ON VIEW public.order_lifecycle_notification_dispatch_analytics_health_view IS
'Shows freshness and health status for notification dispatch analytics datasets.';

-- ============================================================
-- 16. Initial Backfill
-- ============================================================

SELECT public.refresh_all_order_lifecycle_notification_dispatch_analytics(
    CURRENT_DATE - 30,
    CURRENT_DATE
);

-- ============================================================
-- 17. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_notification_dispatch_daily_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dispatch_worker_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_exception_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dispatch_kpi_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dispatch_analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch daily analytics"
ON public.order_lifecycle_notification_dispatch_daily_analytics;

CREATE POLICY "Service role can manage order lifecycle dispatch daily analytics"
ON public.order_lifecycle_notification_dispatch_daily_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch worker analytics"
ON public.order_lifecycle_notification_dispatch_worker_analytics;

CREATE POLICY "Service role can manage order lifecycle dispatch worker analytics"
ON public.order_lifecycle_notification_dispatch_worker_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle notification exception analytics"
ON public.order_lifecycle_notification_exception_analytics;

CREATE POLICY "Service role can manage order lifecycle notification exception analytics"
ON public.order_lifecycle_notification_exception_analytics
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch KPI snapshots"
ON public.order_lifecycle_notification_dispatch_kpi_snapshots;

CREATE POLICY "Service role can manage order lifecycle dispatch KPI snapshots"
ON public.order_lifecycle_notification_dispatch_kpi_snapshots
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch analytics events"
ON public.order_lifecycle_notification_dispatch_analytics_events;

CREATE POLICY "Service role can manage order lifecycle dispatch analytics events"
ON public.order_lifecycle_notification_dispatch_analytics_events
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 18. Migration Registry Marker
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
    111,
    'migration_111_order_lifecycle_notification_dispatch_analytics',
    'Adds analytics tables, KPI snapshots, refresh functions, dashboard views, and reporting support for order lifecycle notification dispatch performance.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
