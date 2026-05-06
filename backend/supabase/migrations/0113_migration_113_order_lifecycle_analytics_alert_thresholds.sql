-- Migration 113: Order Lifecycle Analytics Alert Thresholds
-- Purpose:
-- Adds configurable analytics alert thresholds, evaluation history,
-- alert incidents, threshold evaluation functions, and dashboard views
-- for order lifecycle notification analytics health.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Alert Thresholds
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_thresholds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    threshold_code TEXT NOT NULL UNIQUE,
    threshold_name TEXT NOT NULL,
    threshold_description TEXT,

    metric_scope TEXT NOT NULL DEFAULT 'kpi',
    metric_name TEXT NOT NULL,

    comparison_operator TEXT NOT NULL,
    threshold_value NUMERIC(14, 4) NOT NULL,

    severity TEXT NOT NULL DEFAULT 'medium',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    auto_resolve BOOLEAN NOT NULL DEFAULT TRUE,

    threshold_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_threshold_scope
    CHECK (
        metric_scope IN (
            'kpi',
            'daily_dispatch',
            'worker_dispatch',
            'exception_notification',
            'refresh_health'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_threshold_operator
    CHECK (
        comparison_operator IN (
            'gt',
            'gte',
            'lt',
            'lte',
            'eq',
            'neq'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_threshold_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_thresholds IS
'Stores configurable alert thresholds for order lifecycle notification analytics and KPI health.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_thresholds_code
ON public.order_lifecycle_analytics_alert_thresholds(threshold_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_thresholds_scope
ON public.order_lifecycle_analytics_alert_thresholds(metric_scope);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_thresholds_metric
ON public.order_lifecycle_analytics_alert_thresholds(metric_name);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_thresholds_enabled
ON public.order_lifecycle_analytics_alert_thresholds(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_thresholds_config
ON public.order_lifecycle_analytics_alert_thresholds USING GIN(threshold_config);

-- ============================================================
-- 2. Default Analytics Alert Thresholds
-- ============================================================

INSERT INTO public.order_lifecycle_analytics_alert_thresholds (
    threshold_code,
    threshold_name,
    threshold_description,
    metric_scope,
    metric_name,
    comparison_operator,
    threshold_value,
    severity,
    is_enabled,
    auto_resolve,
    threshold_config
)
VALUES
(
    'DISPATCH_SUCCESS_RATE_LOW',
    'Dispatch Success Rate Low',
    'Creates an alert when notification dispatch success rate drops below 90%.',
    'kpi',
    'success_rate_percent',
    'lt',
    90,
    'high',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
),
(
    'DISPATCH_FAILURE_RATE_HIGH',
    'Dispatch Failure Rate High',
    'Creates an alert when notification dispatch failure rate reaches or exceeds 10%.',
    'kpi',
    'failure_rate_percent',
    'gte',
    10,
    'high',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
),
(
    'DISPATCH_STALE_LOCKS_PRESENT',
    'Dispatch Stale Locks Present',
    'Creates an alert when one or more stale dispatch locks are detected.',
    'kpi',
    'stale_lock_jobs',
    'gt',
    0,
    'medium',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
),
(
    'DISPATCH_DEAD_LETTER_PRESENT',
    'Dispatch Dead Letter Jobs Present',
    'Creates an alert when one or more notification jobs are in the dead letter queue.',
    'kpi',
    'dead_letter_jobs',
    'gt',
    0,
    'critical',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
),
(
    'OPEN_CRITICAL_EXCEPTIONS_PRESENT',
    'Open Critical Exceptions Present',
    'Creates an alert when one or more critical lifecycle exceptions are open.',
    'kpi',
    'open_critical_exceptions',
    'gt',
    0,
    'critical',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
),
(
    'BREACHED_SLA_PRESENT',
    'Breached SLA Present',
    'Creates an alert when one or more lifecycle SLAs are breached.',
    'kpi',
    'breached_sla_count',
    'gt',
    0,
    'critical',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_113')
)
ON CONFLICT (threshold_code) DO UPDATE
SET
    threshold_name = EXCLUDED.threshold_name,
    threshold_description = EXCLUDED.threshold_description,
    metric_scope = EXCLUDED.metric_scope,
    metric_name = EXCLUDED.metric_name,
    comparison_operator = EXCLUDED.comparison_operator,
    threshold_value = EXCLUDED.threshold_value,
    severity = EXCLUDED.severity,
    is_enabled = EXCLUDED.is_enabled,
    auto_resolve = EXCLUDED.auto_resolve,
    threshold_config = EXCLUDED.threshold_config,
    updated_at = NOW();

-- ============================================================
-- 3. Analytics Threshold Evaluations
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_threshold_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    threshold_id UUID REFERENCES public.order_lifecycle_analytics_alert_thresholds(id) ON DELETE SET NULL,
    threshold_code TEXT NOT NULL,

    metric_scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,

    metric_value NUMERIC(14, 4),
    comparison_operator TEXT NOT NULL,
    threshold_value NUMERIC(14, 4) NOT NULL,

    is_breached BOOLEAN NOT NULL DEFAULT FALSE,

    severity TEXT NOT NULL DEFAULT 'medium',

    source_snapshot_id UUID,
    source_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    evaluated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.order_lifecycle_analytics_threshold_evaluations IS
'Stores evaluation history for analytics alert thresholds.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_threshold_evaluations_code
ON public.order_lifecycle_analytics_threshold_evaluations(threshold_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_threshold_evaluations_metric
ON public.order_lifecycle_analytics_threshold_evaluations(metric_scope, metric_name);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_threshold_evaluations_breached
ON public.order_lifecycle_analytics_threshold_evaluations(is_breached);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_threshold_evaluations_created_at
ON public.order_lifecycle_analytics_threshold_evaluations(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_threshold_evaluations_payload
ON public.order_lifecycle_analytics_threshold_evaluations USING GIN(source_payload);

-- ============================================================
-- 4. Analytics Alert Incidents
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    threshold_id UUID REFERENCES public.order_lifecycle_analytics_alert_thresholds(id) ON DELETE SET NULL,
    threshold_code TEXT NOT NULL,

    incident_title TEXT NOT NULL,
    incident_description TEXT,

    metric_scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,

    metric_value NUMERIC(14, 4),
    comparison_operator TEXT NOT NULL,
    threshold_value NUMERIC(14, 4) NOT NULL,

    severity TEXT NOT NULL DEFAULT 'medium',
    incident_status TEXT NOT NULL DEFAULT 'open',

    first_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    acknowledged_by UUID,
    acknowledged_at TIMESTAMPTZ,

    resolved_by UUID,
    resolved_at TIMESTAMPTZ,

    resolution_notes TEXT,

    source_evaluation_id UUID,
    source_snapshot_id UUID,

    incident_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    dedupe_key TEXT NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_incidents_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_analytics_alert_incidents_status
    CHECK (incident_status IN ('open', 'acknowledged', 'resolved', 'ignored'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_incidents IS
'Stores active and historical analytics alert incidents generated by threshold breaches.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_incidents_code
ON public.order_lifecycle_analytics_alert_incidents(threshold_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_incidents_status
ON public.order_lifecycle_analytics_alert_incidents(incident_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_incidents_severity
ON public.order_lifecycle_analytics_alert_incidents(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_incidents_created_at
ON public.order_lifecycle_analytics_alert_incidents(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_incidents_payload
ON public.order_lifecycle_analytics_alert_incidents USING GIN(incident_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_analytics_alert_thresholds_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_thresholds_updated_at
ON public.order_lifecycle_analytics_alert_thresholds;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_thresholds_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_thresholds
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_thresholds_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_incidents_updated_at
ON public.order_lifecycle_analytics_alert_incidents;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_incidents_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_incidents
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_thresholds_updated_at();

-- ============================================================
-- 6. Compare Threshold Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.compare_order_lifecycle_analytics_threshold(
    p_metric_value NUMERIC,
    p_comparison_operator TEXT,
    p_threshold_value NUMERIC
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_metric_value IS NULL
       OR p_comparison_operator IS NULL
       OR p_threshold_value IS NULL THEN
        RETURN FALSE;
    END IF;

    IF p_comparison_operator = 'gt' THEN
        RETURN p_metric_value > p_threshold_value;
    END IF;

    IF p_comparison_operator = 'gte' THEN
        RETURN p_metric_value >= p_threshold_value;
    END IF;

    IF p_comparison_operator = 'lt' THEN
        RETURN p_metric_value < p_threshold_value;
    END IF;

    IF p_comparison_operator = 'lte' THEN
        RETURN p_metric_value <= p_threshold_value;
    END IF;

    IF p_comparison_operator = 'eq' THEN
        RETURN p_metric_value = p_threshold_value;
    END IF;

    IF p_comparison_operator = 'neq' THEN
        RETURN p_metric_value <> p_threshold_value;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Evaluate Analytics Alert Thresholds
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_order_lifecycle_analytics_alert_thresholds()
RETURNS JSONB AS $$
DECLARE
    v_threshold RECORD;

    v_snapshot_id UUID;
    v_total_jobs NUMERIC := 0;
    v_pending_jobs NUMERIC := 0;
    v_locked_jobs NUMERIC := 0;
    v_sent_jobs NUMERIC := 0;
    v_failed_jobs NUMERIC := 0;
    v_ready_jobs NUMERIC := 0;
    v_stale_lock_jobs NUMERIC := 0;
    v_dead_letter_jobs NUMERIC := 0;
    v_success_rate_percent NUMERIC := 0;
    v_failure_rate_percent NUMERIC := 0;
    v_open_critical_exceptions NUMERIC := 0;
    v_breached_sla_count NUMERIC := 0;

    v_metric_value NUMERIC;
    v_is_breached BOOLEAN := FALSE;

    v_evaluation_id UUID;
    v_incident_id UUID;
    v_dedupe_key TEXT;

    v_evaluated_count INTEGER := 0;
    v_breached_count INTEGER := 0;
    v_auto_resolved_count INTEGER := 0;
BEGIN
    SELECT
        id,
        total_jobs,
        pending_jobs,
        locked_jobs,
        sent_jobs,
        failed_jobs,
        ready_jobs,
        stale_lock_jobs,
        dead_letter_jobs,
        success_rate_percent,
        failure_rate_percent,
        open_critical_exceptions,
        breached_sla_count
    INTO
        v_snapshot_id,
        v_total_jobs,
        v_pending_jobs,
        v_locked_jobs,
        v_sent_jobs,
        v_failed_jobs,
        v_ready_jobs,
        v_stale_lock_jobs,
        v_dead_letter_jobs,
        v_success_rate_percent,
        v_failure_rate_percent,
        v_open_critical_exceptions,
        v_breached_sla_count
    FROM public.order_lifecycle_notification_dispatch_latest_kpi_view
    ORDER BY created_at DESC
    LIMIT 1;

    FOR v_threshold IN
        SELECT *
        FROM public.order_lifecycle_analytics_alert_thresholds
        WHERE is_enabled = TRUE
        ORDER BY severity DESC, threshold_code ASC
    LOOP
        v_metric_value := CASE v_threshold.metric_name
            WHEN 'total_jobs' THEN COALESCE(v_total_jobs, 0)
            WHEN 'pending_jobs' THEN COALESCE(v_pending_jobs, 0)
            WHEN 'locked_jobs' THEN COALESCE(v_locked_jobs, 0)
            WHEN 'sent_jobs' THEN COALESCE(v_sent_jobs, 0)
            WHEN 'failed_jobs' THEN COALESCE(v_failed_jobs, 0)
            WHEN 'ready_jobs' THEN COALESCE(v_ready_jobs, 0)
            WHEN 'stale_lock_jobs' THEN COALESCE(v_stale_lock_jobs, 0)
            WHEN 'dead_letter_jobs' THEN COALESCE(v_dead_letter_jobs, 0)
            WHEN 'success_rate_percent' THEN COALESCE(v_success_rate_percent, 0)
            WHEN 'failure_rate_percent' THEN COALESCE(v_failure_rate_percent, 0)
            WHEN 'open_critical_exceptions' THEN COALESCE(v_open_critical_exceptions, 0)
            WHEN 'breached_sla_count' THEN COALESCE(v_breached_sla_count, 0)
            ELSE NULL
        END;

        IF v_metric_value IS NULL THEN
            CONTINUE;
        END IF;

        v_is_breached := public.compare_order_lifecycle_analytics_threshold(
            v_metric_value,
            v_threshold.comparison_operator,
            v_threshold.threshold_value
        );

        INSERT INTO public.order_lifecycle_analytics_threshold_evaluations (
            threshold_id,
            threshold_code,
            metric_scope,
            metric_name,
            metric_value,
            comparison_operator,
            threshold_value,
            is_breached,
            severity,
            source_snapshot_id,
            source_payload,
            evaluated_at,
            created_at
        )
        VALUES (
            v_threshold.id,
            v_threshold.threshold_code,
            v_threshold.metric_scope,
            v_threshold.metric_name,
            v_metric_value,
            v_threshold.comparison_operator,
            v_threshold.threshold_value,
            v_is_breached,
            v_threshold.severity,
            v_snapshot_id,
            jsonb_build_object(
                'threshold_code', v_threshold.threshold_code,
                'metric_scope', v_threshold.metric_scope,
                'metric_name', v_threshold.metric_name,
                'metric_value', v_metric_value,
                'comparison_operator', v_threshold.comparison_operator,
                'threshold_value', v_threshold.threshold_value,
                'source_snapshot_id', v_snapshot_id,
                'generated_by', 'migration_113'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_evaluation_id;

        v_evaluated_count := v_evaluated_count + 1;

        v_dedupe_key := md5(
            concat_ws(
                '|',
                v_threshold.threshold_code,
                v_threshold.metric_scope,
                v_threshold.metric_name
            )
        );

        IF v_is_breached = TRUE THEN
            INSERT INTO public.order_lifecycle_analytics_alert_incidents (
                threshold_id,
                threshold_code,
                incident_title,
                incident_description,
                metric_scope,
                metric_name,
                metric_value,
                comparison_operator,
                threshold_value,
                severity,
                incident_status,
                first_detected_at,
                last_detected_at,
                source_evaluation_id,
                source_snapshot_id,
                incident_payload,
                dedupe_key,
                created_at,
                updated_at
            )
            VALUES (
                v_threshold.id,
                v_threshold.threshold_code,
                v_threshold.threshold_name,
                v_threshold.threshold_description,
                v_threshold.metric_scope,
                v_threshold.metric_name,
                v_metric_value,
                v_threshold.comparison_operator,
                v_threshold.threshold_value,
                v_threshold.severity,
                'open',
                NOW(),
                NOW(),
                v_evaluation_id,
                v_snapshot_id,
                jsonb_build_object(
                    'threshold_code', v_threshold.threshold_code,
                    'metric_scope', v_threshold.metric_scope,
                    'metric_name', v_threshold.metric_name,
                    'metric_value', v_metric_value,
                    'comparison_operator', v_threshold.comparison_operator,
                    'threshold_value', v_threshold.threshold_value,
                    'source_evaluation_id', v_evaluation_id,
                    'source_snapshot_id', v_snapshot_id,
                    'generated_by', 'migration_113'
                ),
                v_dedupe_key,
                NOW(),
                NOW()
            )
            ON CONFLICT (dedupe_key) DO UPDATE
            SET
                threshold_id = EXCLUDED.threshold_id,
                incident_title = EXCLUDED.incident_title,
                incident_description = EXCLUDED.incident_description,
                metric_value = EXCLUDED.metric_value,
                comparison_operator = EXCLUDED.comparison_operator,
                threshold_value = EXCLUDED.threshold_value,
                severity = EXCLUDED.severity,
                incident_status = CASE
                    WHEN public.order_lifecycle_analytics_alert_incidents.incident_status IN ('resolved', 'ignored')
                    THEN 'open'
                    ELSE public.order_lifecycle_analytics_alert_incidents.incident_status
                END,
                last_detected_at = NOW(),
                source_evaluation_id = EXCLUDED.source_evaluation_id,
                source_snapshot_id = EXCLUDED.source_snapshot_id,
                incident_payload = EXCLUDED.incident_payload,
                updated_at = NOW()
            RETURNING id INTO v_incident_id;

            v_breached_count := v_breached_count + 1;
        ELSE
            IF v_threshold.auto_resolve = TRUE THEN
                UPDATE public.order_lifecycle_analytics_alert_incidents
                SET
                    incident_status = 'resolved',
                    resolved_at = NOW(),
                    resolution_notes = 'Auto-resolved because the threshold is no longer breached.',
                    updated_at = NOW()
                WHERE dedupe_key = v_dedupe_key
                AND incident_status IN ('open', 'acknowledged');

                IF FOUND THEN
                    v_auto_resolved_count := v_auto_resolved_count + 1;
                END IF;
            END IF;
        END IF;
    END LOOP;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'evaluate_analytics_alert_thresholds',
        'completed',
        jsonb_build_object(
            'evaluated_count', v_evaluated_count,
            'breached_count', v_breached_count,
            'auto_resolved_count', v_auto_resolved_count,
            'source_snapshot_id', v_snapshot_id,
            'generated_by', 'migration_113'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'evaluated_count', v_evaluated_count,
        'breached_count', v_breached_count,
        'auto_resolved_count', v_auto_resolved_count,
        'source_snapshot_id', v_snapshot_id,
        'generated_by', 'migration_113'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Acknowledge / Resolve Incident Functions
-- ============================================================

CREATE OR REPLACE FUNCTION public.acknowledge_order_lifecycle_analytics_alert_incident(
    p_incident_id UUID,
    p_actor_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_incident_id IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.order_lifecycle_analytics_alert_incidents
    SET
        incident_status = 'acknowledged',
        acknowledged_by = p_actor_id,
        acknowledged_at = NOW(),
        updated_at = NOW()
    WHERE id = p_incident_id
    AND incident_status = 'open';

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.resolve_order_lifecycle_analytics_alert_incident(
    p_incident_id UUID,
    p_actor_id UUID DEFAULT NULL,
    p_resolution_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_incident_id IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.order_lifecycle_analytics_alert_incidents
    SET
        incident_status = 'resolved',
        resolved_by = p_actor_id,
        resolved_at = NOW(),
        resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
        updated_at = NOW()
    WHERE id = p_incident_id
    AND incident_status IN ('open', 'acknowledged');

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_threshold_dashboard_view AS
SELECT
    t.id,
    t.threshold_code,
    t.threshold_name,
    t.threshold_description,
    t.metric_scope,
    t.metric_name,
    t.comparison_operator,
    t.threshold_value,
    t.severity,
    t.is_enabled,
    t.auto_resolve,

    latest_eval.id AS latest_evaluation_id,
    latest_eval.metric_value AS latest_metric_value,
    latest_eval.is_breached AS latest_is_breached,
    latest_eval.evaluated_at AS latest_evaluated_at,

    open_incident.id AS open_incident_id,
    open_incident.incident_status AS open_incident_status,
    open_incident.last_detected_at AS open_incident_last_detected_at,

    CASE
        WHEN t.is_enabled = FALSE THEN 'disabled'
        WHEN open_incident.id IS NOT NULL THEN 'breached'
        WHEN latest_eval.id IS NULL THEN 'not_evaluated'
        WHEN latest_eval.is_breached = TRUE THEN 'breached'
        ELSE 'healthy'
    END AS threshold_dashboard_status,

    t.threshold_config,
    t.created_at,
    t.updated_at
FROM public.order_lifecycle_analytics_alert_thresholds t
LEFT JOIN LATERAL (
    SELECT e.*
    FROM public.order_lifecycle_analytics_threshold_evaluations e
    WHERE e.threshold_code = t.threshold_code
    ORDER BY e.created_at DESC
    LIMIT 1
) latest_eval ON TRUE
LEFT JOIN LATERAL (
    SELECT i.*
    FROM public.order_lifecycle_analytics_alert_incidents i
    WHERE i.threshold_code = t.threshold_code
    AND i.incident_status IN ('open', 'acknowledged')
    ORDER BY i.created_at DESC
    LIMIT 1
) open_incident ON TRUE;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_threshold_dashboard_view IS
'Admin dashboard view for analytics alert thresholds and latest evaluation status.';

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_incident_dashboard_view AS
SELECT
    i.id,
    i.threshold_code,
    t.threshold_name,
    i.incident_title,
    i.incident_description,
    i.metric_scope,
    i.metric_name,
    i.metric_value,
    i.comparison_operator,
    i.threshold_value,
    i.severity,
    i.incident_status,
    i.first_detected_at,
    i.last_detected_at,
    i.acknowledged_by,
    i.acknowledged_at,
    i.resolved_by,
    i.resolved_at,
    i.resolution_notes,
    i.source_evaluation_id,
    i.source_snapshot_id,

    CASE
        WHEN i.incident_status = 'resolved' THEN 'resolved'
        WHEN i.incident_status = 'ignored' THEN 'ignored'
        WHEN i.severity = 'critical' AND i.incident_status IN ('open', 'acknowledged') THEN 'critical_attention'
        WHEN i.severity = 'high' AND i.incident_status IN ('open', 'acknowledged') THEN 'high_attention'
        WHEN i.incident_status = 'acknowledged' THEN 'acknowledged'
        ELSE 'open'
    END AS incident_dashboard_status,

    i.incident_payload,
    i.created_at,
    i.updated_at
FROM public.order_lifecycle_analytics_alert_incidents i
LEFT JOIN public.order_lifecycle_analytics_alert_thresholds t
ON t.threshold_code = i.threshold_code;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_incident_dashboard_view IS
'Admin dashboard view for analytics alert incidents generated from threshold breaches.';

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_thresholds,
    COUNT(*) FILTER (WHERE is_enabled = TRUE)::INTEGER AS enabled_thresholds,
    COUNT(*) FILTER (WHERE is_enabled = FALSE)::INTEGER AS disabled_thresholds,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.order_lifecycle_analytics_alert_incidents
        WHERE incident_status IN ('open', 'acknowledged')
    ) AS active_incidents,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.order_lifecycle_analytics_alert_incidents
        WHERE incident_status IN ('open', 'acknowledged')
        AND severity = 'critical'
    ) AS active_critical_incidents,

    (
        SELECT MAX(evaluated_at)
        FROM public.order_lifecycle_analytics_threshold_evaluations
    ) AS latest_evaluated_at,

    CASE
        WHEN COUNT(*) = 0 THEN 'not_configured'
        WHEN (
            SELECT COUNT(*)
            FROM public.order_lifecycle_analytics_alert_incidents
            WHERE incident_status IN ('open', 'acknowledged')
            AND severity = 'critical'
        ) > 0 THEN 'critical_attention'
        WHEN (
            SELECT COUNT(*)
            FROM public.order_lifecycle_analytics_alert_incidents
            WHERE incident_status IN ('open', 'acknowledged')
        ) > 0 THEN 'attention_required'
        WHEN (
            SELECT MAX(evaluated_at)
            FROM public.order_lifecycle_analytics_threshold_evaluations
        ) IS NULL THEN 'not_evaluated'
        WHEN (
            SELECT MAX(evaluated_at)
            FROM public.order_lifecycle_analytics_threshold_evaluations
        ) < NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'healthy'
    END AS analytics_alert_health_status
FROM public.order_lifecycle_analytics_alert_thresholds;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_health_view IS
'Shows overall health status for analytics alert thresholds and active incidents.';

-- ============================================================
-- 10. Initial Evaluation
-- ============================================================

SELECT public.evaluate_order_lifecycle_analytics_alert_thresholds();

-- ============================================================
-- 11. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_thresholds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_threshold_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_incidents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics alert thresholds"
ON public.order_lifecycle_analytics_alert_thresholds;

CREATE POLICY "Service role can manage order lifecycle analytics alert thresholds"
ON public.order_lifecycle_analytics_alert_thresholds
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics threshold evaluations"
ON public.order_lifecycle_analytics_threshold_evaluations;

CREATE POLICY "Service role can manage order lifecycle analytics threshold evaluations"
ON public.order_lifecycle_analytics_threshold_evaluations
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle analytics alert incidents"
ON public.order_lifecycle_analytics_alert_incidents;

CREATE POLICY "Service role can manage order lifecycle analytics alert incidents"
ON public.order_lifecycle_analytics_alert_incidents
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
    113,
    'migration_113_order_lifecycle_analytics_alert_thresholds',
    'Adds configurable analytics alert thresholds, evaluation history, alert incidents, threshold evaluation functions, and dashboard views.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
