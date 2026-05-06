-- Migration 112: Order Lifecycle Notification Analytics Scheduled Refresh
-- Purpose:
-- Adds scheduled refresh control, refresh run tracking, refresh step logging,
-- due-schedule execution functions, and dashboard views for notification analytics.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Refresh Schedules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_analytics_refresh_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_code TEXT NOT NULL UNIQUE,
    schedule_name TEXT NOT NULL,
    schedule_description TEXT,

    refresh_scope TEXT NOT NULL DEFAULT 'all',

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    frequency_minutes INTEGER NOT NULL DEFAULT 60,
    lookback_days INTEGER NOT NULL DEFAULT 30,

    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    schedule_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_schedules_scope
    CHECK (
        refresh_scope IN (
            'all',
            'daily_dispatch',
            'worker_dispatch',
            'exception_notification',
            'kpi_snapshot'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_schedules_timing
    CHECK (
        frequency_minutes > 0
        AND lookback_days >= 0
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_analytics_refresh_schedules IS
'Stores scheduled refresh settings for order lifecycle notification dispatch analytics.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_schedules_code
ON public.order_lifecycle_notification_analytics_refresh_schedules(schedule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_schedules_enabled
ON public.order_lifecycle_notification_analytics_refresh_schedules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_schedules_next_run
ON public.order_lifecycle_notification_analytics_refresh_schedules(next_run_at);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_schedules_config
ON public.order_lifecycle_notification_analytics_refresh_schedules USING GIN(schedule_config);

-- ============================================================
-- 2. Default Refresh Schedules
-- ============================================================

INSERT INTO public.order_lifecycle_notification_analytics_refresh_schedules (
    schedule_code,
    schedule_name,
    schedule_description,
    refresh_scope,
    is_enabled,
    frequency_minutes,
    lookback_days,
    next_run_at,
    schedule_config
)
VALUES
(
    'HOURLY_ALL_NOTIFICATION_ANALYTICS_REFRESH',
    'Hourly Notification Analytics Refresh',
    'Refreshes all notification dispatch analytics every hour using a 30-day lookback window.',
    'all',
    TRUE,
    60,
    30,
    NOW(),
    jsonb_build_object(
        'created_by', 'migration_112',
        'recommended_for', 'admin_dashboard'
    )
),
(
    'DAILY_DEEP_NOTIFICATION_ANALYTICS_REFRESH',
    'Daily Deep Notification Analytics Refresh',
    'Refreshes all notification dispatch analytics daily using a 90-day lookback window.',
    'all',
    TRUE,
    1440,
    90,
    NOW() + INTERVAL '1 day',
    jsonb_build_object(
        'created_by', 'migration_112',
        'recommended_for', 'daily_reporting'
    )
),
(
    'HOURLY_KPI_SNAPSHOT_REFRESH',
    'Hourly KPI Snapshot Refresh',
    'Creates a fresh KPI snapshot every hour.',
    'kpi_snapshot',
    TRUE,
    60,
    0,
    NOW(),
    jsonb_build_object(
        'created_by', 'migration_112',
        'recommended_for', 'latest_kpi_panel'
    )
)
ON CONFLICT (schedule_code) DO UPDATE
SET
    schedule_name = EXCLUDED.schedule_name,
    schedule_description = EXCLUDED.schedule_description,
    refresh_scope = EXCLUDED.refresh_scope,
    is_enabled = EXCLUDED.is_enabled,
    frequency_minutes = EXCLUDED.frequency_minutes,
    lookback_days = EXCLUDED.lookback_days,
    schedule_config = EXCLUDED.schedule_config,
    updated_at = NOW();

-- ============================================================
-- 3. Analytics Refresh Runs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_analytics_refresh_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_id UUID REFERENCES public.order_lifecycle_notification_analytics_refresh_schedules(id) ON DELETE SET NULL,
    schedule_code TEXT,

    refresh_scope TEXT NOT NULL DEFAULT 'all',
    run_status TEXT NOT NULL DEFAULT 'created',

    from_date DATE,
    to_date DATE,

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    daily_analytics_rows INTEGER NOT NULL DEFAULT 0,
    worker_analytics_rows INTEGER NOT NULL DEFAULT 0,
    exception_analytics_rows INTEGER NOT NULL DEFAULT 0,

    snapshot_id UUID,

    error_message TEXT,

    result_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_runs_scope
    CHECK (
        refresh_scope IN (
            'all',
            'daily_dispatch',
            'worker_dispatch',
            'exception_notification',
            'kpi_snapshot'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_runs_status
    CHECK (
        run_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'cancelled',
            'skipped'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_runs_counts
    CHECK (
        daily_analytics_rows >= 0
        AND worker_analytics_rows >= 0
        AND exception_analytics_rows >= 0
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_analytics_refresh_runs IS
'Stores execution history for scheduled order lifecycle notification analytics refresh jobs.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_schedule
ON public.order_lifecycle_notification_analytics_refresh_runs(schedule_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_code
ON public.order_lifecycle_notification_analytics_refresh_runs(schedule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_status
ON public.order_lifecycle_notification_analytics_refresh_runs(run_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_scope
ON public.order_lifecycle_notification_analytics_refresh_runs(refresh_scope);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_created_at
ON public.order_lifecycle_notification_analytics_refresh_runs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_runs_payload
ON public.order_lifecycle_notification_analytics_refresh_runs USING GIN(result_payload);

-- ============================================================
-- 4. Analytics Refresh Run Steps
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_analytics_refresh_run_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    refresh_run_id UUID NOT NULL REFERENCES public.order_lifecycle_notification_analytics_refresh_runs(id) ON DELETE CASCADE,

    step_code TEXT NOT NULL,
    step_name TEXT NOT NULL,
    step_status TEXT NOT NULL DEFAULT 'created',

    affected_rows INTEGER NOT NULL DEFAULT 0,

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    error_message TEXT,

    step_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_run_steps_status
    CHECK (
        step_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'skipped'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_refresh_run_steps_rows
    CHECK (affected_rows >= 0)
);

COMMENT ON TABLE public.order_lifecycle_notification_analytics_refresh_run_steps IS
'Stores detailed step-level logs for analytics refresh execution.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_run_steps_run
ON public.order_lifecycle_notification_analytics_refresh_run_steps(refresh_run_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_run_steps_code
ON public.order_lifecycle_notification_analytics_refresh_run_steps(step_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_run_steps_status
ON public.order_lifecycle_notification_analytics_refresh_run_steps(step_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_refresh_run_steps_payload
ON public.order_lifecycle_notification_analytics_refresh_run_steps USING GIN(step_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_notification_analytics_refresh_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_refresh_schedules_updated_at
ON public.order_lifecycle_notification_analytics_refresh_schedules;

CREATE TRIGGER trg_order_lifecycle_analytics_refresh_schedules_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_analytics_refresh_schedules
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_analytics_refresh_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_refresh_runs_updated_at
ON public.order_lifecycle_notification_analytics_refresh_runs;

CREATE TRIGGER trg_order_lifecycle_analytics_refresh_runs_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_analytics_refresh_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_notification_analytics_refresh_updated_at();

-- ============================================================
-- 6. Record Refresh Step Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_notification_analytics_refresh_step(
    p_refresh_run_id UUID,
    p_step_code TEXT,
    p_step_name TEXT,
    p_step_status TEXT,
    p_affected_rows INTEGER DEFAULT 0,
    p_error_message TEXT DEFAULT NULL,
    p_step_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_step_id UUID;
BEGIN
    IF p_refresh_run_id IS NULL
       OR p_step_code IS NULL
       OR p_step_name IS NULL
       OR p_step_status IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.order_lifecycle_notification_analytics_refresh_run_steps (
        refresh_run_id,
        step_code,
        step_name,
        step_status,
        affected_rows,
        started_at,
        completed_at,
        failed_at,
        error_message,
        step_payload,
        created_at
    )
    VALUES (
        p_refresh_run_id,
        p_step_code,
        p_step_name,
        p_step_status,
        COALESCE(p_affected_rows, 0),
        CASE
            WHEN p_step_status = 'running' THEN NOW()
            ELSE NULL
        END,
        CASE
            WHEN p_step_status = 'completed' THEN NOW()
            ELSE NULL
        END,
        CASE
            WHEN p_step_status = 'failed' THEN NOW()
            ELSE NULL
        END,
        p_error_message,
        COALESCE(p_step_payload, '{}'::jsonb),
        NOW()
    )
    RETURNING id INTO v_step_id;

    RETURN v_step_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Run One Analytics Refresh Schedule
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_order_lifecycle_notification_analytics_refresh_schedule(
    p_schedule_code TEXT
)
RETURNS UUID AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;

    v_from_date DATE;
    v_to_date DATE;

    v_daily_rows INTEGER := 0;
    v_worker_rows INTEGER := 0;
    v_exception_rows INTEGER := 0;
    v_snapshot_id UUID;

    v_result_payload JSONB := '{}'::jsonb;
BEGIN
    IF p_schedule_code IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_schedule
    FROM public.order_lifecycle_notification_analytics_refresh_schedules
    WHERE schedule_code = p_schedule_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_schedule.is_enabled = FALSE THEN
        INSERT INTO public.order_lifecycle_notification_analytics_refresh_runs (
            schedule_id,
            schedule_code,
            refresh_scope,
            run_status,
            result_payload,
            created_at,
            updated_at
        )
        VALUES (
            v_schedule.id,
            v_schedule.schedule_code,
            v_schedule.refresh_scope,
            'skipped',
            jsonb_build_object(
                'reason', 'schedule_disabled',
                'schedule_code', v_schedule.schedule_code,
                'generated_by', 'migration_112'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_run_id;

        RETURN v_run_id;
    END IF;

    v_to_date := CURRENT_DATE;
    v_from_date := CURRENT_DATE - COALESCE(v_schedule.lookback_days, 30);

    INSERT INTO public.order_lifecycle_notification_analytics_refresh_runs (
        schedule_id,
        schedule_code,
        refresh_scope,
        run_status,
        from_date,
        to_date,
        started_at,
        result_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_schedule.id,
        v_schedule.schedule_code,
        v_schedule.refresh_scope,
        'running',
        v_from_date,
        v_to_date,
        NOW(),
        jsonb_build_object(
            'schedule_code', v_schedule.schedule_code,
            'refresh_scope', v_schedule.refresh_scope,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'generated_by', 'migration_112'
        ),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_run_id;

    BEGIN
        IF v_schedule.refresh_scope IN ('all', 'daily_dispatch') THEN
            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'daily_dispatch_analytics',
                'Refresh Daily Dispatch Analytics',
                'running',
                0,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );

            v_daily_rows := public.refresh_order_lifecycle_notification_dispatch_daily_analytics(
                v_from_date,
                v_to_date
            );

            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'daily_dispatch_analytics',
                'Refresh Daily Dispatch Analytics',
                'completed',
                v_daily_rows,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );
        END IF;

        IF v_schedule.refresh_scope IN ('all', 'worker_dispatch') THEN
            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'worker_dispatch_analytics',
                'Refresh Worker Dispatch Analytics',
                'running',
                0,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );

            v_worker_rows := public.refresh_order_lifecycle_notification_dispatch_worker_analytics(
                v_from_date,
                v_to_date
            );

            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'worker_dispatch_analytics',
                'Refresh Worker Dispatch Analytics',
                'completed',
                v_worker_rows,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );
        END IF;

        IF v_schedule.refresh_scope IN ('all', 'exception_notification') THEN
            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'exception_notification_analytics',
                'Refresh Exception Notification Analytics',
                'running',
                0,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );

            v_exception_rows := public.refresh_order_lifecycle_notification_exception_analytics(
                v_from_date,
                v_to_date
            );

            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'exception_notification_analytics',
                'Refresh Exception Notification Analytics',
                'completed',
                v_exception_rows,
                NULL,
                jsonb_build_object('from_date', v_from_date, 'to_date', v_to_date)
            );
        END IF;

        IF v_schedule.refresh_scope IN ('all', 'kpi_snapshot') THEN
            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'kpi_snapshot',
                'Create KPI Snapshot',
                'running',
                0,
                NULL,
                jsonb_build_object('snapshot_scope', v_schedule.refresh_scope)
            );

            v_snapshot_id := public.create_order_lifecycle_notification_dispatch_kpi_snapshot(
                v_schedule.refresh_scope
            );

            PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
                v_run_id,
                'kpi_snapshot',
                'Create KPI Snapshot',
                'completed',
                1,
                NULL,
                jsonb_build_object('snapshot_id', v_snapshot_id)
            );
        END IF;

        v_result_payload := jsonb_build_object(
            'schedule_code', v_schedule.schedule_code,
            'refresh_scope', v_schedule.refresh_scope,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'daily_analytics_rows', v_daily_rows,
            'worker_analytics_rows', v_worker_rows,
            'exception_analytics_rows', v_exception_rows,
            'snapshot_id', v_snapshot_id,
            'generated_by', 'migration_112'
        );

        UPDATE public.order_lifecycle_notification_analytics_refresh_runs
        SET
            run_status = 'completed',
            completed_at = NOW(),
            daily_analytics_rows = COALESCE(v_daily_rows, 0),
            worker_analytics_rows = COALESCE(v_worker_rows, 0),
            exception_analytics_rows = COALESCE(v_exception_rows, 0),
            snapshot_id = v_snapshot_id,
            result_payload = v_result_payload,
            updated_at = NOW()
        WHERE id = v_run_id;

        UPDATE public.order_lifecycle_notification_analytics_refresh_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'scheduled_analytics_refresh_completed',
            'completed',
            v_result_payload,
            NOW()
        );

    EXCEPTION WHEN OTHERS THEN
        UPDATE public.order_lifecycle_notification_analytics_refresh_runs
        SET
            run_status = 'failed',
            failed_at = NOW(),
            error_message = SQLERRM,
            result_payload = jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'refresh_scope', v_schedule.refresh_scope,
                'error_message', SQLERRM,
                'generated_by', 'migration_112'
            ),
            updated_at = NOW()
        WHERE id = v_run_id;

        PERFORM public.record_order_lifecycle_notification_analytics_refresh_step(
            v_run_id,
            'scheduled_refresh_error',
            'Scheduled Refresh Error',
            'failed',
            0,
            SQLERRM,
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'refresh_scope', v_schedule.refresh_scope
            )
        );

        UPDATE public.order_lifecycle_notification_analytics_refresh_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'scheduled_analytics_refresh_failed',
            'failed',
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'refresh_scope', v_schedule.refresh_scope,
                'error_message', SQLERRM,
                'generated_by', 'migration_112'
            ),
            NOW()
        );
    END;

    RETURN v_run_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Run Due Analytics Refresh Schedules
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_due_order_lifecycle_notification_analytics_refresh_schedules()
RETURNS JSONB AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;
    v_run_count INTEGER := 0;
    v_run_ids JSONB := '[]'::jsonb;
BEGIN
    FOR v_schedule IN
        SELECT *
        FROM public.order_lifecycle_notification_analytics_refresh_schedules
        WHERE is_enabled = TRUE
        AND next_run_at <= NOW()
        ORDER BY next_run_at ASC, created_at ASC
    LOOP
        v_run_id := public.run_order_lifecycle_notification_analytics_refresh_schedule(
            v_schedule.schedule_code
        );

        IF v_run_id IS NOT NULL THEN
            v_run_count := v_run_count + 1;
            v_run_ids := v_run_ids || jsonb_build_array(v_run_id);
        END IF;
    END LOOP;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'run_due_scheduled_analytics_refreshes',
        'completed',
        jsonb_build_object(
            'run_count', v_run_count,
            'run_ids', v_run_ids,
            'generated_by', 'migration_112'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'run_count', v_run_count,
        'run_ids', v_run_ids,
        'generated_by', 'migration_112'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Pause / Resume Refresh Schedule Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_notification_analytics_refresh_schedule_enabled(
    p_schedule_code TEXT,
    p_is_enabled BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_is_enabled IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.order_lifecycle_notification_analytics_refresh_schedules
    SET
        is_enabled = p_is_enabled,
        updated_at = NOW()
    WHERE schedule_code = p_schedule_code;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.reschedule_order_lifecycle_notification_analytics_refresh_schedule(
    p_schedule_code TEXT,
    p_next_run_at TIMESTAMPTZ
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_next_run_at IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.order_lifecycle_notification_analytics_refresh_schedules
    SET
        next_run_at = p_next_run_at,
        updated_at = NOW()
    WHERE schedule_code = p_schedule_code;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Scheduled Refresh Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_analytics_refresh_schedule_dashboard_view AS
SELECT
    s.id,
    s.schedule_code,
    s.schedule_name,
    s.schedule_description,
    s.refresh_scope,
    s.is_enabled,
    s.frequency_minutes,
    s.lookback_days,
    s.last_run_at,
    s.next_run_at,

    CASE
        WHEN s.is_enabled = FALSE THEN 'disabled'
        WHEN s.next_run_at <= NOW() THEN 'due_now'
        WHEN s.next_run_at <= NOW() + INTERVAL '15 minutes' THEN 'due_soon'
        ELSE 'scheduled'
    END AS schedule_dashboard_status,

    latest_run.id AS latest_run_id,
    latest_run.run_status AS latest_run_status,
    latest_run.started_at AS latest_run_started_at,
    latest_run.completed_at AS latest_run_completed_at,
    latest_run.failed_at AS latest_run_failed_at,
    latest_run.error_message AS latest_run_error_message,

    s.schedule_config,
    s.created_at,
    s.updated_at
FROM public.order_lifecycle_notification_analytics_refresh_schedules s
LEFT JOIN LATERAL (
    SELECT r.*
    FROM public.order_lifecycle_notification_analytics_refresh_runs r
    WHERE r.schedule_id = s.id
    ORDER BY r.created_at DESC
    LIMIT 1
) latest_run ON TRUE;

COMMENT ON VIEW public.order_lifecycle_notification_analytics_refresh_schedule_dashboard_view IS
'Admin dashboard view for analytics refresh schedules and their latest run status.';

-- ============================================================
-- 11. Refresh Run Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_analytics_refresh_run_dashboard_view AS
SELECT
    r.id AS refresh_run_id,
    r.schedule_id,
    r.schedule_code,
    r.refresh_scope,
    r.run_status,
    r.from_date,
    r.to_date,
    r.started_at,
    r.completed_at,
    r.failed_at,

    r.daily_analytics_rows,
    r.worker_analytics_rows,
    r.exception_analytics_rows,
    r.snapshot_id,

    r.error_message,

    COUNT(st.id)::INTEGER AS step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'completed')::INTEGER AS completed_step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'failed')::INTEGER AS failed_step_count,

    CASE
        WHEN r.run_status = 'failed' THEN 'attention_required'
        WHEN COUNT(st.id) FILTER (WHERE st.step_status = 'failed') > 0 THEN 'step_failure'
        WHEN r.run_status = 'running' THEN 'running'
        WHEN r.run_status = 'completed' THEN 'completed'
        WHEN r.run_status = 'skipped' THEN 'skipped'
        ELSE 'created'
    END AS refresh_run_dashboard_status,

    r.result_payload,
    r.created_at,
    r.updated_at
FROM public.order_lifecycle_notification_analytics_refresh_runs r
LEFT JOIN public.order_lifecycle_notification_analytics_refresh_run_steps st
ON st.refresh_run_id = r.id
GROUP BY
    r.id,
    r.schedule_id,
    r.schedule_code,
    r.refresh_scope,
    r.run_status,
    r.from_date,
    r.to_date,
    r.started_at,
    r.completed_at,
    r.failed_at,
    r.daily_analytics_rows,
    r.worker_analytics_rows,
    r.exception_analytics_rows,
    r.snapshot_id,
    r.error_message,
    r.result_payload,
    r.created_at,
    r.updated_at;

COMMENT ON VIEW public.order_lifecycle_notification_analytics_refresh_run_dashboard_view IS
'Admin dashboard view for analytics refresh run history and step summary.';

-- ============================================================
-- 12. Scheduled Refresh Health View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_notification_analytics_scheduled_refresh_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE)::INTEGER AS enabled_schedules,
    COUNT(*) FILTER (WHERE is_enabled = FALSE)::INTEGER AS disabled_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at <= NOW())::INTEGER AS due_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at > NOW())::INTEGER AS future_schedules,
    MIN(next_run_at) FILTER (WHERE is_enabled = TRUE) AS next_due_at,
    MAX(last_run_at) AS latest_run_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'not_configured'
        WHEN COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at <= NOW()) > 0 THEN 'due'
        WHEN MAX(last_run_at) IS NULL THEN 'not_started'
        WHEN MAX(last_run_at) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'healthy'
    END AS scheduled_refresh_health_status
FROM public.order_lifecycle_notification_analytics_refresh_schedules;

COMMENT ON VIEW public.order_lifecycle_notification_analytics_scheduled_refresh_health_view IS
'Shows overall health status for scheduled notification analytics refresh control.';

-- ============================================================
-- 13. Initial Due Refresh Run
-- ============================================================

SELECT public.run_due_order_lifecycle_notification_analytics_refresh_schedules();

-- ============================================================
-- 14. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_notification_analytics_refresh_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_analytics_refresh_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_notification_analytics_refresh_run_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics refresh schedules"
ON public.order_lifecycle_notification_analytics_refresh_schedules;

CREATE POLICY "Service role can manage order lifecycle analytics refresh schedules"
ON public.order_lifecycle_notification_analytics_refresh_schedules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics refresh runs"
ON public.order_lifecycle_notification_analytics_refresh_runs;

CREATE POLICY "Service role can manage order lifecycle analytics refresh runs"
ON public.order_lifecycle_notification_analytics_refresh_runs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics refresh run steps"
ON public.order_lifecycle_notification_analytics_refresh_run_steps;

CREATE POLICY "Service role can manage order lifecycle analytics refresh run steps"
ON public.order_lifecycle_notification_analytics_refresh_run_steps
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 15. Migration Registry Marker
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
    112,
    'migration_112_order_lifecycle_notification_analytics_scheduled_refresh',
    'Adds scheduled refresh control, refresh run tracking, refresh step logging, due-schedule execution functions, and dashboard views for notification analytics.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
