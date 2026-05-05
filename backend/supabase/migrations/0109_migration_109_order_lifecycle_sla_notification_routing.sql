-- Migration 109: Order Lifecycle SLA Notification Routing
-- Purpose:
-- Adds notification channel registry, SLA routing rules, notification jobs,
-- delivery attempts, routing functions, and dashboard view for SLA alerts.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Notification Channel Registry
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_notification_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    channel_code TEXT NOT NULL UNIQUE,
    channel_name TEXT NOT NULL,
    channel_type TEXT NOT NULL DEFAULT 'admin_dashboard',

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    critical_only BOOLEAN NOT NULL DEFAULT FALSE,

    channel_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_notification_channels_type
    CHECK (
        channel_type IN (
            'admin_dashboard',
            'in_app',
            'email',
            'sms',
            'webhook',
            'whatsapp',
            'wechat'
        )
    )
);

COMMENT ON TABLE public.order_lifecycle_notification_channels IS
'Stores available notification channels for order lifecycle SLA alerts.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_channels_code
ON public.order_lifecycle_notification_channels(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_channels_enabled
ON public.order_lifecycle_notification_channels(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_notification_channels_config
ON public.order_lifecycle_notification_channels USING GIN(channel_config);

-- ============================================================
-- 2. Default Notification Channels
-- ============================================================

INSERT INTO public.order_lifecycle_notification_channels (
    channel_code,
    channel_name,
    channel_type,
    is_enabled,
    critical_only,
    channel_config
)
VALUES
(
    'ADMIN_DASHBOARD',
    'Admin Dashboard',
    'admin_dashboard',
    TRUE,
    FALSE,
    jsonb_build_object('created_by', 'migration_109')
),
(
    'IN_APP_ADMIN',
    'In-App Admin Alert',
    'in_app',
    TRUE,
    FALSE,
    jsonb_build_object('created_by', 'migration_109')
),
(
    'EMAIL_OPERATIONS',
    'Operations Email Alert',
    'email',
    FALSE,
    FALSE,
    jsonb_build_object(
        'created_by', 'migration_109',
        'enabled_by_default', FALSE,
        'note', 'Enable after email delivery provider is connected.'
    )
),
(
    'SMS_CRITICAL',
    'Critical SMS Alert',
    'sms',
    FALSE,
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_109',
        'enabled_by_default', FALSE,
        'note', 'Enable after SMS provider is connected.'
    )
)
ON CONFLICT (channel_code) DO UPDATE
SET
    channel_name = EXCLUDED.channel_name,
    channel_type = EXCLUDED.channel_type,
    is_enabled = EXCLUDED.is_enabled,
    critical_only = EXCLUDED.critical_only,
    channel_config = EXCLUDED.channel_config,
    updated_at = NOW();

-- ============================================================
-- 3. SLA Notification Routing Rules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_sla_notification_routing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL UNIQUE,
    rule_name TEXT NOT NULL,
    rule_description TEXT,

    severity TEXT NOT NULL DEFAULT 'all',
    sla_status TEXT NOT NULL DEFAULT 'any',
    notification_reason TEXT NOT NULL,

    channel_code TEXT NOT NULL REFERENCES public.order_lifecycle_notification_channels(channel_code),

    priority INTEGER NOT NULL DEFAULT 100,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    route_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_sla_routing_rules_severity
    CHECK (severity IN ('all', 'low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_sla_routing_rules_sla_status
    CHECK (sla_status IN ('any', 'active', 'responded', 'resolved', 'breached', 'escalated', 'ignored')),

    CONSTRAINT chk_order_lifecycle_sla_routing_rules_reason
    CHECK (
        notification_reason IN (
            'sla_created',
            'response_due_soon',
            'resolution_due_soon',
            'escalation_due_soon',
            'sla_breached',
            'critical_exception_open',
            'exception_resolved'
        )
    )
);

COMMENT ON TABLE public.order_lifecycle_sla_notification_routing_rules IS
'Stores routing rules that decide which notification channels receive SLA alert jobs.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_routing_rules_code
ON public.order_lifecycle_sla_notification_routing_rules(rule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_routing_rules_enabled
ON public.order_lifecycle_sla_notification_routing_rules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_routing_rules_severity
ON public.order_lifecycle_sla_notification_routing_rules(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_routing_rules_reason
ON public.order_lifecycle_sla_notification_routing_rules(notification_reason);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_routing_rules_config
ON public.order_lifecycle_sla_notification_routing_rules USING GIN(route_config);

-- ============================================================
-- 4. Default Routing Rules
-- ============================================================

INSERT INTO public.order_lifecycle_sla_notification_routing_rules (
    rule_code,
    rule_name,
    rule_description,
    severity,
    sla_status,
    notification_reason,
    channel_code,
    priority,
    is_enabled,
    route_config
)
VALUES
(
    'ROUTE_ALL_CREATED_TO_ADMIN_DASHBOARD',
    'Route Created SLA Items To Admin Dashboard',
    'Creates admin dashboard notification jobs for newly tracked SLA items.',
    'all',
    'any',
    'sla_created',
    'ADMIN_DASHBOARD',
    100,
    TRUE,
    jsonb_build_object('created_by', 'migration_109')
),
(
    'ROUTE_DUE_SOON_TO_ADMIN_DASHBOARD',
    'Route Due Soon SLA Items To Admin Dashboard',
    'Creates admin dashboard notification jobs when SLA resolution is due soon.',
    'all',
    'any',
    'resolution_due_soon',
    'ADMIN_DASHBOARD',
    80,
    TRUE,
    jsonb_build_object('created_by', 'migration_109', 'due_soon_hours', 6)
),
(
    'ROUTE_BREACH_TO_ADMIN_DASHBOARD',
    'Route SLA Breaches To Admin Dashboard',
    'Creates admin dashboard notification jobs when SLA breach is detected.',
    'all',
    'breached',
    'sla_breached',
    'ADMIN_DASHBOARD',
    30,
    TRUE,
    jsonb_build_object('created_by', 'migration_109')
),
(
    'ROUTE_CRITICAL_TO_IN_APP_ADMIN',
    'Route Critical Exceptions To In-App Admin',
    'Creates in-app admin alert jobs for critical open exceptions.',
    'critical',
    'any',
    'critical_exception_open',
    'IN_APP_ADMIN',
    20,
    TRUE,
    jsonb_build_object('created_by', 'migration_109')
),
(
    'ROUTE_CRITICAL_BREACH_TO_SMS',
    'Route Critical SLA Breaches To SMS',
    'Creates SMS notification jobs for critical SLA breaches when SMS channel is enabled.',
    'critical',
    'breached',
    'sla_breached',
    'SMS_CRITICAL',
    10,
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_109',
        'requires_channel_enablement', TRUE
    )
)
ON CONFLICT (rule_code) DO UPDATE
SET
    rule_name = EXCLUDED.rule_name,
    rule_description = EXCLUDED.rule_description,
    severity = EXCLUDED.severity,
    sla_status = EXCLUDED.sla_status,
    notification_reason = EXCLUDED.notification_reason,
    channel_code = EXCLUDED.channel_code,
    priority = EXCLUDED.priority,
    is_enabled = EXCLUDED.is_enabled,
    route_config = EXCLUDED.route_config,
    updated_at = NOW();

-- ============================================================
-- 5. SLA Notification Jobs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_sla_notification_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exception_id UUID NOT NULL REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    sla_tracking_id UUID REFERENCES public.order_lifecycle_exception_sla_tracking(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

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

    CONSTRAINT chk_order_lifecycle_sla_notification_jobs_status
    CHECK (job_status IN ('pending', 'locked', 'sent', 'failed', 'cancelled', 'skipped')),

    CONSTRAINT chk_order_lifecycle_sla_notification_jobs_reason
    CHECK (
        notification_reason IN (
            'sla_created',
            'response_due_soon',
            'resolution_due_soon',
            'escalation_due_soon',
            'sla_breached',
            'critical_exception_open',
            'exception_resolved'
        )
    )
);

COMMENT ON TABLE public.order_lifecycle_sla_notification_jobs IS
'Stores queued notification jobs created from order lifecycle SLA routing rules.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_exception_id
ON public.order_lifecycle_sla_notification_jobs(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_order_id
ON public.order_lifecycle_sla_notification_jobs(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_status
ON public.order_lifecycle_sla_notification_jobs(job_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_channel
ON public.order_lifecycle_sla_notification_jobs(channel_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_scheduled_at
ON public.order_lifecycle_sla_notification_jobs(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_notification_jobs_payload
ON public.order_lifecycle_sla_notification_jobs USING GIN(job_payload);

-- ============================================================
-- 6. SLA Notification Delivery Attempts
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_sla_notification_delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id UUID NOT NULL REFERENCES public.order_lifecycle_sla_notification_jobs(id) ON DELETE CASCADE,
    exception_id UUID NOT NULL REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

    channel_code TEXT NOT NULL,
    attempt_status TEXT NOT NULL DEFAULT 'recorded',

    attempt_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_message TEXT,

    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_sla_delivery_attempts_status
    CHECK (attempt_status IN ('recorded', 'sent', 'failed', 'cancelled', 'skipped'))
);

COMMENT ON TABLE public.order_lifecycle_sla_notification_delivery_attempts IS
'Stores delivery attempt history for SLA notification jobs.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_delivery_attempts_job_id
ON public.order_lifecycle_sla_notification_delivery_attempts(job_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_delivery_attempts_exception_id
ON public.order_lifecycle_sla_notification_delivery_attempts(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_delivery_attempts_order_id
ON public.order_lifecycle_sla_notification_delivery_attempts(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_delivery_attempts_status
ON public.order_lifecycle_sla_notification_delivery_attempts(attempt_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_sla_delivery_attempts_payload
ON public.order_lifecycle_sla_notification_delivery_attempts USING GIN(attempt_payload);

-- ============================================================
-- 7. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_sla_notification_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_notification_channels_updated_at
ON public.order_lifecycle_notification_channels;

CREATE TRIGGER trg_order_lifecycle_notification_channels_updated_at
BEFORE UPDATE ON public.order_lifecycle_notification_channels
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_sla_notification_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_sla_routing_rules_updated_at
ON public.order_lifecycle_sla_notification_routing_rules;

CREATE TRIGGER trg_order_lifecycle_sla_routing_rules_updated_at
BEFORE UPDATE ON public.order_lifecycle_sla_notification_routing_rules
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_sla_notification_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_sla_notification_jobs_updated_at
ON public.order_lifecycle_sla_notification_jobs;

CREATE TRIGGER trg_order_lifecycle_sla_notification_jobs_updated_at
BEFORE UPDATE ON public.order_lifecycle_sla_notification_jobs
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_sla_notification_updated_at();

-- ============================================================
-- 8. Create SLA Notification Job Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_lifecycle_sla_notification_job(
    p_exception_id UUID,
    p_sla_tracking_id UUID,
    p_route_rule_code TEXT,
    p_channel_code TEXT,
    p_notification_reason TEXT,
    p_priority INTEGER DEFAULT 100,
    p_job_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_exception RECORD;
    v_channel RECORD;
    v_job_id UUID;
    v_dedupe_key TEXT;
    v_alert_dedupe_key TEXT;
BEGIN
    IF p_exception_id IS NULL OR p_channel_code IS NULL OR p_notification_reason IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_exception
    FROM public.order_lifecycle_exception_queue
    WHERE id = p_exception_id
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

    IF v_channel.critical_only = TRUE AND v_exception.severity <> 'critical' THEN
        RETURN NULL;
    END IF;

    v_dedupe_key := md5(
        concat_ws(
            '|',
            p_exception_id::TEXT,
            COALESCE(p_sla_tracking_id::TEXT, 'no_sla_tracking'),
            COALESCE(p_route_rule_code, 'manual'),
            p_channel_code,
            p_notification_reason
        )
    );

    INSERT INTO public.order_lifecycle_sla_notification_jobs (
        exception_id,
        sla_tracking_id,
        order_id,
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
        v_exception.id,
        p_sla_tracking_id,
        v_exception.order_id,
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
        priority = LEAST(public.order_lifecycle_sla_notification_jobs.priority, EXCLUDED.priority),
        job_payload = EXCLUDED.job_payload,
        updated_at = NOW()
    RETURNING id INTO v_job_id;

    -- Also mirror to the existing alert notification table from Migration 107.
    v_alert_dedupe_key := v_dedupe_key || ':alert_notification';

    INSERT INTO public.order_lifecycle_alert_notifications (
        exception_id,
        order_id,
        notification_channel,
        notification_status,
        recipient_type,
        notification_payload,
        dedupe_key,
        created_at,
        updated_at
    )
    VALUES (
        v_exception.id,
        v_exception.order_id,
        lower(p_channel_code),
        'pending',
        'admin',
        jsonb_build_object(
            'exception_id', v_exception.id,
            'order_id', v_exception.order_id,
            'route_rule_code', p_route_rule_code,
            'channel_code', p_channel_code,
            'notification_reason', p_notification_reason,
            'severity', v_exception.severity,
            'generated_by', 'migration_109'
        ),
        v_alert_dedupe_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (dedupe_key) DO NOTHING;

    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Route SLA Notifications For One Exception
-- ============================================================

CREATE OR REPLACE FUNCTION public.route_order_lifecycle_sla_notifications_for_exception(
    p_exception_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_exception RECORD;
    v_sla RECORD;
    v_rule RECORD;
    v_reason TEXT;
    v_created_count INTEGER := 0;
BEGIN
    IF p_exception_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT *
    INTO v_exception
    FROM public.order_lifecycle_exception_queue
    WHERE id = p_exception_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    SELECT *
    INTO v_sla
    FROM public.order_lifecycle_exception_sla_tracking
    WHERE exception_id = p_exception_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Reason 1: SLA created or active
    IF v_sla.sla_status IN ('active', 'responded') THEN
        v_reason := 'sla_created';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_sla_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_exception.severity)
            AND (r.sla_status = 'any' OR r.sla_status = v_sla.sla_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_sla_notification_job(
                v_exception.id,
                v_sla.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'exception_id', v_exception.id,
                    'order_id', v_exception.order_id,
                    'severity', v_exception.severity,
                    'sla_status', v_sla.sla_status,
                    'generated_by', 'migration_109'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    -- Reason 2: Resolution due soon
    IF v_sla.sla_status NOT IN ('resolved', 'ignored')
    AND v_sla.resolution_due_at IS NOT NULL
    AND v_sla.resolution_due_at < NOW() + INTERVAL '6 hours'
    AND v_sla.resolution_due_at >= NOW() THEN
        v_reason := 'resolution_due_soon';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_sla_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_exception.severity)
            AND (r.sla_status = 'any' OR r.sla_status = v_sla.sla_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_sla_notification_job(
                v_exception.id,
                v_sla.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'exception_id', v_exception.id,
                    'order_id', v_exception.order_id,
                    'severity', v_exception.severity,
                    'sla_status', v_sla.sla_status,
                    'resolution_due_at', v_sla.resolution_due_at,
                    'generated_by', 'migration_109'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    -- Reason 3: SLA breached
    IF v_sla.sla_status = 'breached'
    OR v_sla.response_breached = TRUE
    OR v_sla.resolution_breached = TRUE
    OR v_sla.escalation_breached = TRUE THEN
        v_reason := 'sla_breached';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_sla_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_exception.severity)
            AND (r.sla_status = 'any' OR r.sla_status = v_sla.sla_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_sla_notification_job(
                v_exception.id,
                v_sla.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'exception_id', v_exception.id,
                    'order_id', v_exception.order_id,
                    'severity', v_exception.severity,
                    'sla_status', v_sla.sla_status,
                    'response_breached', v_sla.response_breached,
                    'resolution_breached', v_sla.resolution_breached,
                    'escalation_breached', v_sla.escalation_breached,
                    'generated_by', 'migration_109'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    -- Reason 4: Critical exception open
    IF v_exception.severity = 'critical'
    AND v_exception.queue_status IN ('open', 'in_review', 'escalated') THEN
        v_reason := 'critical_exception_open';

        FOR v_rule IN
            SELECT r.*
            FROM public.order_lifecycle_sla_notification_routing_rules r
            JOIN public.order_lifecycle_notification_channels c
            ON c.channel_code = r.channel_code
            WHERE r.is_enabled = TRUE
            AND c.is_enabled = TRUE
            AND r.notification_reason = v_reason
            AND (r.severity = 'all' OR r.severity = v_exception.severity)
            AND (r.sla_status = 'any' OR r.sla_status = v_sla.sla_status)
            ORDER BY r.priority ASC
        LOOP
            PERFORM public.create_order_lifecycle_sla_notification_job(
                v_exception.id,
                v_sla.id,
                v_rule.rule_code,
                v_rule.channel_code,
                v_reason,
                v_rule.priority,
                jsonb_build_object(
                    'reason', v_reason,
                    'exception_id', v_exception.id,
                    'order_id', v_exception.order_id,
                    'severity', v_exception.severity,
                    'queue_status', v_exception.queue_status,
                    'sla_status', v_sla.sla_status,
                    'generated_by', 'migration_109'
                )
            );

            v_created_count := v_created_count + 1;
        END LOOP;
    END IF;

    RETURN v_created_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Route SLA Notifications For All Exceptions
-- ============================================================

CREATE OR REPLACE FUNCTION public.route_all_order_lifecycle_sla_notifications()
RETURNS INTEGER AS $$
DECLARE
    v_exception RECORD;
    v_total_count INTEGER := 0;
BEGIN
    FOR v_exception IN
        SELECT DISTINCT q.id
        FROM public.order_lifecycle_exception_queue q
        JOIN public.order_lifecycle_exception_sla_tracking s
        ON s.exception_id = q.id
        WHERE q.queue_status NOT IN ('resolved', 'ignored')
    LOOP
        v_total_count := v_total_count
            + public.route_order_lifecycle_sla_notifications_for_exception(v_exception.id);
    END LOOP;

    RETURN v_total_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. Record Notification Delivery Attempt Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_sla_notification_delivery_attempt(
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

    SELECT *
    INTO v_job
    FROM public.order_lifecycle_sla_notification_jobs
    WHERE id = p_job_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.order_lifecycle_sla_notification_delivery_attempts (
        job_id,
        exception_id,
        order_id,
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
        v_job.exception_id,
        v_job.order_id,
        v_job.channel_code,
        p_attempt_status,
        v_job.job_payload,
        COALESCE(p_response_payload, '{}'::jsonb),
        p_error_message,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_attempt_id;

    UPDATE public.order_lifecycle_sla_notification_jobs
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

    RETURN v_attempt_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 12. Auto Routing Trigger
-- ============================================================

CREATE OR REPLACE FUNCTION public.order_lifecycle_sla_notification_routing_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.exception_id IS NOT NULL THEN
        PERFORM public.route_order_lifecycle_sla_notifications_for_exception(NEW.exception_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_sla_notification_routing
ON public.order_lifecycle_exception_sla_tracking;

CREATE TRIGGER trg_order_lifecycle_sla_notification_routing
AFTER INSERT OR UPDATE ON public.order_lifecycle_exception_sla_tracking
FOR EACH ROW
EXECUTE FUNCTION public.order_lifecycle_sla_notification_routing_trigger();

-- ============================================================
-- 13. Backfill Initial Routing Jobs
-- ============================================================

SELECT public.route_all_order_lifecycle_sla_notifications();

-- ============================================================
-- 14. Notification Routing Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_sla_notification_routing_dashboard_view AS
SELECT
    j.id AS job_id,
    j.exception_id,
    j.sla_tracking_id,
    j.order_id,
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

    q.rule_code AS exception_rule_code,
    q.exception_type,
    q.severity,
    q.queue_status,
    q.title AS exception_title,

    s.sla_status,
    s.response_due_at,
    s.resolution_due_at,
    s.escalation_due_at,
    s.response_breached,
    s.resolution_breached,
    s.escalation_breached,

    COUNT(a.id) AS delivery_attempt_count,
    COUNT(a.id) FILTER (WHERE a.attempt_status = 'sent') AS sent_attempt_count,
    COUNT(a.id) FILTER (WHERE a.attempt_status = 'failed') AS failed_attempt_count,

    j.job_payload,
    j.created_at,
    j.updated_at
FROM public.order_lifecycle_sla_notification_jobs j
JOIN public.order_lifecycle_exception_queue q
ON q.id = j.exception_id
LEFT JOIN public.order_lifecycle_exception_sla_tracking s
ON s.id = j.sla_tracking_id
LEFT JOIN public.order_lifecycle_notification_channels c
ON c.channel_code = j.channel_code
LEFT JOIN public.order_lifecycle_sla_notification_delivery_attempts a
ON a.job_id = j.id
GROUP BY
    j.id,
    j.exception_id,
    j.sla_tracking_id,
    j.order_id,
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
    q.rule_code,
    q.exception_type,
    q.severity,
    q.queue_status,
    q.title,
    s.sla_status,
    s.response_due_at,
    s.resolution_due_at,
    s.escalation_due_at,
    s.response_breached,
    s.resolution_breached,
    s.escalation_breached,
    j.job_payload,
    j.created_at,
    j.updated_at;

COMMENT ON VIEW public.order_lifecycle_sla_notification_routing_dashboard_view IS
'Admin dashboard view for SLA notification routing jobs, delivery status, and exception context.';

-- ============================================================
-- 15. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_notification_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_sla_notification_routing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_sla_notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_sla_notification_delivery_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle notification channels"
ON public.order_lifecycle_notification_channels;

CREATE POLICY "Service role can manage order lifecycle notification channels"
ON public.order_lifecycle_notification_channels
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle SLA routing rules"
ON public.order_lifecycle_sla_notification_routing_rules;

CREATE POLICY "Service role can manage order lifecycle SLA routing rules"
ON public.order_lifecycle_sla_notification_routing_rules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle SLA notification jobs"
ON public.order_lifecycle_sla_notification_jobs;

CREATE POLICY "Service role can manage order lifecycle SLA notification jobs"
ON public.order_lifecycle_sla_notification_jobs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle SLA notification delivery attempts"
ON public.order_lifecycle_sla_notification_delivery_attempts;

CREATE POLICY "Service role can manage order lifecycle SLA notification delivery attempts"
ON public.order_lifecycle_sla_notification_delivery_attempts
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 16. Migration Registry Marker
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
    109,
    'migration_109_order_lifecycle_sla_notification_routing',
    'Adds notification channel registry, SLA routing rules, notification jobs, delivery attempts, routing functions, and dashboard view for SLA alerts.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
