-- Migration 114: Order Lifecycle Analytics Alert Notification Routing
-- Purpose:
-- Adds routing rules, notification jobs, delivery attempts, routing functions,
-- auto-routing trigger, and dashboard views for analytics alert incidents.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Analytics Alert Notification Routing Rules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_routing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL UNIQUE,
    rule_name TEXT NOT NULL,
    rule_description TEXT,

    severity TEXT NOT NULL DEFAULT 'all',
    incident_status TEXT NOT NULL DEFAULT 'any',

    notification_reason TEXT NOT NULL,
    channel_code TEXT NOT NULL REFERENCES public.order_lifecycle_notification_channels(channel_code),

    priority INTEGER NOT NULL DEFAULT 100,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    route_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_routing_severity
    CHECK (severity IN ('all', 'low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_analytics_alert_routing_status
    CHECK (incident_status IN ('any', 'open', 'acknowledged', 'resolved', 'ignored')),

    CONSTRAINT chk_order_lifecycle_analytics_alert_routing_reason
    CHECK (
        notification_reason IN (
            'analytics_alert_opened',
            'analytics_alert_acknowledged',
            'analytics_alert_resolved',
            'critical_analytics_alert_open',
            'high_analytics_alert_open'
        )
    )
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_routing_rules IS
'Stores routing rules for analytics alert incident notifications.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_routing_rules_code
ON public.order_lifecycle_analytics_alert_notification_routing_rules(rule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_routing_rules_enabled
ON public.order_lifecycle_analytics_alert_notification_routing_rules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_routing_rules_severity
ON public.order_lifecycle_analytics_alert_notification_routing_rules(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_routing_rules_reason
ON public.order_lifecycle_analytics_alert_notification_routing_rules(notification_reason);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_routing_rules_config
ON public.order_lifecycle_analytics_alert_notification_routing_rules USING GIN(route_config);

-- ============================================================
-- 2. Default Analytics Alert Routing Rules
-- ============================================================

INSERT INTO public.order_lifecycle_analytics_alert_notification_routing_rules (
    rule_code,
    rule_name,
    rule_description,
    severity,
    incident_status,
    notification_reason,
    channel_code,
    priority,
    is_enabled,
    route_config
)
VALUES
(
    'ROUTE_ANALYTICS_ALERT_OPEN_TO_ADMIN_DASHBOARD',
    'Route Analytics Alert Open To Admin Dashboard',
    'Creates an admin dashboard notification job when an analytics alert incident is open.',
    'all',
    'open',
    'analytics_alert_opened',
    'ADMIN_DASHBOARD',
    100,
    TRUE,
    jsonb_build_object('created_by', 'migration_114')
),
(
    'ROUTE_HIGH_ANALYTICS_ALERT_TO_ADMIN_DASHBOARD',
    'Route High Analytics Alert To Admin Dashboard',
    'Creates a higher-priority admin dashboard notification job for high analytics alert incidents.',
    'high',
    'open',
    'high_analytics_alert_open',
    'ADMIN_DASHBOARD',
    50,
    TRUE,
    jsonb_build_object('created_by', 'migration_114')
),
(
    'ROUTE_CRITICAL_ANALYTICS_ALERT_TO_ADMIN_DASHBOARD',
    'Route Critical Analytics Alert To Admin Dashboard',
    'Creates a high-priority admin dashboard notification job for critical analytics alert incidents.',
    'critical',
    'open',
    'critical_analytics_alert_open',
    'ADMIN_DASHBOARD',
    20,
    TRUE,
    jsonb_build_object('created_by', 'migration_114')
),
(
    'ROUTE_CRITICAL_ANALYTICS_ALERT_TO_IN_APP_ADMIN',
    'Route Critical Analytics Alert To In-App Admin',
    'Creates an in-app admin notification job for critical analytics alert incidents.',
    'critical',
    'open',
    'critical_analytics_alert_open',
    'IN_APP_ADMIN',
    10,
    TRUE,
    jsonb_build_object('created_by', 'migration_114')
),
(
    'ROUTE_CRITICAL_ANALYTICS_ALERT_TO_SMS',
    'Route Critical Analytics Alert To SMS',
    'Creates an SMS notification job for critical analytics alert incidents when the SMS channel is enabled.',
    'critical',
    'open',
    'critical_analytics_alert_open',
    'SMS_CRITICAL',
    5,
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_114',
        'requires_channel_enablement', TRUE
    )
),
(
    'ROUTE_ANALYTICS_ALERT_RESOLVED_TO_ADMIN_DASHBOARD',
    'Route Analytics Alert Resolved To Admin Dashboard',
    'Creates an admin dashboard notification job when an analytics alert incident is resolved.',
    'all',
    'resolved',
    'analytics_alert_resolved',
    'ADMIN_DASHBOARD',
    120,
    TRUE,
    jsonb_build_object('created_by', 'migration_114')
)
ON CONFLICT (rule_code) DO UPDATE
SET
    rule_name = EXCLUDED.rule_name,
    rule_description = EXCLUDED.rule_description,
    severity = EXCLUDED.severity,
    incident_status = EXCLUDED.incident_status,
    notification_reason = EXCLUDED.notification_reason,
    channel_code = EXCLUDED.channel_code,
    priority = EXCLUDED.priority,
    is_enabled = EXCLUDED.is_enabled,
    route_config = EXCLUDED.route_config,
    updated_at = NOW();

-- ============================================================
-- 3. Analytics Alert Notification Jobs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    incident_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_incidents(id) ON DELETE CASCADE,

    threshold_code TEXT NOT NULL,
    metric_scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,

    route_rule_code TEXT,
    channel_code TEXT NOT NULL REFERENCES public.order_lifecycle_notification_channels(channel_code),

    notification_reason TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 100,

    job_status TEXT NOT NULL DEFAULT 'pending',

    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,

    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,

    last_error TEXT,

    job_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    dedupe_key TEXT NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_notification_jobs_status
    CHECK (job_status IN ('pending', 'locked', 'sent', 'failed', 'cancelled', 'skipped')),

    CONSTRAINT chk_order_lifecycle_analytics_alert_notification_jobs_reason
    CHECK (
        notification_reason IN (
            'analytics_alert_opened',
            'analytics_alert_acknowledged',
            'analytics_alert_resolved',
            'critical_analytics_alert_open',
            'high_analytics_alert_open'
        )
    ),

    CONSTRAINT chk_order_lifecycle_analytics_alert_notification_jobs_attempts
    CHECK (attempt_count >= 0 AND max_attempts > 0)
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_jobs IS
'Stores notification jobs created from analytics alert incidents.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_incident
ON public.order_lifecycle_analytics_alert_notification_jobs(incident_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_threshold
ON public.order_lifecycle_analytics_alert_notification_jobs(threshold_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_status
ON public.order_lifecycle_analytics_alert_notification_jobs(job_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_channel
ON public.order_lifecycle_analytics_alert_notification_jobs(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_scheduled
ON public.order_lifecycle_analytics_alert_notification_jobs(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_notification_jobs_payload
ON public.order_lifecycle_analytics_alert_notification_jobs USING GIN(job_payload);

-- ============================================================
-- 4. Analytics Alert Notification Delivery Attempts
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_analytics_alert_notification_delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_notification_jobs(id) ON DELETE CASCADE,
    incident_id UUID NOT NULL REFERENCES public.order_lifecycle_analytics_alert_incidents(id) ON DELETE CASCADE,

    channel_code TEXT NOT NULL,
    attempt_status TEXT NOT NULL DEFAULT 'recorded',

    attempt_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_message TEXT,

    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_analytics_alert_delivery_attempts_status
    CHECK (attempt_status IN ('recorded', 'sent', 'failed', 'cancelled', 'skipped'))
);

COMMENT ON TABLE public.order_lifecycle_analytics_alert_notification_delivery_attempts IS
'Stores delivery attempt history for analytics alert notification jobs.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_delivery_attempts_job
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_delivery_attempts_incident
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts(incident_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_delivery_attempts_channel
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_delivery_attempts_status
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts(attempt_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_analytics_alert_delivery_attempts_payload
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts USING GIN(attempt_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_analytics_alert_notification_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_routing_rules_updated_at
ON public.order_lifecycle_analytics_alert_notification_routing_rules;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_routing_rules_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_notification_routing_rules
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_notification_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_notification_jobs_updated_at
ON public.order_lifecycle_analytics_alert_notification_jobs;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_notification_jobs_updated_at
BEFORE UPDATE ON public.order_lifecycle_analytics_alert_notification_jobs
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_analytics_alert_notification_updated_at();

-- ============================================================
-- 6. Create Analytics Alert Notification Job Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_lifecycle_analytics_alert_notification_job(
    p_incident_id UUID,
    p_route_rule_code TEXT,
    p_channel_code TEXT,
    p_notification_reason TEXT,
    p_priority INTEGER DEFAULT 100,
    p_job_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_incident RECORD;
    v_channel RECORD;
    v_job_id UUID;
    v_dedupe_key TEXT;
BEGIN
    IF p_incident_id IS NULL
       OR p_channel_code IS NULL
       OR p_notification_reason IS NULL THEN
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

    SELECT *
    INTO v_channel
    FROM public.order_lifecycle_notification_channels
    WHERE channel_code = p_channel_code
    AND is_enabled = TRUE
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_channel.critical_only = TRUE AND v_incident.severity <> 'critical' THEN
        RETURN NULL;
    END IF;

    v_dedupe_key := md5(
        concat_ws(
            '|',
            p_incident_id::TEXT,
            COALESCE(p_route_rule_code, 'manual'),
            p_channel_code,
            p_notification_reason,
            v_incident.incident_status
        )
    );

    INSERT INTO public.order_lifecycle_analytics_alert_notification_jobs (
        incident_id,
        threshold_code,
        metric_scope,
        metric_name,
        route_rule_code,
        channel_code,
        notification_reason,
        priority,
        job_status,
        scheduled_at,
        job_payload,
        dedupe_key,
        created_at,
        updated_at
    )
    VALUES (
        v_incident.id,
        v_incident.threshold_code,
        v_incident.metric_scope,
        v_incident.metric_name,
        p_route_rule_code,
        p_channel_code,
        p_notification_reason,
        COALESCE(p_priority, 100),
        'pending',
        NOW(),
        COALESCE(p_job_payload, '{}'::jsonb),
        v_dedupe_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (dedupe_key) DO UPDATE
    SET
        priority = LEAST(public.order_lifecycle_analytics_alert_notification_jobs.priority, EXCLUDED.priority),
        job_payload = EXCLUDED.job_payload,
        updated_at = NOW()
    RETURNING id INTO v_job_id;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'analytics_alert_notification_job_created',
        'recorded',
        jsonb_build_object(
            'job_id', v_job_id,
            'incident_id', v_incident.id,
            'threshold_code', v_incident.threshold_code,
            'channel_code', p_channel_code,
            'notification_reason', p_notification_reason,
            'generated_by', 'migration_114'
        ),
        NOW()
    );

    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Route Notifications For One Analytics Alert Incident
-- ============================================================

CREATE OR REPLACE FUNCTION public.route_order_lifecycle_analytics_alert_notifications_for_incident(
    p_incident_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_incident RECORD;
    v_rule RECORD;
    v_reason TEXT;
    v_created_count INTEGER := 0;
BEGIN
    IF p_incident_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT *
    INTO v_incident
    FROM public.order_lifecycle_analytics_alert_incidents
    WHERE id = p_incident_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    IF v_incident.incident_status = 'open' THEN
        v_reason := 'analytics_alert_opened';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_analytics_alert_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_incident.severity)
            AND (r.incident_status = 'any' OR r.incident_status = v_incident.incident_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
                v_incident.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'incident_id', v_incident.id,
                    'threshold_code', v_incident.threshold_code,
                    'metric_scope', v_incident.metric_scope,
                    'metric_name', v_incident.metric_name,
                    'metric_value', v_incident.metric_value,
                    'severity', v_incident.severity,
                    'incident_status', v_incident.incident_status,
                    'generated_by', 'migration_114'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    IF v_incident.severity = 'high'
       AND v_incident.incident_status IN ('open', 'acknowledged') THEN
        v_reason := 'high_analytics_alert_open';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_analytics_alert_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_incident.severity)
            AND (r.incident_status = 'any' OR r.incident_status = v_incident.incident_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
                v_incident.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'incident_id', v_incident.id,
                    'threshold_code', v_incident.threshold_code,
                    'metric_name', v_incident.metric_name,
                    'metric_value', v_incident.metric_value,
                    'severity', v_incident.severity,
                    'generated_by', 'migration_114'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    IF v_incident.severity = 'critical'
       AND v_incident.incident_status IN ('open', 'acknowledged') THEN
        v_reason := 'critical_analytics_alert_open';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_analytics_alert_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_incident.severity)
            AND (r.incident_status = 'any' OR r.incident_status = v_incident.incident_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
                v_incident.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'incident_id', v_incident.id,
                    'threshold_code', v_incident.threshold_code,
                    'metric_name', v_incident.metric_name,
                    'metric_value', v_incident.metric_value,
                    'severity', v_incident.severity,
                    'generated_by', 'migration_114'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    IF v_incident.incident_status = 'acknowledged' THEN
        v_reason := 'analytics_alert_acknowledged';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_analytics_alert_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_incident.severity)
            AND (r.incident_status = 'any' OR r.incident_status = v_incident.incident_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
                v_incident.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'incident_id', v_incident.id,
                    'threshold_code', v_incident.threshold_code,
                    'incident_status', v_incident.incident_status,
                    'generated_by', 'migration_114'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    IF v_incident.incident_status = 'resolved' THEN
        v_reason := 'analytics_alert_resolved';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_analytics_alert_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_incident.severity)
            AND (r.incident_status = 'any' OR r.incident_status = v_incident.incident_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_analytics_alert_notification_job(
                v_incident.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'incident_id', v_incident.id,
                    'threshold_code', v_incident.threshold_code,
                    'incident_status', v_incident.incident_status,
                    'resolved_at', v_incident.resolved_at,
                    'generated_by', 'migration_114'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'route_analytics_alert_notifications_for_incident',
        'completed',
        jsonb_build_object(
            'incident_id', p_incident_id,
            'created_count', v_created_count,
            'generated_by', 'migration_114'
        ),
        NOW()
    );

    RETURN v_created_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Route Notifications For All Active Analytics Alert Incidents
-- ============================================================

CREATE OR REPLACE FUNCTION public.route_all_order_lifecycle_analytics_alert_notifications()
RETURNS INTEGER AS $$
DECLARE
    v_incident RECORD;
    v_total_count INTEGER := 0;
BEGIN
    FOR v_incident IN
        SELECT id
        FROM public.order_lifecycle_analytics_alert_incidents
        WHERE incident_status IN ('open', 'acknowledged')
        ORDER BY
            CASE severity
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                ELSE 4
            END,
            last_detected_at DESC
    LOOP
        v_total_count := v_total_count
            + public.route_order_lifecycle_analytics_alert_notifications_for_incident(v_incident.id);
    END LOOP;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'route_all_analytics_alert_notifications',
        'completed',
        jsonb_build_object(
            'created_count', v_total_count,
            'generated_by', 'migration_114'
        ),
        NOW()
    );

    RETURN v_total_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Record Analytics Alert Notification Delivery Attempt
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_analytics_alert_notification_delivery_attempt(
    p_job_id UUID,
    p_attempt_status TEXT,
    p_response_payload JSONB DEFAULT '{}'::jsonb,
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_job RECORD;
    v_attempt_id UUID;
BEGIN
    IF p_job_id IS NULL OR p_attempt_status IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_attempt_status NOT IN ('recorded', 'sent', 'failed', 'cancelled', 'skipped') THEN
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

    INSERT INTO public.order_lifecycle_analytics_alert_notification_delivery_attempts (
        job_id,
        incident_id,
        channel_code,
        attempt_status,
        attempt_payload,
        response_payload,
        error_message,
        attempted_at,
        created_at
    )
    VALUES (
        v_job.id,
        v_job.incident_id,
        v_job.channel_code,
        p_attempt_status,
        v_job.job_payload,
        COALESCE(p_response_payload, '{}'::jsonb),
        p_error_message,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_attempt_id;

    UPDATE public.order_lifecycle_analytics_alert_notification_jobs
    SET
        attempt_count = attempt_count + 1,
        job_status = CASE
            WHEN p_attempt_status = 'sent' THEN 'sent'
            WHEN p_attempt_status = 'failed'
                 AND attempt_count + 1 >= max_attempts THEN 'failed'
            WHEN p_attempt_status = 'cancelled' THEN 'cancelled'
            WHEN p_attempt_status = 'skipped' THEN 'skipped'
            ELSE job_status
        END,
        sent_at = CASE
            WHEN p_attempt_status = 'sent' THEN NOW()
            ELSE sent_at
        END,
        failed_at = CASE
            WHEN p_attempt_status = 'failed'
                 AND attempt_count + 1 >= max_attempts THEN NOW()
            ELSE failed_at
        END,
        cancelled_at = CASE
            WHEN p_attempt_status = 'cancelled' THEN NOW()
            ELSE cancelled_at
        END,
        last_error = CASE
            WHEN p_error_message IS NOT NULL THEN p_error_message
            ELSE last_error
        END,
        updated_at = NOW()
    WHERE id = v_job.id;

    INSERT INTO public.order_lifecycle_notification_dispatch_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'analytics_alert_notification_delivery_attempt_recorded',
        p_attempt_status,
        jsonb_build_object(
            'job_id', v_job.id,
            'incident_id', v_job.incident_id,
            'channel_code', v_job.channel_code,
            'attempt_status', p_attempt_status,
            'generated_by', 'migration_114'
        ),
        NOW()
    );

    RETURN v_attempt_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Auto Routing Trigger
-- ============================================================

CREATE OR REPLACE FUNCTION public.order_lifecycle_analytics_alert_notification_routing_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS NOT NULL THEN
        PERFORM public.route_order_lifecycle_analytics_alert_notifications_for_incident(NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_analytics_alert_notification_routing
ON public.order_lifecycle_analytics_alert_incidents;

CREATE TRIGGER trg_order_lifecycle_analytics_alert_notification_routing
AFTER INSERT OR UPDATE ON public.order_lifecycle_analytics_alert_incidents
FOR EACH ROW
EXECUTE FUNCTION public.order_lifecycle_analytics_alert_notification_routing_trigger();

-- ============================================================
-- 11. Initial Routing Backfill
-- ============================================================

SELECT public.route_all_order_lifecycle_analytics_alert_notifications();

-- ============================================================
-- 12. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_notification_routing_dashboard_view AS
SELECT
    j.id AS job_id,
    j.incident_id,
    j.threshold_code,
    j.metric_scope,
    j.metric_name,
    j.route_rule_code,
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

    i.incident_title,
    i.severity,
    i.incident_status,
    i.metric_value,
    i.comparison_operator,
    i.threshold_value,
    i.first_detected_at,
    i.last_detected_at,

    COUNT(a.id)::INTEGER AS delivery_attempt_count,
    COUNT(a.id) FILTER (WHERE a.attempt_status = 'sent')::INTEGER AS sent_attempt_count,
    COUNT(a.id) FILTER (WHERE a.attempt_status = 'failed')::INTEGER AS failed_attempt_count,

    CASE
        WHEN j.job_status = 'sent' THEN 'sent'
        WHEN j.job_status = 'failed' THEN 'failed'
        WHEN j.job_status = 'pending' AND j.scheduled_at <= NOW() THEN 'ready'
        WHEN j.job_status = 'pending' AND j.scheduled_at > NOW() THEN 'scheduled'
        WHEN j.job_status = 'locked' THEN 'locked'
        WHEN j.job_status = 'cancelled' THEN 'cancelled'
        WHEN j.job_status = 'skipped' THEN 'skipped'
        ELSE 'other'
    END AS notification_dashboard_status,

    j.job_payload,
    j.created_at,
    j.updated_at
FROM public.order_lifecycle_analytics_alert_notification_jobs j
JOIN public.order_lifecycle_analytics_alert_incidents i
ON i.id = j.incident_id
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_analytics_alert_notification_delivery_attempts a
ON a.job_id = j.id
GROUP BY
    j.id,
    j.incident_id,
    j.threshold_code,
    j.metric_scope,
    j.metric_name,
    j.route_rule_code,
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
    i.incident_title,
    i.severity,
    i.incident_status,
    i.metric_value,
    i.comparison_operator,
    i.threshold_value,
    i.first_detected_at,
    i.last_detected_at,
    j.job_payload,
    j.created_at,
    j.updated_at;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_notification_routing_dashboard_view IS
'Admin dashboard view for analytics alert notification jobs, routing context, and delivery attempts.';

CREATE OR REPLACE VIEW public.order_lifecycle_analytics_alert_notification_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_jobs,
    COUNT(*) FILTER (WHERE job_status = 'pending')::INTEGER AS pending_jobs,
    COUNT(*) FILTER (WHERE job_status = 'locked')::INTEGER AS locked_jobs,
    COUNT(*) FILTER (WHERE job_status = 'sent')::INTEGER AS sent_jobs,
    COUNT(*) FILTER (WHERE job_status = 'failed')::INTEGER AS failed_jobs,
    COUNT(*) FILTER (WHERE job_status = 'cancelled')::INTEGER AS cancelled_jobs,
    COUNT(*) FILTER (WHERE job_status = 'skipped')::INTEGER AS skipped_jobs,

    COUNT(*) FILTER (
        WHERE job_status = 'pending'
        AND scheduled_at <= NOW()
    )::INTEGER AS ready_jobs,

    COUNT(*) FILTER (
        WHERE job_status = 'failed'
    )::INTEGER AS failed_attention_jobs,

    MAX(created_at) AS latest_job_created_at,

    CASE
        WHEN COUNT(*) = 0 THEN 'no_notifications'
        WHEN COUNT(*) FILTER (WHERE job_status = 'failed') > 0 THEN 'attention_required'
        WHEN COUNT(*) FILTER (WHERE job_status = 'pending' AND scheduled_at <= NOW()) > 0 THEN 'ready'
        WHEN COUNT(*) FILTER (WHERE job_status = 'locked') > 0 THEN 'in_progress'
        WHEN COUNT(*) FILTER (WHERE job_status = 'sent') > 0 THEN 'healthy'
        ELSE 'idle'
    END AS analytics_alert_notification_health_status
FROM public.order_lifecycle_analytics_alert_notification_jobs;

COMMENT ON VIEW public.order_lifecycle_analytics_alert_notification_health_view IS
'Shows overall health for analytics alert notification routing jobs.';

-- ============================================================
-- 13. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_analytics_alert_notification_routing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_analytics_alert_notification_delivery_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage analytics alert notification routing rules"
ON public.order_lifecycle_analytics_alert_notification_routing_rules;

CREATE POLICY "Service role can manage analytics alert notification routing rules"
ON public.order_lifecycle_analytics_alert_notification_routing_rules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage analytics alert notification jobs"
ON public.order_lifecycle_analytics_alert_notification_jobs;

CREATE POLICY "Service role can manage analytics alert notification jobs"
ON public.order_lifecycle_analytics_alert_notification_jobs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage analytics alert notification delivery attempts"
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts;

CREATE POLICY "Service role can manage analytics alert notification delivery attempts"
ON public.order_lifecycle_analytics_alert_notification_delivery_attempts
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 14. Migration Registry Marker
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
    114,
    'migration_114_order_lifecycle_analytics_alert_notification_routing',
    'Adds routing rules, notification jobs, delivery attempts, routing functions, auto-routing trigger, and dashboard views for analytics alert incidents.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
