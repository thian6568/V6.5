-- Migration 110: Order Lifecycle Notification Dispatch Control
-- Purpose:
-- Adds dispatch control, channel dispatch settings, job locking,
-- retry handling, stale-lock recovery, dead-letter tracking,
-- and dashboard view for order lifecycle SLA notification jobs.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Notification Dispatch Settings
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    setting_code TEXT NOT NULL UNIQUE,
    setting_name TEXT NOT NULL,
    setting_description TEXT,

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    max_locked_minutes INTEGER NOT NULL DEFAULT 15,
    retry_delay_minutes INTEGER NOT NULL DEFAULT 10,
    default_max_attempts INTEGER NOT NULL DEFAULT 3,

    setting_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_dispatch_settings_positive_values
    CHECK (
        max_locked_minutes > 0
        AND retry_delay_minutes > 0
        AND default_max_attempts > 0
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_settings IS
'Stores global dispatch settings for order lifecycle SLA notification delivery control.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_settings_code
ON public.order_lifecycle_notification_dispatch_settings(setting_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_settings_enabled
ON public.order_lifecycle_notification_dispatch_settings(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_settings_config
ON public.order_lifecycle_notification_dispatch_settings USING GIN(setting_config);

-- ============================================================
-- 2. Default Dispatch Settings
-- ============================================================

INSERT INTO public.order_lifecycle_notification_dispatch_settings (
    setting_code,
    setting_name,
    setting_description,
    is_enabled,
    max_locked_minutes,
    retry_delay_minutes,
    default_max_attempts,
    setting_config
)
VALUES
(
    'GLOBAL_NOTIFICATION_DISPATCH',
    'Global Notification Dispatch Control',
    'Default dispatch control settings for order lifecycle SLA notification jobs.',
    TRUE,
    15,
    10,
    3,
    jsonb_build_object('created_by', 'migration_110')
)
ON CONFLICT (setting_code) DO UPDATE
SET
    setting_name = EXCLUDED.setting_name,
    setting_description = EXCLUDED.setting_description,
    is_enabled = EXCLUDED.is_enabled,
    max_locked_minutes = EXCLUDED.max_locked_minutes,
    retry_delay_minutes = EXCLUDED.retry_delay_minutes,
    default_max_attempts = EXCLUDED.default_max_attempts,
    setting_config = EXCLUDED.setting_config,
    updated_at = NOW();

-- ============================================================
-- 3. Channel Dispatch Controls
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_channel_dispatch_controls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    channel_code TEXT NOT NULL UNIQUE REFERENCES public.order_lifecycle_notification_channels(channel_code),

    is_dispatch_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_paused BOOLEAN NOT NULL DEFAULT FALSE,

    pause_reason TEXT,

    rate_limit_per_hour INTEGER NOT NULL DEFAULT 1000,
    current_window_started_at TIMESTAMPTZ,
    current_window_dispatch_count INTEGER NOT NULL DEFAULT 0,

    control_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_channel_dispatch_controls_rate_limit
    CHECK (rate_limit_per_hour > 0 AND current_window_dispatch_count >= 0)
);

COMMENT ON TABLE public.order_lifecycle_channel_dispatch_controls IS
'Stores per-channel dispatch enablement, pause status, and rate-limit controls.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_channel_dispatch_controls_channel
ON public.order_lifecycle_channel_dispatch_controls(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_channel_dispatch_controls_enabled
ON public.order_lifecycle_channel_dispatch_controls(is_dispatch_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_channel_dispatch_controls_paused
ON public.order_lifecycle_channel_dispatch_controls(is_paused);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_channel_dispatch_controls_config
ON public.order_lifecycle_channel_dispatch_controls USING GIN(control_config);

-- ============================================================
-- 4. Backfill Channel Dispatch Controls
-- ============================================================

INSERT INTO public.order_lifecycle_channel_dispatch_controls (
    channel_code,
    is_dispatch_enabled,
    is_paused,
    rate_limit_per_hour,
    current_window_started_at,
    current_window_dispatch_count,
    control_config
)
SELECT
    channel_code,
    TRUE,
    FALSE,
    CASE
        WHEN channel_type = 'sms' THEN 100
        WHEN channel_type = 'email' THEN 500
        ELSE 1000
    END,
    NOW(),
    0,
    jsonb_build_object(
        'created_by', 'migration_110',
        'channel_type', channel_type
    )
FROM public.order_lifecycle_notification_channels
ON CONFLICT (channel_code) DO UPDATE
SET
    is_dispatch_enabled = EXCLUDED.is_dispatch_enabled,
    rate_limit_per_hour = EXCLUDED.rate_limit_per_hour,
    control_config = EXCLUDED.control_config,
    updated_at = NOW();

-- ============================================================
-- 5. Notification Dispatch Batches
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    batch_code TEXT NOT NULL UNIQUE,
    worker_id TEXT NOT NULL DEFAULT 'system_dispatcher',

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

    CONSTRAINT chk_order_lifecycle_dispatch_batches_status
    CHECK (batch_status IN ('created', 'running', 'completed', 'failed', 'cancelled')),

    CONSTRAINT chk_order_lifecycle_dispatch_batches_counts
    CHECK (
        requested_job_count >= 0
        AND locked_job_count >= 0
        AND sent_job_count >= 0
        AND failed_job_count >= 0
        AND skipped_job_count >= 0
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_batches IS
'Stores dispatch batch records for grouped notification job processing.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_batches_code
ON public.order_lifecycle_notification_dispatch_batches(batch_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_batches_worker
ON public.order_lifecycle_notification_dispatch_batches(worker_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_batches_status
ON public.order_lifecycle_notification_dispatch_batches(batch_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_batches_channel
ON public.order_lifecycle_notification_dispatch_batches(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_batches_payload
ON public.order_lifecycle_notification_dispatch_batches USING GIN(batch_payload);

-- ============================================================
-- 6. Notification Dispatch Locks
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dispatch_locks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL UNIQUE REFERENCES public.order_lifecycle_sla_notification_jobs(id) ON DELETE CASCADE,

    batch_id UUID REFERENCES public.order_lifecycle_notification_dispatch_batches(id) ON DELETE SET NULL,

    worker_id TEXT NOT NULL DEFAULT 'system_dispatcher',

    lock_status TEXT NOT NULL DEFAULT 'active',

    locked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_until TIMESTAMPTZ NOT NULL,

    released_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    lock_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_dispatch_locks_status
    CHECK (lock_status IN ('active', 'released', 'completed', 'failed', 'expired', 'cancelled'))
);

COMMENT ON TABLE public.order_lifecycle_notification_dispatch_locks IS
'Tracks worker locks for SLA notification dispatch jobs to prevent duplicate delivery.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_job_id
ON public.order_lifecycle_notification_dispatch_locks(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_batch_id
ON public.order_lifecycle_notification_dispatch_locks(batch_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_worker
ON public.order_lifecycle_notification_dispatch_locks(worker_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_status
ON public.order_lifecycle_notification_dispatch_locks(lock_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_locked_until
ON public.order_lifecycle_notification_dispatch_locks(locked_until);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dispatch_locks_payload
ON public.order_lifecycle_notification_dispatch_locks USING GIN(lock_payload);

-- ============================================================
-- 7. Notification Dead Letter Queue
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_dead_letter_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL UNIQUE REFERENCES public.order_lifecycle_sla_notification_jobs(id) ON DELETE CASCADE,
    exception_id UUID NOT NULL REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

    channel_code TEXT NOT NULL,

    failure_reason TEXT NOT NULL,
    failure_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    final_attempt_count INTEGER NOT NULL DEFAULT 0,

    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_dead_letter_final_attempt_count
    CHECK (final_attempt_count >= 0)
);

COMMENT ON TABLE public.order_lifecycle_notification_dead_letter_queue IS
'Stores notification jobs that failed permanently after exhausting retry attempts.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dead_letter_job_id
ON public.order_lifecycle_notification_dead_letter_queue(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dead_letter_exception_id
ON public.order_lifecycle_notification_dead_letter_queue(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dead_letter_order_id
ON public.order_lifecycle_notification_dead_letter_queue(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dead_letter_channel
ON public.order_lifecycle_notification_dead_letter_queue(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_dead_letter_payload
ON public.order_lifecycle_notification_dead_letter_queue USING GIN(failure_payload);

-- ============================================================
-- 8. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_dispatch_settings_updated_at
ON public.order_lifecycle_notification_dispatch_settings;

CREATE TRIGGER trg_order_lifecycle_dispatch_settings_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dispatch_settings
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_channel_dispatch_controls_updated_at
ON public.order_lifecycle_channel_dispatch_controls;

CREATE TRIGGER trg_order_lifecycle_channel_dispatch_controls_updated_at
BEFORE UPDATE ON public.order_lifecycle_channel_dispatch_controls
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_dispatch_batches_updated_at
ON public.order_lifecycle_notification_dispatch_batches;

CREATE TRIGGER trg_order_lifecycle_dispatch_batches_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dispatch_batches
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_dispatch_locks_updated_at
ON public.order_lifecycle_notification_dispatch_locks;

CREATE TRIGGER trg_order_lifecycle_dispatch_locks_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dispatch_locks
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_dead_letter_updated_at
ON public.order_lifecycle_notification_dead_letter_queue;

CREATE TRIGGER trg_order_lifecycle_dead_letter_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_dead_letter_queue
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_dispatch_updated_at();

-- ============================================================
-- 9. Check Channel Dispatch Availability
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_dispatch_order_lifecycle_notification_channel(
    p_channel_code TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_channel RECORD;
    v_control RECORD;
BEGIN
    IF p_channel_code IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT *
    INTO v_channel
    FROM public.order_lifecycle_notification_channels
    WHERE channel_code = p_channel_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_channel.is_enabled = FALSE THEN
        RETURN FALSE;
    END IF;

    SELECT *
    INTO v_control
    FROM public.order_lifecycle_channel_dispatch_controls
    WHERE channel_code = p_channel_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    IF v_control.is_dispatch_enabled = FALSE OR v_control.is_paused = TRUE THEN
        RETURN FALSE;
    END IF;

    IF v_control.current_window_started_at IS NULL
       OR v_control.current_window_started_at < NOW() - INTERVAL '1 hour' THEN
        UPDATE public.order_lifecycle_channel_dispatch_controls
        SET
            current_window_started_at = NOW(),
            current_window_dispatch_count = 0,
            updated_at = NOW()
        WHERE channel_code = p_channel_code;

        RETURN TRUE;
    END IF;

    IF v_control.current_window_dispatch_count >= v_control.rate_limit_per_hour THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Acquire Next Notification Job
-- ============================================================

CREATE OR REPLACE FUNCTION public.acquire_next_order_lifecycle_notification_dispatch_job(
    p_worker_id TEXT DEFAULT 'system_dispatcher',
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
    FROM public.order_lifecycle_sla_notification_jobs j
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

    UPDATE public.order_lifecycle_sla_notification_jobs
    SET
        job_status = 'locked',
        locked_at = NOW(),
        updated_at = NOW()
    WHERE id = v_job.id;

    INSERT INTO public.order_lifecycle_notification_dispatch_locks (
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
        COALESCE(p_worker_id, 'system_dispatcher'),
        'active',
        NOW(),
        v_locked_until,
        jsonb_build_object(
            'job_id', v_job.id,
            'channel_code', v_job.channel_code,
            'worker_id', COALESCE(p_worker_id, 'system_dispatcher'),
            'generated_by', 'migration_110'
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
        UPDATE public.order_lifecycle_notification_dispatch_batches
        SET
            batch_status = 'running',
            locked_job_count = locked_job_count + 1,
            started_at = COALESCE(started_at, NOW()),
            updated_at = NOW()
        WHERE id = p_batch_id;
    END IF;

    RETURN v_job.id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. Create Dispatch Batch Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_lifecycle_notification_dispatch_batch(
    p_worker_id TEXT DEFAULT 'system_dispatcher',
    p_channel_code TEXT DEFAULT NULL,
    p_requested_job_count INTEGER DEFAULT 10,
    p_batch_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_batch_code TEXT;
BEGIN
    v_batch_code := 'dispatch_' || replace(gen_random_uuid()::TEXT, '-', '');

    INSERT INTO public.order_lifecycle_notification_dispatch_batches (
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
        COALESCE(p_worker_id, 'system_dispatcher'),
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
-- 12. Record Dispatch Result Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_notification_dispatch_result(
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
    FROM public.order_lifecycle_sla_notification_jobs
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

    v_attempt_id := public.record_order_lifecycle_sla_notification_delivery_attempt(
        p_job_id,
        p_dispatch_status,
        COALESCE(p_response_payload, '{}'::jsonb),
        p_error_message
    );

    IF p_dispatch_status = 'sent' THEN
        UPDATE public.order_lifecycle_notification_dispatch_locks
        SET
            lock_status = 'completed',
            completed_at = NOW(),
            updated_at = NOW()
        WHERE job_id = p_job_id;

        UPDATE public.order_lifecycle_notification_dispatch_batches b
        SET
            sent_job_count = sent_job_count + 1,
            updated_at = NOW()
        FROM public.order_lifecycle_notification_dispatch_locks l
        WHERE l.batch_id = b.id
        AND l.job_id = p_job_id;

        RETURN v_attempt_id;
    END IF;

    IF p_dispatch_status = 'failed' THEN
        SELECT *
        INTO v_job
        FROM public.order_lifecycle_sla_notification_jobs
        WHERE id = p_job_id
        LIMIT 1;

        IF v_job.attempt_count >= v_job.max_attempts THEN
            INSERT INTO public.order_lifecycle_notification_dead_letter_queue (
                job_id,
                exception_id,
                order_id,
                channel_code,
                failure_reason,
                failure_payload,
                final_attempt_count,
                created_at,
                updated_at
            )
            VALUES (
                v_job.id,
                v_job.exception_id,
                v_job.order_id,
                v_job.channel_code,
                COALESCE(p_error_message, 'Maximum notification dispatch attempts reached.'),
                jsonb_build_object(
                    'job_id', v_job.id,
                    'channel_code', v_job.channel_code,
                    'attempt_count', v_job.attempt_count,
                    'max_attempts', v_job.max_attempts,
                    'response_payload', COALESCE(p_response_payload, '{}'::jsonb),
                    'generated_by', 'migration_110'
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

            UPDATE public.order_lifecycle_notification_dispatch_locks
            SET
                lock_status = 'failed',
                failed_at = NOW(),
                updated_at = NOW()
            WHERE job_id = p_job_id;

            UPDATE public.order_lifecycle_notification_dispatch_batches b
            SET
                failed_job_count = failed_job_count + 1,
                updated_at = NOW()
            FROM public.order_lifecycle_notification_dispatch_locks l
            WHERE l.batch_id = b.id
            AND l.job_id = p_job_id;
        ELSE
            UPDATE public.order_lifecycle_sla_notification_jobs
            SET
                job_status = 'pending',
                locked_at = NULL,
                scheduled_at = NOW() + make_interval(mins => v_retry_delay_minutes),
                last_error = COALESCE(p_error_message, last_error),
                updated_at = NOW()
            WHERE id = p_job_id;

            UPDATE public.order_lifecycle_notification_dispatch_locks
            SET
                lock_status = 'released',
                released_at = NOW(),
                updated_at = NOW()
            WHERE job_id = p_job_id;
        END IF;

        RETURN v_attempt_id;
    END IF;

    IF p_dispatch_status IN ('cancelled', 'skipped') THEN
        UPDATE public.order_lifecycle_notification_dispatch_locks
        SET
            lock_status = p_dispatch_status,
            released_at = NOW(),
            updated_at = NOW()
        WHERE job_id = p_job_id;

        UPDATE public.order_lifecycle_notification_dispatch_batches b
        SET
            skipped_job_count = skipped_job_count + 1,
            updated_at = NOW()
        FROM public.order_lifecycle_notification_dispatch_locks l
        WHERE l.batch_id = b.id
        AND l.job_id = p_job_id;
    END IF;

    RETURN v_attempt_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 13. Release Stale Dispatch Locks
-- ============================================================

CREATE OR REPLACE FUNCTION public.release_stale_order_lifecycle_notification_dispatch_locks()
RETURNS INTEGER AS $$
DECLARE
    v_released_count INTEGER := 0;
BEGIN
    UPDATE public.order_lifecycle_sla_notification_jobs j
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
        last_error = COALESCE(j.last_error, 'Dispatch lock expired before completion.'),
        updated_at = NOW()
    FROM public.order_lifecycle_notification_dispatch_locks l
    WHERE l.job_id = j.id
    AND l.lock_status = 'active'
    AND l.locked_until < NOW();

    UPDATE public.order_lifecycle_notification_dispatch_locks
    SET
        lock_status = 'expired',
        released_at = NOW(),
        updated_at = NOW()
    WHERE lock_status = 'active'
    AND locked_until < NOW();

    GET DIAGNOSTICS v_released_count = ROW_COUNT;

    RETURN v_released_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 14. Complete Dispatch Batch Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_order_lifecycle_notification_dispatch_batch(
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

    UPDATE public.order_lifecycle_notification_dispatch_batches
    SET
        batch_status = p_batch_status,
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_batch_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 15. Dispatch Control Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_dispatch_control_dashboard_view AS
SELECT
    j.id AS job_id,
    j.exception_id,
    j.sla_tracking_id,
    j.order_id,
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

    CASE
        WHEN j.job_status = 'sent' THEN 'sent'
        WHEN j.job_status = 'failed' THEN 'failed'
        WHEN l.lock_status = 'active' AND l.locked_until < NOW() THEN 'stale_lock'
        WHEN dc.is_paused = TRUE THEN 'channel_paused'
        WHEN dc.is_dispatch_enabled = FALSE THEN 'channel_disabled'
        WHEN j.job_status = 'locked' THEN 'in_dispatch'
        WHEN j.job_status = 'pending' AND j.scheduled_at <= NOW() THEN 'ready'
        WHEN j.job_status = 'pending' AND j.scheduled_at > NOW() THEN 'scheduled'
        ELSE 'other'
    END AS dispatch_dashboard_status,

    j.job_payload,
    j.created_at,
    j.updated_at
FROM public.order_lifecycle_sla_notification_jobs j
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_channel_dispatch_controls dc
ON dc.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_notification_dispatch_locks l
ON l.job_id = j.id;

COMMENT ON VIEW public.order_lifecycle_notification_dispatch_control_dashboard_view IS
'Admin dashboard view for notification dispatch status, locks, retries, channel pause state, and delivery control.';

-- ============================================================
-- 16. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_notification_dispatch_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_channel_dispatch_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dispatch_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dispatch_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_dead_letter_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch settings"
ON public.order_lifecycle_notification_dispatch_settings;

CREATE POLICY "Service role can manage order lifecycle dispatch settings"
ON public.order_lifecycle_notification_dispatch_settings
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle channel dispatch controls"
ON public.order_lifecycle_channel_dispatch_controls;

CREATE POLICY "Service role can manage order lifecycle channel dispatch controls"
ON public.order_lifecycle_channel_dispatch_controls
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch batches"
ON public.order_lifecycle_notification_dispatch_batches;

CREATE POLICY "Service role can manage order lifecycle dispatch batches"
ON public.order_lifecycle_notification_dispatch_batches
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dispatch locks"
ON public.order_lifecycle_notification_dispatch_locks;

CREATE POLICY "Service role can manage order lifecycle dispatch locks"
ON public.order_lifecycle_notification_dispatch_locks
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle dead letter queue"
ON public.order_lifecycle_notification_dead_letter_queue;

CREATE POLICY "Service role can manage order lifecycle dead letter queue"
ON public.order_lifecycle_notification_dead_letter_queue
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 17. Migration Registry Marker
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
    110,
    'migration_110_order_lifecycle_notification_dispatch_control',
    'Adds dispatch control, channel dispatch settings, job locking, retry handling, stale-lock recovery, dead-letter tracking, and dashboard view for order lifecycle SLA notification jobs.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
