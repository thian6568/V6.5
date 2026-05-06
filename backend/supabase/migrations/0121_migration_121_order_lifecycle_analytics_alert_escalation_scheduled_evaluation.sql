-- Migration 121: Order Lifecycle Analytics Alert Escalation Scheduled Evaluation
-- Purpose:
-- Adds scheduled escalation evaluation control, evaluation run tracking,
-- step logging, due-schedule execution functions, and dashboard views
-- for analytics alert escalation evaluation.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Escalation Evaluation Schedules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_code TEXT NOT NULL UNIQUE,
    schedule_name TEXT NOT NULL,
    schedule_description TEXT,

    evaluation_scope TEXT NOT NULL DEFAULT 'all',

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    frequency_minutes INTEGER NOT NULL DEFAULT 15,

    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    schedule_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_escalation_eval_schedules_scope
    CHECK (
        evaluation_scope IN (
            'all',
            'active_escalations',
            'critical_only'
        )
    ),

    CONSTRAINT chk_oiaa_escalation_eval_schedules_frequency
    CHECK (frequency_minutes > 0)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_schedules IS
'Stores scheduled evaluation settings for analytics alert escalation policies and queue.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedules_code
ON public.oiaa_escalation_evaluation_schedules(schedule_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedules_enabled
ON public.oiaa_escalation_evaluation_schedules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedules_next_run
ON public.oiaa_escalation_evaluation_schedules(next_run_at);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_schedules_config
ON public.oiaa_escalation_evaluation_schedules USING GIN(schedule_config);

-- ============================================================
-- 2. Default Escalation Evaluation Schedules
-- ============================================================

INSERT INTO public.oiaa_escalation_evaluation_schedules (
    schedule_code,
    schedule_name,
    schedule_description,
    evaluation_scope,
    is_enabled,
    frequency_minutes,
    next_run_at,
    schedule_config
)
VALUES
(
    'FIFTEEN_MINUTE_OIAA_ESCALATION_EVALUATION',
    '15-Minute Analytics Alert Escalation Evaluation',
    'Evaluates analytics alert escalation queue every 15 minutes.',
    'all',
    TRUE,
    15,
    NOW(),
    jsonb_build_object(
        'created_by', 'migration_121',
        'recommended_for', 'escalation_monitoring'
    )
),
(
    'FIVE_MINUTE_CRITICAL_OIAA_ESCALATION_EVALUATION',
    '5-Minute Critical Analytics Alert Escalation Evaluation',
    'Evaluates critical analytics alert escalation conditions every 5 minutes.',
    'critical_only',
    TRUE,
    5,
    NOW(),
    jsonb_build_object(
        'created_by', 'migration_121',
        'recommended_for', 'critical_alert_monitoring'
    )
)
ON CONFLICT (schedule_code) DO UPDATE
SET
    schedule_name = EXCLUDED.schedule_name,
    schedule_description = EXCLUDED.schedule_description,
    evaluation_scope = EXCLUDED.evaluation_scope,
    is_enabled = EXCLUDED.is_enabled,
    frequency_minutes = EXCLUDED.frequency_minutes,
    schedule_config = EXCLUDED.schedule_config,
    updated_at = NOW();

-- ============================================================
-- 3. Escalation Evaluation Runs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    schedule_id UUID REFERENCES public.oiaa_escalation_evaluation_schedules(id) ON DELETE SET NULL,
    schedule_code TEXT,

    evaluation_scope TEXT NOT NULL DEFAULT 'all',
    run_status TEXT NOT NULL DEFAULT 'created',

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    created_count INTEGER NOT NULL DEFAULT 0,
    due_count INTEGER NOT NULL DEFAULT 0,
    notified_count INTEGER NOT NULL DEFAULT 0,
    resolved_count INTEGER NOT NULL DEFAULT 0,

    error_message TEXT,

    result_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_escalation_eval_runs_scope
    CHECK (
        evaluation_scope IN (
            'all',
            'active_escalations',
            'critical_only'
        )
    ),

    CONSTRAINT chk_oiaa_escalation_eval_runs_status
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

    CONSTRAINT chk_oiaa_escalation_eval_runs_counts
    CHECK (
        created_count >= 0
        AND due_count >= 0
        AND notified_count >= 0
        AND resolved_count >= 0
    )
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_runs IS
'Stores execution history for scheduled analytics alert escalation evaluations.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_schedule
ON public.oiaa_escalation_evaluation_runs(schedule_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_code
ON public.oiaa_escalation_evaluation_runs(schedule_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_status
ON public.oiaa_escalation_evaluation_runs(run_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_scope
ON public.oiaa_escalation_evaluation_runs(evaluation_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_created
ON public.oiaa_escalation_evaluation_runs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_runs_payload
ON public.oiaa_escalation_evaluation_runs USING GIN(result_payload);

-- ============================================================
-- 4. Escalation Evaluation Run Steps
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_run_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    evaluation_run_id UUID NOT NULL REFERENCES public.oiaa_escalation_evaluation_runs(id) ON DELETE CASCADE,

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

    CONSTRAINT chk_oiaa_escalation_eval_steps_status
    CHECK (
        step_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'skipped'
        )
    ),

    CONSTRAINT chk_oiaa_escalation_eval_steps_rows
    CHECK (affected_rows >= 0)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_run_steps IS
'Stores detailed step-level logs for analytics alert escalation evaluation execution.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_steps_run
ON public.oiaa_escalation_evaluation_run_steps(evaluation_run_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_steps_code
ON public.oiaa_escalation_evaluation_run_steps(step_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_steps_status
ON public.oiaa_escalation_evaluation_run_steps(step_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_eval_steps_payload
ON public.oiaa_escalation_evaluation_run_steps USING GIN(step_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_evaluation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_escalation_eval_schedules_updated_at
ON public.oiaa_escalation_evaluation_schedules;

CREATE TRIGGER trg_oiaa_escalation_eval_schedules_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_schedules
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_escalation_eval_runs_updated_at
ON public.oiaa_escalation_evaluation_runs;

CREATE TRIGGER trg_oiaa_escalation_eval_runs_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_updated_at();

-- ============================================================
-- 6. Record Evaluation Step Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_oiaa_escalation_evaluation_step(
    p_evaluation_run_id UUID,
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
    IF p_evaluation_run_id IS NULL
       OR p_step_code IS NULL
       OR p_step_name IS NULL
       OR p_step_status IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.oiaa_escalation_evaluation_run_steps (
        evaluation_run_id,
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
        p_evaluation_run_id,
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
-- 7. Run One Evaluation Schedule
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_oiaa_escalation_evaluation_schedule(
    p_schedule_code TEXT
)
RETURNS UUID AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;
    v_result JSONB := '{}'::jsonb;

    v_created_count INTEGER := 0;
    v_due_count INTEGER := 0;
    v_notified_count INTEGER := 0;
    v_resolved_count INTEGER := 0;
BEGIN
    IF p_schedule_code IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_schedule
    FROM public.oiaa_escalation_evaluation_schedules
    WHERE schedule_code = p_schedule_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_schedule.is_enabled = FALSE THEN
        INSERT INTO public.oiaa_escalation_evaluation_runs (
            schedule_id,
            schedule_code,
            evaluation_scope,
            run_status,
            result_payload,
            created_at,
            updated_at
        )
        VALUES (
            v_schedule.id,
            v_schedule.schedule_code,
            v_schedule.evaluation_scope,
            'skipped',
            jsonb_build_object(
                'reason', 'schedule_disabled',
                'schedule_code', v_schedule.schedule_code,
                'generated_by', 'migration_121'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_run_id;

        RETURN v_run_id;
    END IF;

    INSERT INTO public.oiaa_escalation_evaluation_runs (
        schedule_id,
        schedule_code,
        evaluation_scope,
        run_status,
        started_at,
        result_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_schedule.id,
        v_schedule.schedule_code,
        v_schedule.evaluation_scope,
        'running',
        NOW(),
        jsonb_build_object(
            'schedule_code', v_schedule.schedule_code,
            'evaluation_scope', v_schedule.evaluation_scope,
            'generated_by', 'migration_121'
        ),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_run_id;

    BEGIN
        PERFORM public.record_oiaa_escalation_evaluation_step(
            v_run_id,
            'evaluate_escalations',
            'Evaluate Analytics Alert Escalations',
            'running',
            0,
            NULL,
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'evaluation_scope', v_schedule.evaluation_scope
            )
        );

        v_result := public.evaluate_oiaa_escalations();

        v_created_count := COALESCE((v_result ->> 'created_count')::INTEGER, 0);
        v_due_count := COALESCE((v_result ->> 'due_count')::INTEGER, 0);
        v_notified_count := COALESCE((v_result ->> 'notified_count')::INTEGER, 0);
        v_resolved_count := COALESCE((v_result ->> 'resolved_count')::INTEGER, 0);

        PERFORM public.record_oiaa_escalation_evaluation_step(
            v_run_id,
            'evaluate_escalations',
            'Evaluate Analytics Alert Escalations',
            'completed',
            v_created_count + v_due_count + v_notified_count + v_resolved_count,
            NULL,
            v_result
        );

        UPDATE public.oiaa_escalation_evaluation_runs
        SET
            run_status = 'completed',
            completed_at = NOW(),
            created_count = v_created_count,
            due_count = v_due_count,
            notified_count = v_notified_count,
            resolved_count = v_resolved_count,
            result_payload = v_result || jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'evaluation_scope', v_schedule.evaluation_scope,
                'generated_by', 'migration_121'
            ),
            updated_at = NOW()
        WHERE id = v_run_id;

        UPDATE public.oiaa_escalation_evaluation_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'oiaa_escalation_scheduled_evaluation_completed',
            'completed',
            jsonb_build_object(
                'evaluation_run_id', v_run_id,
                'schedule_code', v_schedule.schedule_code,
                'created_count', v_created_count,
                'due_count', v_due_count,
                'notified_count', v_notified_count,
                'resolved_count', v_resolved_count,
                'generated_by', 'migration_121'
            ),
            NOW()
        );

    EXCEPTION WHEN OTHERS THEN
        UPDATE public.oiaa_escalation_evaluation_runs
        SET
            run_status = 'failed',
            failed_at = NOW(),
            error_message = SQLERRM,
            result_payload = jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'evaluation_scope', v_schedule.evaluation_scope,
                'error_message', SQLERRM,
                'generated_by', 'migration_121'
            ),
            updated_at = NOW()
        WHERE id = v_run_id;

        PERFORM public.record_oiaa_escalation_evaluation_step(
            v_run_id,
            'evaluate_escalations',
            'Evaluate Analytics Alert Escalations',
            'failed',
            0,
            SQLERRM,
            jsonb_build_object(
                'schedule_code', v_schedule.schedule_code,
                'evaluation_scope', v_schedule.evaluation_scope
            )
        );

        UPDATE public.oiaa_escalation_evaluation_schedules
        SET
            last_run_at = NOW(),
            next_run_at = NOW() + make_interval(mins => frequency_minutes),
            updated_at = NOW()
        WHERE id = v_schedule.id;

        INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'oiaa_escalation_scheduled_evaluation_failed',
            'failed',
            jsonb_build_object(
                'evaluation_run_id', v_run_id,
                'schedule_code', v_schedule.schedule_code,
                'error_message', SQLERRM,
                'generated_by', 'migration_121'
            ),
            NOW()
        );
    END;

    RETURN v_run_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Run Due Evaluation Schedules
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_due_oiaa_escalation_evaluation_schedules()
RETURNS JSONB AS $$
DECLARE
    v_schedule RECORD;
    v_run_id UUID;
    v_run_count INTEGER := 0;
    v_run_ids JSONB := '[]'::jsonb;
BEGIN
    FOR v_schedule IN
        SELECT *
        FROM public.oiaa_escalation_evaluation_schedules
        WHERE is_enabled = TRUE
        AND next_run_at <= NOW()
        ORDER BY next_run_at ASC, created_at ASC
    LOOP
        v_run_id := public.run_oiaa_escalation_evaluation_schedule(
            v_schedule.schedule_code
        );

        IF v_run_id IS NOT NULL THEN
            v_run_count := v_run_count + 1;
            v_run_ids := v_run_ids || jsonb_build_array(v_run_id);
        END IF;
    END LOOP;

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'run_due_oiaa_escalation_evaluation_schedules',
        'completed',
        jsonb_build_object(
            'run_count', v_run_count,
            'run_ids', v_run_ids,
            'generated_by', 'migration_121'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'run_count', v_run_count,
        'run_ids', v_run_ids,
        'generated_by', 'migration_121'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Enable / Reschedule Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_evaluation_schedule_enabled(
    p_schedule_code TEXT,
    p_is_enabled BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_is_enabled IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.oiaa_escalation_evaluation_schedules
    SET
        is_enabled = p_is_enabled,
        updated_at = NOW()
    WHERE schedule_code = p_schedule_code;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.reschedule_oiaa_escalation_evaluation_schedule(
    p_schedule_code TEXT,
    p_next_run_at TIMESTAMPTZ
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_schedule_code IS NULL OR p_next_run_at IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.oiaa_escalation_evaluation_schedules
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

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_schedule_dashboard_view AS
SELECT
    s.id,
    s.schedule_code,
    s.schedule_name,
    s.schedule_description,
    s.evaluation_scope,
    s.is_enabled,
    s.frequency_minutes,
    s.last_run_at,
    s.next_run_at,

    CASE
        WHEN s.is_enabled = FALSE THEN 'disabled'
        WHEN s.next_run_at <= NOW() THEN 'due_now'
        WHEN s.next_run_at <= NOW() + INTERVAL '5 minutes' THEN 'due_soon'
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
FROM public.oiaa_escalation_evaluation_schedules s
LEFT JOIN LATERAL (
    SELECT r.*
    FROM public.oiaa_escalation_evaluation_runs r
    WHERE r.schedule_id = s.id
    ORDER BY r.created_at DESC
    LIMIT 1
) latest_run ON TRUE;

COMMENT ON VIEW public.oiaa_escalation_evaluation_schedule_dashboard_view IS
'Admin dashboard view for analytics alert escalation evaluation schedules and latest run status.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_run_dashboard_view AS
SELECT
    r.id AS evaluation_run_id,
    r.schedule_id,
    r.schedule_code,
    r.evaluation_scope,
    r.run_status,
    r.started_at,
    r.completed_at,
    r.failed_at,

    r.created_count,
    r.due_count,
    r.notified_count,
    r.resolved_count,

    r.error_message,

    COUNT(st.id)::INTEGER AS step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'completed')::INTEGER AS completed_step_count,
    COUNT(st.id) FILTER (WHERE st.step_status = 'failed')::INTEGER AS failed_step_count,

    CASE
        WHEN r.run_status = 'failed' THEN 'attention_required'
        WHEN COUNT(st.id) FILTER (WHERE st.step_status = 'failed') > 0 THEN 'step_failure'
        WHEN r.run_status = 'running' THEN 'running'
        WHEN r.run_status = 'completed' AND r.notified_count > 0 THEN 'notifications_created'
        WHEN r.run_status = 'completed' THEN 'completed'
        WHEN r.run_status = 'skipped' THEN 'skipped'
        ELSE 'created'
    END AS evaluation_run_dashboard_status,

    r.result_payload,
    r.created_at,
    r.updated_at
FROM public.oiaa_escalation_evaluation_runs r
LEFT JOIN public.oiaa_escalation_evaluation_run_steps st
ON st.evaluation_run_id = r.id
GROUP BY
    r.id,
    r.schedule_id,
    r.schedule_code,
    r.evaluation_scope,
    r.run_status,
    r.started_at,
    r.completed_at,
    r.failed_at,
    r.created_count,
    r.due_count,
    r.notified_count,
    r.resolved_count,
    r.error_message,
    r.result_payload,
    r.created_at,
    r.updated_at;

COMMENT ON VIEW public.oiaa_escalation_evaluation_run_dashboard_view IS
'Admin dashboard view for analytics alert escalation evaluation run history and step summary.';

CREATE OR REPLACE VIEW public.oiaa_escalation_scheduled_evaluation_health_view AS
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
        WHEN MAX(last_run_at) < NOW() - INTERVAL '1 hour' THEN 'stale'
        ELSE 'healthy'
    END AS scheduled_evaluation_health_status
FROM public.oiaa_escalation_evaluation_schedules;

COMMENT ON VIEW public.oiaa_escalation_scheduled_evaluation_health_view IS
'Shows overall health status for scheduled analytics alert escalation evaluation control.';

-- ============================================================
-- 11. Initial Due Evaluation Run
-- ============================================================

SELECT public.run_due_oiaa_escalation_evaluation_schedules();

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.oiaa_escalation_evaluation_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_run_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_evaluation_schedules"
ON public.oiaa_escalation_evaluation_schedules;

CREATE POLICY "svc_manage_oiaa_escalation_evaluation_schedules"
ON public.oiaa_escalation_evaluation_schedules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_evaluation_runs"
ON public.oiaa_escalation_evaluation_runs;

CREATE POLICY "svc_manage_oiaa_escalation_evaluation_runs"
ON public.oiaa_escalation_evaluation_runs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_evaluation_steps"
ON public.oiaa_escalation_evaluation_run_steps;

CREATE POLICY "svc_manage_oiaa_escalation_evaluation_steps"
ON public.oiaa_escalation_evaluation_run_steps
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
    121,
    'migration_121_order_lifecycle_analytics_alert_escalation_scheduled_evaluation',
    'Adds scheduled escalation evaluation control, evaluation run tracking, step logging, due-schedule execution functions, and dashboard views for analytics alert escalation evaluation.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
