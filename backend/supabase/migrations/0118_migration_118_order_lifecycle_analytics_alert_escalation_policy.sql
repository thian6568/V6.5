-- Migration 118: Order Lifecycle Analytics Alert Escalation Policy
-- Purpose:
-- Adds escalation policies, escalation queue, escalation action history,
-- evaluation functions, auto-escalation trigger, and dashboard views
-- for order lifecycle analytics alert incidents.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Alert Escalation Policies
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    policy_code TEXT NOT NULL UNIQUE,
    policy_name TEXT NOT NULL,
    policy_description TEXT,

    severity TEXT NOT NULL,
    incident_status TEXT NOT NULL DEFAULT 'open',

    first_escalation_due_minutes INTEGER NOT NULL DEFAULT 60,
    repeat_escalation_minutes INTEGER NOT NULL DEFAULT 240,
    max_escalation_level INTEGER NOT NULL DEFAULT 3,

    channel_code TEXT REFERENCES public.order_lifecycle_notification_channels(channel_code),

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    auto_notify BOOLEAN NOT NULL DEFAULT TRUE,

    policy_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_escalation_policies_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_oiaa_escalation_policies_status
    CHECK (incident_status IN ('open', 'acknowledged')),

    CONSTRAINT chk_oiaa_escalation_policies_timing
    CHECK (
        first_escalation_due_minutes > 0
        AND repeat_escalation_minutes > 0
        AND max_escalation_level > 0
    )
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_policies IS
'Stores escalation policy settings for analytics alert incidents by severity.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policies_code
ON public.order_lifecycle_analytics_alert_escalation_policies(policy_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policies_severity
ON public.order_lifecycle_analytics_alert_escalation_policies(severity);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policies_enabled
ON public.order_lifecycle_analytics_alert_escalation_policies(is_enabled);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_policies_config
ON public.order_lifecycle_analytics_alert_escalation_policies USING GIN(policy_config);

-- ============================================================
-- 2. Default Escalation Policies
-- ============================================================

INSERT INTO public.order_lifecycle_analytics_alert_escalation_policies (
    policy_code,
    policy_name,
    policy_description,
    severity,
    incident_status,
    first_escalation_due_minutes,
    repeat_escalation_minutes,
    max_escalation_level,
    channel_code,
    is_enabled,
    auto_notify,
    policy_config
)
VALUES
(
    'LOW_ANALYTICS_ALERT_ESCALATION',
    'Low Analytics Alert Escalation',
    'Default escalation policy for low severity analytics alert incidents.',
    'low',
    'open',
    1440,
    1440,
    2,
    'ADMIN_DASHBOARD',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_118')
),
(
    'MEDIUM_ANALYTICS_ALERT_ESCALATION',
    'Medium Analytics Alert Escalation',
    'Default escalation policy for medium severity analytics alert incidents.',
    'medium',
    'open',
    480,
    720,
    3,
    'ADMIN_DASHBOARD',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_118')
),
(
    'HIGH_ANALYTICS_ALERT_ESCALATION',
    'High Analytics Alert Escalation',
    'Default escalation policy for high severity analytics alert incidents.',
    'high',
    'open',
    120,
    240,
    4,
    'ADMIN_DASHBOARD',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_118')
),
(
    'CRITICAL_ANALYTICS_ALERT_ESCALATION',
    'Critical Analytics Alert Escalation',
    'Default escalation policy for critical analytics alert incidents.',
    'critical',
    'open',
    30,
    60,
    5,
    'IN_APP_ADMIN',
    TRUE,
    TRUE,
    jsonb_build_object('created_by', 'migration_118')
)
ON CONFLICT (policy_code) DO UPDATE
SET
    policy_name = EXCLUDED.policy_name,
    policy_description = EXCLUDED.policy_description,
    severity = EXCLUDED.severity,
    incident_status = EXCLUDED.incident_status,
    first_escalation_due_minutes = EXCLUDED.first_escalation_due_minutes,
    repeat_escalation_minutes = EXCLUDED.repeat_escalation_minutes,
    max_escalation_level = EXCLUDED.max_escalation_level,
    channel_code = EXCLUDED.channel_code,
    is_enabled = EXCLUDED.is_enabled,
    auto_notify = EXCLUDED.auto_notify,
    policy_config = EXCLUDED.policy_config,
    updated_at = NOW();

-- ============================================================
-- 3. Analytics Alert Escalation Queue
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    incident_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_incidents(id) ON DELETE CASCADE,

    policy_code TEXT NOT NULL,
    severity TEXT NOT NULL,

    escalation_level INTEGER NOT NULL DEFAULT 1,
    max_escalation_level INTEGER NOT NULL DEFAULT 3,

    escalation_status TEXT NOT NULL DEFAULT 'pending',

    channel_code TEXT,

    due_at TIMESTAMPTZ NOT NULL,
    escalated_at TIMESTAMPTZ,
    last_notified_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ,

    assigned_to UUID,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,

    escalation_notes TEXT,
    escalation_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    dedupe_key TEXT NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_escalation_queue_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_oiaa_escalation_queue_status
    CHECK (escalation_status IN ('pending', 'due', 'notified', 'resolved', 'cancelled', 'skipped')),

    CONSTRAINT chk_oiaa_escalation_queue_levels
    CHECK (
        escalation_level > 0
        AND max_escalation_level > 0
        AND escalation_level <= max_escalation_level
    )
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_queue IS
'Stores escalation queue items for analytics alert incidents that need higher attention.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_incident
ON public.order_lifecycle_analytics_alert_escalation_queue(incident_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_policy
ON public.order_lifecycle_analytics_alert_escalation_queue(policy_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_status
ON public.order_lifecycle_analytics_alert_escalation_queue(escalation_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_severity
ON public.order_lifecycle_analytics_alert_escalation_queue(severity);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_due
ON public.order_lifecycle_analytics_alert_escalation_queue(due_at);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_queue_payload
ON public.order_lifecycle_analytics_alert_escalation_queue USING GIN(escalation_payload);

-- ============================================================
-- 4. Analytics Alert Escalation Actions
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_escalation_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    escalation_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_escalation_queue(id) ON DELETE CASCADE,
    incident_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_incidents(id) ON DELETE CASCADE,

    action_type TEXT NOT NULL,
    action_status TEXT NOT NULL DEFAULT 'recorded',

    actor_id UUID,
    actor_type TEXT NOT NULL DEFAULT 'system',

    previous_escalation_status TEXT,
    new_escalation_status TEXT,

    action_notes TEXT,
    action_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_escalation_actions_status
    CHECK (action_status IN ('recorded', 'completed', 'failed', 'cancelled'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_escalation_actions IS
'Stores action history for analytics alert escalation review, notification, assignment, and resolution.';

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_actions_escalation
ON public.order_lifecycle_analytics_alert_escalation_actions(escalation_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_actions_incident
ON public.order_lifecycle_analytics_alert_escalation_actions(incident_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_actions_type
ON public.order_lifecycle_analytics_alert_escalation_actions(action_type);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_actions_created
ON public.order_lifecycle_analytics_alert_escalation_actions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_escalation_actions_payload
ON public.order_lifecycle_analytics_alert_escalation_actions USING GIN(action_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_escalation_policies_updated_at
ON public.order_lifecycle_analytics_alert_escalation_policies;

CREATE TRIGGER trg_oiaa_escalation_policies_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_escalation_policies
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_escalation_queue_updated_at
ON public.order_lifecycle_analytics_alert_escalation_queue;

CREATE TRIGGER trg_oiaa_escalation_queue_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_escalation_queue
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_updated_at();

-- ============================================================
-- 6. Ensure Escalation For Incident
-- ============================================================

CREATE OR REPLACE FUNCTION public.ensure_oiaa_escalation_for_incident(
    p_incident_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_incident RECORD;
    v_policy RECORD;
    v_escalation_id UUID;
    v_dedupe_key TEXT;
BEGIN
    IF p_incident_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_incident
    FROM public.order_lifecycle_analytics_alert_incidents
    WHERE id = p_incident_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_incident.incident_status NOT IN ('open', 'acknowledged') THEN
        UPDATE public.order_lifecycle_analytics_alert_escalation_queue
        SET
            escalation_status = 'resolved',
            resolved_at = NOW(),
            updated_at = NOW()
        WHERE incident_id = v_incident.id
        AND escalation_status IN ('pending', 'due', 'notified');

        RETURN NULL;
    END IF;

    SELECT *
    INTO v_policy
    FROM public.order_lifecycle_analytics_alert_escalation_policies
    WHERE severity = v_incident.severity
    AND incident_status IN ('open', v_incident.incident_status)
    AND is_enabled = TRUE
    ORDER BY
        CASE severity
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END,
        created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_dedupe_key := md5(
        concat_ws(
            '|',
            v_incident.id::TEXT,
            v_policy.policy_code
        )
    );

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_queue (
        incident_id,
        policy_code,
        severity,
        escalation_level,
        max_escalation_level,
        escalation_status,
        channel_code,
        due_at,
        next_review_at,
        escalation_payload,
        dedupe_key,
        created_at,
        updated_at
    )
    VALUES (
        v_incident.id,
        v_policy.policy_code,
        v_incident.severity,
        1,
        v_policy.max_escalation_level,
        'pending',
        v_policy.channel_code,
        COALESCE(v_incident.first_detected_at, v_incident.created_at, NOW())
            + make_interval(mins => v_policy.first_escalation_due_minutes),
        COALESCE(v_incident.first_detected_at, v_incident.created_at, NOW())
            + make_interval(mins => v_policy.first_escalation_due_minutes),
        jsonb_build_object(
            'incident_id', v_incident.id,
            'threshold_code', v_incident.threshold_code,
            'metric_scope', v_incident.metric_scope,
            'metric_name', v_incident.metric_name,
            'metric_value', v_incident.metric_value,
            'severity', v_incident.severity,
            'incident_status', v_incident.incident_status,
            'policy_code', v_policy.policy_code,
            'generated_by', 'migration_118'
        ),
        v_dedupe_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (dedupe_key) DO UPDATE
    SET
        severity = EXCLUDED.severity,
        max_escalation_level = EXCLUDED.max_escalation_level,
        channel_code = EXCLUDED.channel_code,
        escalation_payload = EXCLUDED.escalation_payload,
        escalation_status = CASE
            WHEN public.order_lifecycle_analytics_alert_escalation_queue.escalation_status = 'resolved'
            THEN 'pending'
            ELSE public.order_lifecycle_analytics_alert_escalation_queue.escalation_status
        END,
        updated_at = NOW()
    RETURNING id INTO v_escalation_id;

    RETURN v_escalation_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Record Escalation Action
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_oiaa_escalation_action(
    p_escalation_id UUID,
    p_action_type TEXT,
    p_actor_id UUID DEFAULT NULL,
    p_actor_type TEXT DEFAULT 'system',
    p_new_escalation_status TEXT DEFAULT NULL,
    p_action_notes TEXT DEFAULT NULL,
    p_action_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_escalation RECORD;
    v_action_id UUID;
    v_new_status TEXT;
BEGIN
    IF p_escalation_id IS NULL OR p_action_type IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_escalation
    FROM public.order_lifecycle_analytics_alert_escalation_queue
    WHERE id = p_escalation_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_new_status := COALESCE(p_new_escalation_status, v_escalation.escalation_status);

    INSERT INTO public.order_lifecycle_analytics_alert_escalation_actions (
        escalation_id,
        incident_id,
        action_type,
        action_status,
        actor_id,
        actor_type,
        previous_escalation_status,
        new_escalation_status,
        action_notes,
        action_payload,
        created_at
    )
    VALUES (
        v_escalation.id,
        v_escalation.incident_id,
        p_action_type,
        'recorded',
        p_actor_id,
        COALESCE(p_actor_type, 'system'),
        v_escalation.escalation_status,
        v_new_status,
        p_action_notes,
        COALESCE(p_action_payload, '{}'::jsonb),
        NOW()
    )
    RETURNING id INTO v_action_id;

    UPDATE public.order_lifecycle_analytics_alert_escalation_queue
    SET
        escalation_status = v_new_status,
        resolved_by = CASE
            WHEN v_new_status = 'resolved' THEN p_actor_id
            ELSE resolved_by
        END,
        resolved_at = CASE
            WHEN v_new_status = 'resolved' THEN NOW()
            ELSE resolved_at
        END,
        escalation_notes = COALESCE(p_action_notes, escalation_notes),
        updated_at = NOW()
    WHERE id = v_escalation.id;

    RETURN v_action_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Evaluate Escalations
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_oiaa_escalations()
RETURNS JSONB AS $$
DECLARE
    v_incident RECORD;
    v_escalation RECORD;
    v_reason TEXT;
    v_created_count INTEGER := 0;
    v_due_count INTEGER := 0;
    v_notified_count INTEGER := 0;
    v_resolved_count INTEGER := 0;
BEGIN
    FOR v_incident IN
        SELECT id
        FROM public.order_lifecycle_analytics_alert_incidents
        WHERE incident_status IN ('open', 'acknowledged')
    LOOP
        IF public.ensure_oiaa_escalation_for_incident(v_incident.id) IS NOT NULL THEN
            v_created_count := v_created_count + 1;
        END IF;
    END LOOP;

    UPDATE public.order_lifecycle_analytics_alert_escalation_queue
    SET
        escalation_status = 'due',
        updated_at = NOW()
    WHERE escalation_status IN ('pending', 'notified')
    AND COALESCE(next_review_at, due_at) <= NOW();

    GET DIAGNOSTICS v_due_count = ROW_COUNT;

    FOR v_escalation IN
        SELECT
            e.*,
            i.incident_status,
            i.threshold_code,
            i.metric_scope,
            i.metric_name,
            i.metric_value,
            i.threshold_value
        FROM public.order_lifecycle_analytics_alert_escalation_queue e
        JOIN public.order_lifecycle_analytics_alert_incidents i
        ON i.id = e.incident_id
        JOIN public.order_lifecycle_analytics_alert_escalation_policies p
        ON p.policy_code = e.policy_code
        WHERE e.escalation_status = 'due'
        AND i.incident_status IN ('open', 'acknowledged')
        AND p.auto_notify = TRUE
        ORDER BY
            CASE e.severity
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                ELSE 4
            END,
            e.due_at ASC
    LOOP
        v_reason := CASE
            WHEN v_escalation.severity = 'critical' THEN 'critical_analytics_alert_open'
            WHEN v_escalation.severity = 'high' THEN 'high_analytics_alert_open'
            ELSE 'analytics_alert_opened'
        END;

        PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
            v_escalation.incident_id,
            'ESCALATION_' || v_escalation.policy_code,
            COALESCE(v_escalation.channel_code, 'ADMIN_DASHBOARD'),
            v_reason,
            CASE
                WHEN v_escalation.severity = 'critical' THEN 5
                WHEN v_escalation.severity = 'high' THEN 20
                WHEN v_escalation.severity = 'medium' THEN 60
                ELSE 100
            END,
            jsonb_build_object(
                'reason', v_reason,
                'escalation_id', v_escalation.id,
                'incident_id', v_escalation.incident_id,
                'policy_code', v_escalation.policy_code,
                'escalation_level', v_escalation.escalation_level,
                'max_escalation_level', v_escalation.max_escalation_level,
                'severity', v_escalation.severity,
                'threshold_code', v_escalation.threshold_code,
                'metric_scope', v_escalation.metric_scope,
                'metric_name', v_escalation.metric_name,
                'metric_value', v_escalation.metric_value,
                'threshold_value', v_escalation.threshold_value,
                'generated_by', 'migration_118'
            )
        );

        UPDATE public.order_lifecycle_analytics_alert_escalation_queue
        SET
            escalation_status = 'notified',
            escalated_at = COALESCE(escalated_at, NOW()),
            last_notified_at = NOW(),
            next_review_at = CASE
                WHEN escalation_level < max_escalation_level
                THEN NOW() + INTERVAL '4 hours'
                ELSE NULL
            END,
            escalation_level = CASE
                WHEN escalation_level < max_escalation_level
                THEN escalation_level + 1
                ELSE escalation_level
            END,
            updated_at = NOW()
        WHERE id = v_escalation.id;

        PERFORM public.record_oiaa_escalation_action(
            v_escalation.id,
            'notify',
            NULL,
            'system',
            'notified',
            'Escalation notification job created.',
            jsonb_build_object(
                'notification_reason', v_reason,
                'channel_code', COALESCE(v_escalation.channel_code, 'ADMIN_DASHBOARD'),
                'generated_by', 'migration_118'
            )
        );

        v_notified_count := v_notified_count + 1;
    END LOOP;

    UPDATE public.order_lifecycle_analytics_alert_escalation_queue e
    SET
        escalation_status = 'resolved',
        resolved_at = NOW(),
        updated_at = NOW()
    FROM public.order_lifecycle_analytics_alert_incidents i
    WHERE i.id = e.incident_id
    AND i.incident_status IN ('resolved', 'ignored')
    AND e.escalation_status IN ('pending', 'due', 'notified');

    GET DIAGNOSTICS v_resolved_count = ROW_COUNT;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'evaluate_analytics_alert_escalations',
        'completed',
        jsonb_build_object(
            'created_count', v_created_count,
            'due_count', v_due_count,
            'notified_count', v_notified_count,
            'resolved_count', v_resolved_count,
            'generated_by', 'migration_118'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'created_count', v_created_count,
        'due_count', v_due_count,
        'notified_count', v_notified_count,
        'resolved_count', v_resolved_count,
        'generated_by', 'migration_118'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Auto Escalation Trigger
-- ============================================================

CREATE OR REPLACE FUNCTION public.oiaa_escalation_incident_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS NOT NULL THEN
        PERFORM public.ensure_oiaa_escalation_for_incident(NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_escalation_incident
ON public.order_lifecycle_analytics_alert_incidents;

CREATE TRIGGER trg_oiaa_escalation_incident
AFTER INSERT OR UPDATE ON public.order_lifecycle_analytics_alert_incidents
FOR EACH ROW
EXECUTE FUNCTION public.oiaa_escalation_incident_trigger();

-- ============================================================
-- 10. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.oiaa_escalation_policy_dashboard_view AS
SELECT
    p.id,
    p.policy_code,
    p.policy_name,
    p.policy_description,
    p.severity,
    p.incident_status,
    p.first_escalation_due_minutes,
    p.repeat_escalation_minutes,
    p.max_escalation_level,
    p.channel_code,
    c.channel_name,
    c.channel_type,
    p.is_enabled,
    p.auto_notify,
    COUNT(q.id)::INTEGER AS queue_count,
    COUNT(q.id) FILTER (WHERE q.escalation_status IN ('pending', 'due', 'notified'))::INTEGER AS active_queue_count,
    p.policy_config,
    p.created_at,
    p.updated_at
FROM public.order_lifecycle_analytics_alert_escalation_policies p
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = p.channel_code
LEFT JOIN public.order_lifecycle_analytics_alert_escalation_queue q
ON q.policy_code = p.policy_code
GROUP BY
    p.id,
    p.policy_code,
    p.policy_name,
    p.policy_description,
    p.severity,
    p.incident_status,
    p.first_escalation_due_minutes,
    p.repeat_escalation_minutes,
    p.max_escalation_level,
    p.channel_code,
    c.channel_name,
    c.channel_type,
    p.is_enabled,
    p.auto_notify,
    p.policy_config,
    p.created_at,
    p.updated_at;

COMMENT ON VIEW public.oiaa_escalation_policy_dashboard_view IS
'Admin dashboard view for analytics alert escalation policies.';

CREATE OR REPLACE VIEW public.oiaa_escalation_queue_dashboard_view AS
SELECT
    q.id,
    q.incident_id,
    q.policy_code,
    q.severity,
    q.escalation_level,
    q.max_escalation_level,
    q.escalation_status,
    q.channel_code,
    c.channel_name,
    c.channel_type,
    q.due_at,
    q.escalated_at,
    q.last_notified_at,
    q.next_review_at,
    q.assigned_to,
    q.resolved_by,
    q.resolved_at,
    q.escalation_notes,

    i.threshold_code,
    i.incident_title,
    i.incident_status,
    i.metric_scope,
    i.metric_name,
    i.metric_value,
    i.threshold_value,
    i.first_detected_at,
    i.last_detected_at,

    CASE
        WHEN q.escalation_status = 'resolved' THEN 'resolved'
        WHEN q.escalation_status = 'due' THEN 'due_now'
        WHEN q.escalation_status IN ('pending', 'notified')
             AND COALESCE(q.next_review_at, q.due_at) <= NOW() THEN 'due_now'
        WHEN q.severity = 'critical' AND q.escalation_status IN ('pending', 'due', 'notified') THEN 'critical_attention'
        WHEN q.severity = 'high' AND q.escalation_status IN ('pending', 'due', 'notified') THEN 'high_attention'
        ELSE q.escalation_status
    END AS escalation_dashboard_status,

    q.escalation_payload,
    q.created_at,
    q.updated_at
FROM public.order_lifecycle_analytics_alert_escalation_queue q
JOIN public.order_lifecycle_analytics_alert_incidents i
ON i.id = q.incident_id
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = q.channel_code;

COMMENT ON VIEW public.oiaa_escalation_queue_dashboard_view IS
'Admin dashboard view for analytics alert escalation queue and incident context.';

CREATE OR REPLACE VIEW public.oiaa_escalation_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_escalations,
    COUNT(*) FILTER (WHERE escalation_status = 'pending')::INTEGER AS pending_escalations,
    COUNT(*) FILTER (WHERE escalation_status = 'due')::INTEGER AS due_escalations,
    COUNT(*) FILTER (WHERE escalation_status = 'notified')::INTEGER AS notified_escalations,
    COUNT(*) FILTER (WHERE escalation_status = 'resolved')::INTEGER AS resolved_escalations,
    COUNT(*) FILTER (
        WHERE severity = 'critical'
        AND escalation_status IN ('pending', 'due', 'notified')
    )::INTEGER AS active_critical_escalations,
    MIN(COALESCE(next_review_at, due_at)) FILTER (
        WHERE escalation_status IN ('pending', 'due', 'notified')
    ) AS next_escalation_due_at,
    MAX(updated_at) AS latest_updated_at,
    CASE
        WHEN COUNT(*) = 0 THEN 'no_escalations'
        WHEN COUNT(*) FILTER (
            WHERE severity = 'critical'
            AND escalation_status IN ('pending', 'due', 'notified')
        ) > 0 THEN 'critical_attention'
        WHEN COUNT(*) FILTER (WHERE escalation_status = 'due') > 0 THEN 'due'
        WHEN COUNT(*) FILTER (WHERE escalation_status IN ('pending', 'notified')) > 0 THEN 'active'
        ELSE 'healthy'
    END AS escalation_health_status
FROM public.order_lifecycle_analytics_alert_escalation_queue;

COMMENT ON VIEW public.oiaa_escalation_health_view IS
'Shows overall health for analytics alert escalation policies and queue.';

-- ============================================================
-- 11. Initial Evaluation
-- ============================================================

SELECT public.evaluate_oiaa_escalations();

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_escalation_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_escalation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_escalation_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_policies"
ON public.order_lifecycle_analytics_alert_escalation_policies;

CREATE POLICY "svc_manage_oiaa_escalation_policies"
ON public.order_lifecycle_analytics_alert_escalation_policies
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_queue"
ON public.order_lifecycle_analytics_alert_escalation_queue;

CREATE POLICY "svc_manage_oiaa_escalation_queue"
ON public.order_lifecycle_analytics_alert_escalation_queue
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_escalation_actions"
ON public.order_lifecycle_analytics_alert_escalation_actions;

CREATE POLICY "svc_manage_oiaa_escalation_actions"
ON public.order_lifecycle_analytics_alert_escalation_actions
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
    118,
    'migration_118_order_lifecycle_analytics_alert_escalation_policy',
    'Adds escalation policies, escalation queue, escalation action history, evaluation functions, auto-escalation trigger, and dashboard views for analytics alert incidents.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
