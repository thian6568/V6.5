-- Migration 115: Order Lifecycle Analytics Alert Notification Dispatch Control
-- Purpose:
-- Adds dispatch control, locking, retry handling, stale-lock recovery,
-- dead-letter tracking, and dashboard views for analytics alert notification jobs.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Alert Notification Dispatch Batches
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_dispatch_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    batch_code TEXT NOT NULL UNIQUE,
    worker_id TEXT NOT NULL DEFAULT 'analytics_alert_dispatcher',

    channel_code TEXT,
    batch_status TEXT NOT NULL DEFAULT 'created',

    requested_job_count INTEGER NOT NULL DEFAULT 0,
    locked_job_count INTEGER NOT NULL DEFAULT 0,
    sent_job_count INTEGER NOT NULL DEFAULT 0,
    failed_job_count INTEGER NOT NULL DEFAULT 0,
    skipped_job_count INTEGER NOT NULL DEFAULT 0,

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    batch_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_dispatch_batches_status
    CHECK (batch_status IN ('created', 'running', 'completed', 'failed', 'cancelled')),

    CONSTRAINT chk_order_lifecycle_analytics_alert_dispatch_batches_counts
    CHECK (
        requested_job_count >= 0
        AND locked_job_count >= 0
        AND sent_job_count >= 0
        AND failed_job_count >= 0
        AND skipped_job_count >= 0
    )
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_dispatch_batches IS
'Stores dispatch batch records for analytics alert notification job processing.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_batches_code
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches(batch_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_batches_worker
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches(worker_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_batches_status
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches(batch_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_batches_channel
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_batches_payload
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches USING GIN(batch_payload);

-- ============================================================
-- 2. Analytics Alert Notification Dispatch Locks
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_dispatch_locks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL UNIQUE REFERENCES public.order_lifecycle_analytics_alert_notification_jobs(id) ON DELETE CASCADE,

    batch_id UUID REFERENCES public.order_lifecycle_analytics_alert_notification_dispatch_batches(id) ON DELETE SET NULL,

    worker_id TEXT NOT NULL DEFAULT 'analytics_alert_dispatcher',

    lock_status TEXT NOT NULL DEFAULT 'active',

    locked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_until TIMESTAMPTZ NOT NULL,

    released_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    lock_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_dispatch_locks_status
    CHECK (lock_status IN ('active', 'released', 'completed', 'failed', 'expired', 'cancelled', 'skipped'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_dispatch_locks IS
'Tracks worker locks for analytics alert notification dispatch jobs to prevent duplicate delivery.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_job
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_batch
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks(batch_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_worker
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks(worker_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_status
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks(lock_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_until
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks(locked_until);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dispatch_locks_payload
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks USING GIN(lock_payload);

-- ============================================================
-- 3. Analytics Alert Notification Dead Letter Queue
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_dead_letter_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL UNIQUE REFERENCES public.order_lifecycle_analytics_alert_notification_jobs(id) ON DELETE CASCADE,
    incident_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_incidents(id) ON DELETE CASCADE,

    threshold_code TEXT NOT NULL,
    metric_scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,

    channel_code TEXT NOT NULL,

    failure_reason TEXT NOT NULL,
    failure_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    final_attempt_count INTEGER NOT NULL DEFAULT 0,

    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_dead_letter_attempt_count
    CHECK (final_attempt_count >= 0)
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_dead_letter_queue IS
'Stores analytics alert notification jobs that failed permanently after exhausting retry attempts.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dead_letter_job
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dead_letter_incident
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue(incident_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dead_letter_threshold
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue(threshold_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dead_letter_channel
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_dead_letter_payload
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue USING GIN(failure_payload);

-- ============================================================
-- 4. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_analytics_alert_notification_dispatch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_dispatch_batches_updated_at
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_dispatch_batches_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_notification_dispatch_batches
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_dispatch_locks_updated_at
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_dispatch_locks_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_notification_dispatch_locks
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_dead_letter_updated_at
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_dead_letter_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_notification_dispatch_updated_at();

-- ============================================================
-- 5. Create Analytics Alert Dispatch Batch Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_lifecycle_analytics_alert_notification_dispatch_batch(
    p_worker_id TEXT DEFAULT 'analytics_alert_dispatcher',
    p_channel_code TEXT DEFAULT NULL,
    p_requested_job_count INTEGER DEFAULT 10,
    p_batch_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_batch_code TEXT;
BEGIN
    v_batch_code := 'analytics_alert_dispatch_' || replace(gen_random_uuid()::TEXT, '-', '');

    INSERT INTO public.order_lifecycle_analytics_alert_notification_dispatch_batches (
        batch_code,
        worker_id,
        channel_code,
        batch_status,
        requested_job_count,
        batch_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_batch_code,
        COALESCE(p_worker_id, 'analytics_alert_dispatcher'),
        p_channel_code,
        'created',
        COALESCE(p_requested_job_count, 10),
        COALESCE(p_batch_payload, '{}'::jsonb),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_batch_id;

    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6. Acquire Next Analytics Alert Notification Dispatch Job
-- ============================================================

CREATE OR REPLACE FUNCTION public.acquire_next_order_lifecycle_analytics_alert_notification_dispatch_job(
    p_worker_id TEXT DEFAULT 'analytics_alert_dispatcher',
    p_batch_id UUID DEFAULT NULL,
    p_channel_code TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_job RECORD;
    v_setting RECORD;
    v_lock_id UUID;
    v_locked_until TIMESTAMPTZ;
BEGIN
    SELECT *
    INTO v_setting
    FROM public.order_lifecycle_notification_dispatch_settings
    WHERE setting_code = 'GLOBAL_NOTIFICATION_DISPATCH'
    AND is_enabled = TRUE
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT j.*
    INTO v_job
    FROM public.order_lifecycle_analytics_alert_notification_jobs j
    JOIN public.order_lifecycle_notification_channels c
    ON c.channel_code = j.channel_code
    LEFT JOIN public.order_lifecycle_channel_dispatch_controls dc
    ON dc.channel_code = j.channel_code
    WHERE j.job_status = 'pending'
    AND j.scheduled_at <= NOW()
    AND j.attempt_count < j.max_attempts
    AND c.is_enabled = TRUE
    AND COALESCE(dc.is_dispatch_enabled, TRUE) = TRUE
    AND COALESCE(dc.is_paused, FALSE) = FALSE
    AND (
        p_channel_code IS NULL
        OR j.channel_code = p_channel_code
    )
    ORDER BY
        j.priority ASC,
        j.scheduled_at ASC,
        j.created_at ASC
    LIMIT 1
    FOR UPDATE OF j SKIP LOCKED;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF public.can_dispatch_order_lifecycle_notification_channel(v_job.channel_code) = FALSE THEN
        RETURN NULL;
    END IF;

    v_locked_until := NOW() + make_interval(mins => COALESCE(v_setting.max_locked_minutes, 15));

    UPDATE public.order_lifecycle_analytics_alert_notification_jobs
    SET
        job_status = 'locked',
        locked_at = NOW(),
        updated_at = NOW()
    WHERE id = v_job.id;

    INSERT INTO public.order_lifecycle_analytics_alert_notification_dispatch_locks (
        job_id,
        batch_id,
        worker_id,
        lock_status,
        locked_at,
        locked_until,
        lock_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_job.id,
        p_batch_id,
        COALESCE(p_worker_id, 'analytics_alert_dispatcher'),
        'active',
        NOW(),
        v_locked_until,
        jsonb_build_object(
            'job_id', v_job.id,
            'incident_id', v_job.incident_id,
            'threshold_code', v_job.threshold_code,
            'channel_code', v_job.channel_code,
            'worker_id', COALESCE(p_worker_id, 'analytics_alert_dispatcher'),
            'generated_by', 'migration_115'
        ),
        NOW(),
        NOW()
    )
    ON CONFLICT (job_id) DO UPDATE
    SET
        batch_id = EXCLUDED.batch_id,
        worker_id = EXCLUDED.worker_id,
        lock_status = 'active',
        locked_at = NOW(),
        locked_until = EXCLUDED.locked_until,
        released_at = NULL,
        completed_at = NULL,
        failed_at = NULL,
        lock_payload = EXCLUDED.lock_payload,
        updated_at = NOW()
    RETURNING id INTO v_lock_id;

    UPDATE public.order_lifecycle_channel_dispatch_controls
    SET
        current_window_dispatch_count = current_window_dispatch_count + 1,
        updated_at = NOW()
    WHERE channel_code = v_job.channel_code;

    IF p_batch_id IS NOT NULL THEN
        UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_batches
        SET
            batch_status = 'running',
            locked_job_count = locked_job_count + 1,
            started_at = COALESCE(started_at, NOW()),
            updated_at = NOW()
        WHERE id = p_batch_id;
    END IF;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'analytics_alert_notification_dispatch_job_acquired',
        'locked',
        jsonb_build_object(
            'job_id', v_job.id,
            'batch_id', p_batch_id,
            'worker_id', COALESCE(p_worker_id, 'analytics_alert_dispatcher'),
            'channel_code', v_job.channel_code,
            'generated_by', 'migration_115'
        ),
        NOW()
    );

    RETURN v_job.id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Record Analytics Alert Dispatch Result Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_analytics_alert_notification_dispatch_result(
    p_job_id UUID,
    p_dispatch_status TEXT,
    p_response_payload JSONB DEFAULT '{}'::jsonb,
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_job RECORD;
    v_setting RECORD;
    v_attempt_id UUID;
    v_retry_delay_minutes INTEGER := 10;
BEGIN
    IF p_job_id IS NULL OR p_dispatch_status IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_dispatch_status NOT IN ('sent', 'failed', 'cancelled', 'skipped') THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_job
    FROM public.order_lifecycle_analytics_alert_notification_jobs
    WHERE id = p_job_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_setting
    FROM public.order_lifecycle_notification_dispatch_settings
    WHERE setting_code = 'GLOBAL_NOTIFICATION_DISPATCH'
    LIMIT 1;

    v_retry_delay_minutes := COALESCE(v_setting.retry_delay_minutes, 10);

    v_attempt_id := public.record_order_lifecycle_analytics_alert_notification_delivery_attempt(
        p_job_id,
        p_dispatch_status,
        COALESCE(p_response_payload, '{}'::jsonb),
        p_error_message
    );

    IF p_dispatch_status = 'sent' THEN
        UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_locks
        SET
            lock_status = 'completed',
            completed_at = NOW(),
            updated_at = NOW()
        WHERE job_id = p_job_id;

        UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_batches b
        SET
            sent_job_count = sent_job_count + 1,
            updated_at = NOW()
        FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks l
        WHERE l.batch_id = b.id
        AND l.job_id = p_job_id;

        RETURN v_attempt_id;
    END IF;

    IF p_dispatch_status = 'failed' THEN
        SELECT *
        INTO v_job
        FROM public.order_lifecycle_analytics_alert_notification_jobs
        WHERE id = p_job_id
        LIMIT 1;

        IF v_job.attempt_count >= v_job.max_attempts THEN
            INSERT INTO public.order_lifecycle_analytics_alert_notification_dead_letter_queue (
                job_id,
                incident_id,
                threshold_code,
                metric_scope,
                metric_name,
                channel_code,
                failure_reason,
                failure_payload,
                final_attempt_count,
                created_at,
                updated_at
            )
            VALUES (
                v_job.id,
                v_job.incident_id,
                v_job.threshold_code,
                v_job.metric_scope,
                v_job.metric_name,
                v_job.channel_code,
                COALESCE(p_error_message, 'Maximum analytics alert notification dispatch attempts reached.'),
                jsonb_build_object(
                    'job_id', v_job.id,
                    'incident_id', v_job.incident_id,
                    'threshold_code', v_job.threshold_code,
                    'channel_code', v_job.channel_code,
                    'attempt_count', v_job.attempt_count,
                    'max_attempts', v_job.max_attempts,
                    'response_payload', COALESCE(p_response_payload, '{}'::jsonb),
                    'generated_by', 'migration_115'
                ),
                v_job.attempt_count,
                NOW(),
                NOW()
            )
            ON CONFLICT (job_id) DO UPDATE
            SET
                failure_reason = EXCLUDED.failure_reason,
                failure_payload = EXCLUDED.failure_payload,
                final_attempt_count = EXCLUDED.final_attempt_count,
                updated_at = NOW();

            UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_locks
            SET
                lock_status = 'failed',
                failed_at = NOW(),
                updated_at = NOW()
            WHERE job_id = p_job_id;

            UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_batches b
            SET
                failed_job_count = failed_job_count + 1,
                updated_at = NOW()
            FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks l
            WHERE l.batch_id = b.id
            AND l.job_id = p_job_id;
        ELSE
            UPDATE public.order_lifecycle_analytics_alert_notification_jobs
            SET
                job_status = 'pending',
                locked_at = NULL,
                scheduled_at = NOW() + make_interval(mins => v_retry_delay_minutes),
                last_error = COALESCE(p_error_message, last_error),
                updated_at = NOW()
            WHERE id = p_job_id;

            UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_locks
            SET
                lock_status = 'released',
                released_at = NOW(),
                updated_at = NOW()
            WHERE job_id = p_job_id;
        END IF;

        RETURN v_attempt_id;
    END IF;

    IF p_dispatch_status IN ('cancelled', 'skipped') THEN
        UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_locks
        SET
            lock_status = p_dispatch_status,
            released_at = NOW(),
            updated_at = NOW()
        WHERE job_id = p_job_id;

        UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_batches b
        SET
            skipped_job_count = skipped_job_count + 1,
            updated_at = NOW()
        FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks l
        WHERE l.batch_id = b.id
        AND l.job_id = p_job_id;
    END IF;

    RETURN v_attempt_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Release Stale Analytics Alert Dispatch Locks
-- ============================================================

CREATE OR REPLACE FUNCTION public.release_stale_order_lifecycle_analytics_alert_notification_dispatch_locks()
RETURNS INTEGER AS $$
DECLARE
    v_released_count INTEGER := 0;
BEGIN
    UPDATE public.order_lifecycle_analytics_alert_notification_jobs j
    SET
        job_status = CASE
            WHEN j.attempt_count >= j.max_attempts THEN 'failed'
            ELSE 'pending'
        END,
        locked_at = NULL,
        scheduled_at = CASE
            WHEN j.attempt_count >= j.max_attempts THEN j.scheduled_at
            ELSE NOW()
        END,
        last_error = COALESCE(j.last_error, 'Analytics alert notification dispatch lock expired before completion.'),
        updated_at = NOW()
    FROM public.order_lifecycle_analytics_alert_notification_dispatch_locks l
    WHERE l.job_id = j.id
    AND l.lock_status = 'active'
    AND l.locked_until < NOW();

    UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_locks
    SET
        lock_status = 'expired',
        released_at = NOW(),
        updated_at = NOW()
    WHERE lock_status = 'active'
    AND locked_until < NOW();

    GET DIAGNOSTICS v_released_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'release_stale_analytics_alert_notification_dispatch_locks',
        'completed',
        jsonb_build_object(
            'released_count', v_released_count,
            'generated_by', 'migration_115'
        ),
        NOW()
    );

    RETURN v_released_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Complete Analytics Alert Dispatch Batch Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_order_lifecycle_analytics_alert_notification_dispatch_batch(
    p_batch_id UUID,
    p_batch_status TEXT DEFAULT 'completed'
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_batch_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF p_batch_status NOT IN ('completed', 'failed', 'cancelled') THEN
        RETURN FALSE;
    END IF;

    UPDATE public.order_lifecycle_analytics_alert_notification_dispatch_batches
    SET
        batch_status = p_batch_status,
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_batch_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Dispatch Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_notification_dispatch_control_dashboard_view AS
SELECT
    j.id AS job_id,
    j.incident_id,
    j.threshold_code,
    j.metric_scope,
    j.metric_name,
    j.channel_code,
    c.channel_name,
    c.channel_type,
    j.notification_reason,
    j.priority,
    j.job_status,
    j.scheduled_at,
    j.locked_at,
    j.sent_at,
    j.failed_at,
    j.cancelled_at,
    j.attempt_count,
    j.max_attempts,
    j.last_error,

    l.id AS lock_id,
    l.batch_id,
    l.worker_id,
    l.lock_status,
    l.locked_until,
    l.released_at,
    l.completed_at AS lock_completed_at,
    l.failed_at AS lock_failed_at,

    dc.is_dispatch_enabled,
    dc.is_paused,
    dc.pause_reason,
    dc.rate_limit_per_hour,
    dc.current_window_dispatch_count,

    i.incident_title,
    i.severity,
    i.incident_status,
    i.metric_value,
    i.threshold_value,

    CASE
        WHEN j.job_status = 'sent' THEN 'sent'
        WHEN j.job_status = 'failed' THEN 'failed'
        WHEN l.lock_status = 'active' AND l.locked_until < NOW() THEN 'stale_lock'
        WHEN dc.is_paused = TRUE THEN 'channel_paused'
        WHEN dc.is_dispatch_enabled = FALSE THEN 'channel_disabled'
        WHEN j.job_status = 'locked' THEN 'in_dispatch'
        WHEN j.job_status = 'pending' AND j.scheduled_at <= NOW() THEN 'ready'
        WHEN j.job_status = 'pending' AND j.scheduled_at > NOW() THEN 'scheduled'
        WHEN j.job_status = 'cancelled' THEN 'cancelled'
        WHEN j.job_status = 'skipped' THEN 'skipped'
        ELSE 'other'
    END AS dispatch_dashboard_status,

    j.job_payload,
    j.created_at,
    j.updated_at
FROM public.order_lifecycle_analytics_alert_notification_jobs j
JOIN public.order_lifecycle_analytics_alert_incidents i
ON i.id = j.incident_id
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_channel_dispatch_controls dc
ON dc.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_analytics_alert_notification_dispatch_locks l
ON l.job_id = j.id;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_notification_dispatch_control_dashboard_view IS
'Admin dashboard view for analytics alert notification dispatch status, locks, retries, channel pause state, and delivery control.';

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_notification_dead_letter_dashboard_view AS
SELECT
    d.id,
    d.job_id,
    d.incident_id,
    d.threshold_code,
    d.metric_scope,
    d.metric_name,
    d.channel_code,
    c.channel_name,
    c.channel_type,
    d.failure_reason,
    d.final_attempt_count,
    d.reviewed_by,
    d.reviewed_at,
    d.review_notes,

    i.incident_title,
    i.severity,
    i.incident_status,

    CASE
        WHEN d.reviewed_at IS NOT NULL THEN 'reviewed'
        WHEN i.severity = 'critical' THEN 'critical_review_required'
        ELSE 'review_required'
    END AS dead_letter_dashboard_status,

    d.failure_payload,
    d.created_at,
    d.updated_at
FROM public.order_lifecycle_analytics_alert_notification_dead_letter_queue d
LEFT JOIN public.order_lifecycle_analytics_alert_incidents i
ON i.id = d.incident_id
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = d.channel_code;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_notification_dead_letter_dashboard_view IS
'Admin dashboard view for analytics alert notification dead letter queue review.';

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_notification_dispatch_health_view AS
SELECT
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

    COUNT(l.id) FILTER (
        WHERE l.lock_status = 'active'
        AND l.locked_until < NOW()
    )::INTEGER AS stale_lock_jobs,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.order_lifecycle_analytics_alert_notification_dead_letter_queue
        WHERE reviewed_at IS NULL
    ) AS unreviewed_dead_letter_jobs,

    MAX(j.created_at) AS latest_job_created_at,

    CASE
        WHEN COUNT(j.id) = 0 THEN 'no_dispatch_jobs'
        WHEN (
            SELECT COUNT(*)
            FROM public.order_lifecycle_analytics_alert_notification_dead_letter_queue
            WHERE reviewed_at IS NULL
        ) > 0 THEN 'dead_letter_attention'
        WHEN COUNT(l.id) FILTER (
            WHERE l.lock_status = 'active'
            AND l.locked_until < NOW()
        ) > 0 THEN 'stale_lock_attention'
        WHEN COUNT(j.id) FILTER (WHERE j.job_status = 'failed') > 0 THEN 'failed_jobs_attention'
        WHEN COUNT(j.id) FILTER (WHERE j.job_status = 'pending' AND j.scheduled_at <= NOW()) > 0 THEN 'ready'
        WHEN COUNT(j.id) FILTER (WHERE j.job_status = 'locked') > 0 THEN 'in_progress'
        WHEN COUNT(j.id) FILTER (WHERE j.job_status = 'sent') > 0 THEN 'healthy'
        ELSE 'idle'
    END AS dispatch_health_status
FROM public.order_lifecycle_analytics_alert_notification_jobs j
LEFT JOIN public.order_lifecycle_analytics_alert_notification_dispatch_locks l
ON l.job_id = j.id;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_notification_dispatch_health_view IS
'Shows overall dispatch health for analytics alert notification jobs.';

-- ============================================================
-- 11. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_notification_dispatch_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_notification_dispatch_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_notification_dead_letter_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage analytics alert notification dispatch batches"
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches;

CREATE POLICY "Service role can manage analytics alert notification dispatch batches"
ON public.order_lifecycle_analytics_alert_notification_dispatch_batches
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage analytics alert notification dispatch locks"
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks;

CREATE POLICY "Service role can manage analytics alert notification dispatch locks"
ON public.order_lifecycle_analytics_alert_notification_dispatch_locks
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage analytics alert notification dead letter queue"
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue;

CREATE POLICY "Service role can manage analytics alert notification dead letter queue"
ON public.order_lifecycle_analytics_alert_notification_dead_letter_queue
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
    115,
    'migration_115_order_lifecycle_analytics_alert_notification_dispatch_control',
    'Adds dispatch control, locking, retry handling, stale-lock recovery, dead-letter tracking, and dashboard views for analytics alert notification jobs.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
