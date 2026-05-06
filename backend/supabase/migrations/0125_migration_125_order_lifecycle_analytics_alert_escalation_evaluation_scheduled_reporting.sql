-- Migration 125: Order Lifecycle Analytics Alert Escalation Evaluation Scheduled Reporting
-- Purpose:
-- Adds scheduled reporting control, scheduled report run tracking,
-- step logging, due-schedule execution functions, and dashboard views
-- for analytics alert escalation evaluation reports.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Escalation Evaluation Report Schedules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_report_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_code TEXT NOT NULL UNIQUE,
    schedule_name TEXT NOT NULL,
    schedule_description TEXT,

    report_code TEXT NOT NULL REFERENCES public.oiaa_escalation_evaluation_report_definitions(report_code),

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    frequency_minutes INTEGER NOT NULL DEFAULT 1440,
    lookback_days INTEGER NOT NULL DEFAULT 30,

    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    schedule_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    delivery_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_report_schedules_timing
    CHECK (
        frequency_minutes > 0
        AND lookback_days >= 0
    )
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_report_schedules IS
'Stores scheduled reporting settings for analytics alert escalation evaluation reports.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_schedules_code
ON public.oiaa_escalation_evaluation_report_schedules(schedule_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_schedules_report_code
ON public.oiaa_escalation_evaluation_report_schedules(report_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_schedules_enabled
ON public.oiaa_escalation_evaluation_report_schedules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_schedules_next_run
ON public.oiaa_escalation_evaluation_report_schedules(next_run_at);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_schedules_config
ON public.oiaa_escalation_evaluation_report_schedules USING GIN(schedule_config);

-- ============================================================
-- 2. Default Scheduled Reports
-- ============================================================

INSERT INTO public.oiaa_escalation_evaluation_report_schedules (
    schedule_code,
    schedule_name,
    schedule_description,
    report_code,
    is_enabled,
    frequency_minutes,
    lookback_days,
    next_run_at,
    schedule_config,
    delivery_config
)
VALUES
(
    'DAILY_OIAA_ESCALATION_EVALUATION_HEALTH_REPORT_SCHEDULE',
    'Daily Analytics Alert Escalation Evaluation Health Report Schedule',
    'Generates the escalation evaluation health report every day.',
    'OIAA_ESCALATION_EVALUATION_HEALTH_REPORT',
    TRUE,
    1440,
    7,
    NOW(),
    jsonb_build_object(
        'created_by', 'migration_125',
        'recommended_for', 'daily_admin_health_review'
    ),
    jsonb_build_object(
        'delivery_mode', 'admin_dashboard',
        'created_by', 'migration_125'
    )
),
(
    'DAILY_OIAA_ESCALATION_EVALUATION_REPORT_SCHEDULE',
    'Daily Analytics Alert Escalation Evaluation Report Schedule',
    'Generates the daily escalation evaluation report every day.',
    'DAILY_OIAA_ESCALATION_EVALUATION_REPORT',
    TRUE,
    1440,
    30,
    NOW() + INTERVAL '1 hour',
    jsonb_build_object(
        'created_by', 'migration_125',
        'recommended_for', 'operations_review'
    ),
    jsonb_build_object(
        'delivery_mode', 'manual_download',
        'created_by', 'migration_125'
    )
),
(
    'WEEKLY_OIAA_ESCALATION_EVALUATION_REPORT_SCHEDULE',
    'Weekly Analytics Alert Escalation Evaluation Report Schedule',
    'Generates the weekly escalation evaluation report every 7 days.',
    'WEEKLY_OIAA_ESCALATION_EVALUATION_REPORT',
    TRUE,
    10080,
    90,
    NOW() + INTERVAL '1 day',
    jsonb_build_object(
        'created_by', 'migration_125',
        'recommended_for', 'weekly_operations_review'
    ),
    jsonb_build_object(
        'delivery_mode', 'manual_download',
        'created_by', 'migration_125'
    )
)
ON CONFLICT (schedule_code) DO UPDATE
SET
    schedule_name = EXCLUDED.schedule_name,
    schedule_description = EXCLUDED.schedule_description,
    report_code = EXCLUDED.report_code,
    is_enabled = EXCLUDED.is_enabled,
    frequency_minutes = EXCLUDED.frequency_minutes,
    lookback_days = EXCLUDED.lookback_days,
    schedule_config = EXCLUDED.schedule_config,
    delivery_config = EXCLUDED.delivery_config,
    updated_at = NOW();

-- ============================================================
-- 3. Scheduled Report Runs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_scheduled_report_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_id UUID REFERENCES public.oiaa_escalation_evaluation_report_schedules(id) ON DELETE SET NULL,
    schedule_code TEXT,

    report_code TEXT NOT NULL,
    generated_report_run_id UUID REFERENCES public.oiaa_escalation_evaluation_report_runs(id) ON DELETE SET NULL,

    run_status TEXT NOT NULL DEFAULT 'created',

    from_date DATE,
    to_date DATE,

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    error_message TEXT,

    result_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_scheduled_report_runs_status
    CHECK (
        run_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'cancelled',
            'skipped'
        )
    )
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_scheduled_report_runs IS
'Stores scheduled report execution history for analytics alert escalation evaluation reports.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_schedule
ON public.oiaa_escalation_evaluation_scheduled_report_runs(schedule_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_code
ON public.oiaa_escalation_evaluation_scheduled_report_runs(schedule_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_report_code
ON public.oiaa_escalation_evaluation_scheduled_report_runs(report_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_status
ON public.oiaa_escalation_evaluation_scheduled_report_runs(run_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_created
ON public.oiaa_escalation_evaluation_scheduled_report_runs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_runs_payload
ON public.oiaa_escalation_evaluation_scheduled_report_runs USING GIN(result_payload);

-- ============================================================
-- 4. Scheduled Report Run Steps
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_scheduled_report_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    scheduled_report_run_id UUID NOT NULL REFERENCES public.oiaa_escalation_evaluation_scheduled_report_runs(id) ON DELETE CASCADE,

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

    CONSTRAINT chk_oiaa_eval_scheduled_report_steps_status
    CHECK (
        step_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'skipped'
        )
    ),

    CONSTRAINT chk_oiaa_eval_scheduled_report_steps_rows
    CHECK (affected_rows >= 0)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_scheduled_report_steps IS
'Stores step-level logs for scheduled analytics alert escalation evaluation report generation.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_steps_run
ON public.oiaa_escalation_evaluation_scheduled_report_steps(scheduled_report_run_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_steps_code
ON public.oiaa_escalation_evaluation_scheduled_report_steps(step_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_steps_status
ON public.oiaa_escalation_evaluation_scheduled_report_steps(step_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_scheduled_report_steps_payload
ON public.oiaa_escalation_evaluation_scheduled_report_steps USING GIN(step_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_scheduled_reporting_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_eval_report_schedules_updated_at
ON public.oiaa_escalation_evaluation_report_schedules;

CREATE TRIGGER trg_oiaa_eval_report_schedules_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_report_schedules
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_scheduled_reporting_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_eval_scheduled_report_runs_updated_at
ON public.oiaa_escalation_evaluation_scheduled_report_runs;

CREATE TRIGGER trg_oiaa_eval_scheduled_report_runs_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_scheduled_report_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_scheduled_reporting_updated_at();

-- ============================================================
-- 6. Record Scheduled Report Step Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_oiaa_scheduled_report_step(
    p_scheduled_report_run_id UUID,
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
    IF p_scheduled_report_run_id IS NULL
       OR p_step_code IS NULL
       OR p_step_name IS NULL
       OR p_step_status IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.oiaa_escalation_evaluation_scheduled_report_steps (
        scheduled_report_run_id,
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
        p_scheduled_report_run_id,
        p_step_code,
        p_step_name,
        p_step_status,
        COALESCE(p_affected_rows, 0),
        CASE WHEN p_step_status = 'running' THEN NOW() ELSE NULL END,
        CASE WHEN p_step_status = 'completed' THEN NOW() ELSE NULL END,
        CASE WHEN p_step_status = 'failed' THEN NOW() ELSE NULL END,
        p_error_message,
        COALESCE(p_step_payload, '{}'::jsonb),
        NOW()
    )
    RETURNING id INTO v_step_id;

    RETURN v_step_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Run One Scheduled Report
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_oiaa_escalation_evaluation_report_schedule(
    p_schedule_code TEXT
)
RETURNS UUID AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;
    v_generated_report_run_id UUID;

    v_from_date DATE;
    v_to_date DATE;

    v_result_payload JSONB := '{}'::jsonb;
BEGIN
    IF p_schedule_code IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_schedule
    FROM public.oiaa_escalation_evaluation_report_schedules
    WHERE schedule_code = p_schedule_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_to_date := CURRENT_DATE;
    v_from_date := CURRENT_DATE - COALESCE(v_schedule.lookback_days, 30);

    IF v_schedule.is_enabled = FALSE THEN
        INSERT INTO public.oiaa_escalation_evaluation_scheduled_report_runs (
            schedule_id,
            schedule_code,
            report_code,
            run_status,
            from_date,
            to_date,
            result_payload,
            created_at,
            updated_at
        )
        VALUES (
            v_schedule.id,
            v_schedule.schedule_code,
            v_schedule.report_code,
            'skipped',
            v_from_date,
            v_to_date,
            jsonb_build_object(
                'reason', 'schedule_disabled',
                'schedule_code', v_schedule.schedule_code,
                'report_code', v_schedule.report_code,
                'generated_by', 'migration_125'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_run_id;

        RETURN v_run_id;
    END IF;

    INSERT INTO public.oiaa_escalation_evaluation_scheduled_report_runs (
        schedule_id,
        schedule_code,
        report_code,
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
        v_schedule.report_code,
        'running',
        v_from_date,
        v_to_date,
        NOW(),
        jsonb_build_object(
            'schedule_code', v_schedule.schedule_code,
            'report_code', v_schedule.report_code,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'generated_by', 'migration_125'
        ),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_run_id;

    BEGIN
        PERFORM public.record_oiaa_scheduled_report_step(
            v_run_id,
            'generate_report',
            'Generate Analytics Alert Escalation Evaluation Report',
            'running',
            0,
            NULL,
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'report_code', v_schedule.report_code,
                'from_date', v_from_date,
                'to_date', v_to_date
            )
        );

        v_generated_report_run_id := public.generate_oiaa_escalation_evaluation_report(
            v_schedule.report_code,
            v_from_date,
            v_to_date
        );

        PERFORM public.record_oiaa_scheduled_report_step(
            v_run_id,
            'generate_report',
            'Generate Analytics Alert Escalation Evaluation Report',
            'completed',
            CASE WHEN v_generated_report_run_id IS NULL THEN 0 ELSE 1 END,
            NULL,
            jsonb_build_object(
                'generated_report_run_id', v_generated_report_run_id,
                'report_code', v_schedule.report_code
            )
        );

        v_result_payload := jsonb_build_object(
            'schedule_code', v_schedule.schedule_code,
            'report_code', v_schedule.report_code,
            'generated_report_run_id', v_generated_report_run_id,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'delivery_config', v_schedule.delivery_config,
            'generated_by', 'migration_125'
        );

        UPDATE public.oiaa_escalation_evaluation_scheduled_report_runs
        SET
            run_status = CASE
                WHEN v_generated_report_run_id IS NULL THEN 'failed'
                ELSE 'completed'
            END,
            completed_at = CASE
                WHEN v_generated_report_run_id IS NOT NULL THEN NOW()
                ELSE completed_at
            END,
            failed_at = CASE
                WHEN v_generated_report_run_id IS NULL THEN NOW()
                ELSE failed_at
            END,
            error_message = CASE
                WHEN v_generated_report_run_id IS NULL THEN 'Report generation returned NULL.'
                ELSE error_message
            END,
            generated_report_run_id = v_generated_report_run_id,
            result_payload = v_result_payload,
            updated_at = NOW()
        WHERE id = v_run_id;

        UPDATE public.oiaa_escalation_evaluation_report_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'oiaa_escalation_evaluation_scheduled_report_completed',
            CASE WHEN v_generated_report_run_id IS NULL THEN 'failed' ELSE 'completed' END,
            v_result_payload,
            NOW()
        );

    EXCEPTION WHEN OTHERS THEN
        UPDATE public.oiaa_escalation_evaluation_scheduled_report_runs
        SET
            run_status = 'failed',
            failed_at = NOW(),
            error_message = SQLERRM,
            result_payload = jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'report_code', v_schedule.report_code,
                'error_message', SQLERRM,
                'generated_by', 'migration_125'
            ),
            updated_at = NOW()
        WHERE id = v_run_id;

        PERFORM public.record_oiaa_scheduled_report_step(
            v_run_id,
            'generate_report',
            'Generate Analytics Alert Escalation Evaluation Report',
            'failed',
            0,
            SQLERRM,
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'report_code', v_schedule.report_code
            )
        );

        UPDATE public.oiaa_escalation_evaluation_report_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'oiaa_escalation_evaluation_scheduled_report_failed',
            'failed',
            jsonb_build_object(
                'scheduled_report_run_id', v_run_id,
                'schedule_code', v_schedule.schedule_code,
                'report_code', v_schedule.report_code,
                'error_message', SQLERRM,
                'generated_by', 'migration_125'
            ),
            NOW()
        );
    END;

    RETURN v_run_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Run Due Scheduled Reports
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_due_oiaa_escalation_evaluation_report_schedules()
RETURNS JSONB AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;
    v_run_count INTEGER := 0;
    v_run_ids JSONB := '[]'::jsonb;
BEGIN
    FOR v_schedule IN
        SELECT *
        FROM public.oiaa_escalation_evaluation_report_schedules
        WHERE is_enabled = TRUE
        AND next_run_at <= NOW()
        ORDER BY next_run_at ASC, created_at ASC
    LOOP
        v_run_id := public.run_oiaa_escalation_evaluation_report_schedule(
            v_schedule.schedule_code
        );

        IF v_run_id IS NOT NULL THEN
            v_run_count := v_run_count + 1;
            v_run_ids := v_run_ids || jsonb_build_array(v_run_id);
        END IF;
    END LOOP;

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'run_due_oiaa_escalation_evaluation_report_schedules',
        'completed',
        jsonb_build_object(
            'run_count', v_run_count,
            'run_ids', v_run_ids,
            'generated_by', 'migration_125'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'run_count', v_run_count,
        'run_ids', v_run_ids,
        'generated_by', 'migration_125'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Enable / Reschedule Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_evaluation_report_schedule_enabled(
    p_schedule_code TEXT,
    p_is_enabled BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_is_enabled IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.oiaa_escalation_evaluation_report_schedules
    SET
        is_enabled = p_is_enabled,
        updated_at = NOW()
    WHERE schedule_code = p_schedule_code;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.reschedule_oiaa_escalation_evaluation_report_schedule(
    p_schedule_code TEXT,
    p_next_run_at TIMESTAMPTZ
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_next_run_at IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.oiaa_escalation_evaluation_report_schedules
    SET
        next_run_at = p_next_run_at,
        updated_at = NOW()
    WHERE schedule_code = p_schedule_code;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_report_schedule_dashboard_view AS
SELECT
    s.id,
    s.schedule_code,
    s.schedule_name,
    s.schedule_description,
    s.report_code,
    d.report_name,
    d.report_scope,
    d.output_format,
    s.is_enabled,
    s.frequency_minutes,
    s.lookback_days,
    s.last_run_at,
    s.next_run_at,

    CASE
        WHEN s.is_enabled = FALSE THEN 'disabled'
        WHEN s.next_run_at <= NOW() THEN 'due_now'
        WHEN s.next_run_at <= NOW() + INTERVAL '1 hour' THEN 'due_soon'
        ELSE 'scheduled'
    END AS schedule_dashboard_status,

    latest_run.id AS latest_scheduled_report_run_id,
    latest_run.run_status AS latest_scheduled_report_status,
    latest_run.started_at AS latest_started_at,
    latest_run.completed_at AS latest_completed_at,
    latest_run.failed_at AS latest_failed_at,
    latest_run.error_message AS latest_error_message,

    latest_report.report_status AS latest_generated_report_status,
    latest_report.total_sections AS latest_generated_report_sections,
    latest_report.total_export_records AS latest_generated_report_exports,

    s.schedule_config,
    s.delivery_config,
    s.created_at,
    s.updated_at
FROM public.oiaa_escalation_evaluation_report_schedules s
LEFT JOIN public.oiaa_escalation_evaluation_report_definitions d
ON d.report_code = s.report_code
LEFT JOIN LATERAL (
    SELECT r.*
    FROM public.oiaa_escalation_evaluation_scheduled_report_runs r
    WHERE r.schedule_id = s.id
    ORDER BY r.created_at DESC
    LIMIT 1
) latest_run ON TRUE
LEFT JOIN public.oiaa_escalation_evaluation_report_runs latest_report
ON latest_report.id = latest_run.generated_report_run_id;

COMMENT ON VIEW public.oiaa_escalation_evaluation_report_schedule_dashboard_view IS
'Admin dashboard view for scheduled escalation evaluation report settings and latest execution status.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_scheduled_report_run_dashboard_view AS
SELECT
    r.id AS scheduled_report_run_id,
    r.schedule_id,
    r.schedule_code,
    r.report_code,
    r.generated_report_run_id,
    r.run_status,
    r.from_date,
    r.to_date,
    r.started_at,
    r.completed_at,
    r.failed_at,
    r.error_message,

    generated.report_status AS generated_report_status,
    generated.total_sections AS generated_report_sections,
    generated.total_export_records AS generated_report_exports,

    COUNT(st.id)::INTEGER AS step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'completed')::INTEGER AS completed_step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'failed')::INTEGER AS failed_step_count,

    CASE
        WHEN r.run_status = 'failed' THEN 'attention_required'
        WHEN COUNT(st.id) FILTER (WHERE st.step_status = 'failed') > 0 THEN 'step_failure'
        WHEN generated.report_status = 'failed' THEN 'generated_report_failure'
        WHEN r.run_status = 'running' THEN 'running'
        WHEN r.run_status = 'completed' THEN 'completed'
        WHEN r.run_status = 'skipped' THEN 'skipped'
        ELSE 'created'
    END AS scheduled_report_run_dashboard_status,

    r.result_payload,
    r.created_at,
    r.updated_at
FROM public.oiaa_escalation_evaluation_scheduled_report_runs r
LEFT JOIN public.oiaa_escalation_evaluation_scheduled_report_steps st
ON st.scheduled_report_run_id = r.id
LEFT JOIN public.oiaa_escalation_evaluation_report_runs generated
ON generated.id = r.generated_report_run_id
GROUP BY
    r.id,
    r.schedule_id,
    r.schedule_code,
    r.report_code,
    r.generated_report_run_id,
    r.run_status,
    r.from_date,
    r.to_date,
    r.started_at,
    r.completed_at,
    r.failed_at,
    r.error_message,
    generated.report_status,
    generated.total_sections,
    generated.total_export_records,
    r.result_payload,
    r.created_at,
    r.updated_at;

COMMENT ON VIEW public.oiaa_escalation_evaluation_scheduled_report_run_dashboard_view IS
'Admin dashboard view for scheduled escalation evaluation report run history and step summary.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_scheduled_reporting_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE)::INTEGER AS enabled_schedules,
    COUNT(*) FILTER (WHERE is_enabled = FALSE)::INTEGER AS disabled_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at <= NOW())::INTEGER AS due_schedules,
    COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at > NOW())::INTEGER AS future_schedules,
    MIN(next_run_at) FILTER (WHERE is_enabled = TRUE) AS next_due_at,
    MAX(last_run_at) AS latest_run_at,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.oiaa_escalation_evaluation_scheduled_report_runs
        WHERE run_status = 'failed'
    ) AS failed_scheduled_report_runs,

    CASE
        WHEN COUNT(*) = 0 THEN 'not_configured'
        WHEN (
            SELECT COUNT(*)
            FROM public.oiaa_escalation_evaluation_scheduled_report_runs
            WHERE run_status = 'failed'
        ) > 0 THEN 'failure_attention'
        WHEN COUNT(*) FILTER (WHERE is_enabled = TRUE AND next_run_at <= NOW()) > 0 THEN 'due'
        WHEN MAX(last_run_at) IS NULL THEN 'not_started'
        WHEN MAX(last_run_at) < NOW() - INTERVAL '7 days' THEN 'stale'
        ELSE 'healthy'
    END AS scheduled_reporting_health_status
FROM public.oiaa_escalation_evaluation_report_schedules;

COMMENT ON VIEW public.oiaa_escalation_evaluation_scheduled_reporting_health_view IS
'Shows overall health status for scheduled analytics alert escalation evaluation reporting.';

-- ============================================================
-- 11. Initial Due Scheduled Report Run
-- ============================================================

SELECT public.run_due_oiaa_escalation_evaluation_report_schedules();

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.oiaa_escalation_evaluation_report_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_scheduled_report_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_scheduled_report_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_report_schedules"
ON public.oiaa_escalation_evaluation_report_schedules;

CREATE POLICY "svc_manage_oiaa_eval_report_schedules"
ON public.oiaa_escalation_evaluation_report_schedules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_scheduled_report_runs"
ON public.oiaa_escalation_evaluation_scheduled_report_runs;

CREATE POLICY "svc_manage_oiaa_eval_scheduled_report_runs"
ON public.oiaa_escalation_evaluation_scheduled_report_runs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_scheduled_report_steps"
ON public.oiaa_escalation_evaluation_scheduled_report_steps;

CREATE POLICY "svc_manage_oiaa_eval_scheduled_report_steps"
ON public.oiaa_escalation_evaluation_scheduled_report_steps
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
    125,
    'migration_125_order_lifecycle_analytics_alert_escalation_evaluation_scheduled_reporting',
    'Adds scheduled reporting control, scheduled report run tracking, step logging, due-schedule execution functions, and dashboard views for analytics alert escalation evaluation reports.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
