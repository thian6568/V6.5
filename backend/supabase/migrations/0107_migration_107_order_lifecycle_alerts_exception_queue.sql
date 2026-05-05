-- Migration 107: Order Lifecycle Alerts Exception Queue
-- Purpose:
-- Adds alert rules, exception queue, notification tracking, and auto-evaluation
-- support for order lifecycle reporting issues after Migration 106.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Order Lifecycle Alert Rules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_alert_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL UNIQUE,
    rule_name TEXT NOT NULL,
    rule_description TEXT,

    severity TEXT NOT NULL DEFAULT 'medium',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    rule_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_alert_rules_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE public.order_lifecycle_alert_rules IS
'Stores configurable alert rules for order lifecycle reporting, export, and delivery exception detection.';

COMMENT ON COLUMN public.order_lifecycle_alert_rules.rule_code IS
'Stable system rule code used by alert evaluation functions.';

COMMENT ON COLUMN public.order_lifecycle_alert_rules.rule_config IS
'Flexible JSON configuration for threshold-based alert rules.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_rules_rule_code
ON public.order_lifecycle_alert_rules(rule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_rules_enabled
ON public.order_lifecycle_alert_rules(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_rules_config
ON public.order_lifecycle_alert_rules USING GIN(rule_config);

-- ============================================================
-- 2. Default Alert Rules
-- ============================================================

INSERT INTO public.order_lifecycle_alert_rules (
    rule_code,
    rule_name,
    rule_description,
    severity,
    is_enabled,
    rule_config
)
VALUES
(
    'FAILED_CHECKPOINT_DETECTED',
    'Failed Checkpoint Detected',
    'Creates an exception when an order has one or more failed or cancelled export/delivery checkpoints.',
    'critical',
    TRUE,
    jsonb_build_object(
        'failed_statuses', jsonb_build_array('failed', 'cancelled')
    )
),
(
    'PENDING_CHECKPOINT_DELAYED',
    'Pending Checkpoint Delayed',
    'Creates an exception when an order has pending checkpoints older than the configured threshold.',
    'medium',
    TRUE,
    jsonb_build_object(
        'pending_threshold_hours', 48
    )
),
(
    'FAILED_EVENT_STATUS_DETECTED',
    'Failed Event Status Detected',
    'Creates an exception when the latest lifecycle event status indicates a failure or cancellation.',
    'high',
    TRUE,
    jsonb_build_object(
        'failed_event_statuses', jsonb_build_array('failed', 'error', 'cancelled')
    )
),
(
    'CHECKPOINT_WITHOUT_EVENT',
    'Checkpoint Without Lifecycle Event',
    'Creates an exception when checkpoints exist but no lifecycle audit event exists for the order.',
    'low',
    TRUE,
    jsonb_build_object(
        'expected_minimum_lifecycle_events', 1
    )
)
ON CONFLICT (rule_code) DO UPDATE
SET
    rule_name = EXCLUDED.rule_name,
    rule_description = EXCLUDED.rule_description,
    severity = EXCLUDED.severity,
    is_enabled = EXCLUDED.is_enabled,
    rule_config = EXCLUDED.rule_config,
    updated_at = NOW();

-- ============================================================
-- 3. Order Lifecycle Exception Queue
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_exception_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID NOT NULL,

    rule_code TEXT NOT NULL,
    exception_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'medium',

    queue_status TEXT NOT NULL DEFAULT 'open',

    title TEXT NOT NULL,
    description TEXT,

    source_event_type TEXT,
    source_event_status TEXT,
    source_checkpoint_type TEXT,
    source_checkpoint_status TEXT,

    source_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    assigned_to UUID,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,
    resolution_notes TEXT,

    dedupe_key TEXT NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_exception_queue_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_exception_queue_status
    CHECK (queue_status IN ('open', 'in_review', 'resolved', 'ignored', 'escalated'))
);

COMMENT ON TABLE public.order_lifecycle_exception_queue IS
'Stores order lifecycle exceptions requiring admin review, escalation, or resolution.';

COMMENT ON COLUMN public.order_lifecycle_exception_queue.dedupe_key IS
'Prevents duplicate open exceptions for the same order and rule condition.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_order_id
ON public.order_lifecycle_exception_queue(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_rule_code
ON public.order_lifecycle_exception_queue(rule_code);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_status
ON public.order_lifecycle_exception_queue(queue_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_severity
ON public.order_lifecycle_exception_queue(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_created_at
ON public.order_lifecycle_exception_queue(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_queue_payload
ON public.order_lifecycle_exception_queue USING GIN(source_payload);

-- ============================================================
-- 4. Order Lifecycle Alert Notifications
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_alert_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exception_id UUID NOT NULL REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

    notification_channel TEXT NOT NULL DEFAULT 'admin_dashboard',
    notification_status TEXT NOT NULL DEFAULT 'pending',

    recipient_type TEXT NOT NULL DEFAULT 'admin',
    recipient_id UUID,

    notification_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    dedupe_key TEXT NOT NULL UNIQUE,

    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_alert_notifications_status
    CHECK (notification_status IN ('pending', 'sent', 'failed', 'cancelled'))
);

COMMENT ON TABLE public.order_lifecycle_alert_notifications IS
'Tracks notification records generated from order lifecycle exception queue items.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_notifications_exception_id
ON public.order_lifecycle_alert_notifications(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_notifications_order_id
ON public.order_lifecycle_alert_notifications(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_notifications_status
ON public.order_lifecycle_alert_notifications(notification_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_notifications_channel
ON public.order_lifecycle_alert_notifications(notification_channel);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_alert_notifications_payload
ON public.order_lifecycle_alert_notifications USING GIN(notification_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_alerts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_alert_rules_updated_at
ON public.order_lifecycle_alert_rules;

CREATE TRIGGER trg_order_lifecycle_alert_rules_updated_at
BEFORE UPDATE ON public.order_lifecycle_alert_rules
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_alerts_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_exception_queue_updated_at
ON public.order_lifecycle_exception_queue;

CREATE TRIGGER trg_order_lifecycle_exception_queue_updated_at
BEFORE UPDATE ON public.order_lifecycle_exception_queue
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_alerts_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_alert_notifications_updated_at
ON public.order_lifecycle_alert_notifications;

CREATE TRIGGER trg_order_lifecycle_alert_notifications_updated_at
BEFORE UPDATE ON public.order_lifecycle_alert_notifications
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_alerts_updated_at();

-- ============================================================
-- 6. Enqueue Exception Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.enqueue_order_lifecycle_exception(
    p_order_id UUID,
    p_rule_code TEXT,
    p_exception_type TEXT,
    p_severity TEXT,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_source_payload JSONB DEFAULT '{}'::jsonb,
    p_source_event_type TEXT DEFAULT NULL,
    p_source_event_status TEXT DEFAULT NULL,
    p_source_checkpoint_type TEXT DEFAULT NULL,
    p_source_checkpoint_status TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_exception_id UUID;
    v_dedupe_key TEXT;
    v_notification_dedupe_key TEXT;
BEGIN
    IF p_order_id IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_rule_code IS NULL OR p_exception_type IS NULL OR p_title IS NULL THEN
        RETURN NULL;
    END IF;

    v_dedupe_key := md5(
        concat_ws(
            '|',
            p_order_id::TEXT,
            p_rule_code,
            p_exception_type
        )
    );

    INSERT INTO public.order_lifecycle_exception_queue (
        order_id,
        rule_code,
        exception_type,
        severity,
        queue_status,
        title,
        description,
        source_event_type,
        source_event_status,
        source_checkpoint_type,
        source_checkpoint_status,
        source_payload,
        dedupe_key,
        created_at,
        updated_at
    )
    VALUES (
        p_order_id,
        p_rule_code,
        p_exception_type,
        COALESCE(p_severity, 'medium'),
        'open',
        p_title,
        p_description,
        p_source_event_type,
        p_source_event_status,
        p_source_checkpoint_type,
        p_source_checkpoint_status,
        COALESCE(p_source_payload, '{}'::jsonb),
        v_dedupe_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (dedupe_key) DO UPDATE
    SET
        severity = EXCLUDED.severity,
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        source_event_type = EXCLUDED.source_event_type,
        source_event_status = EXCLUDED.source_event_status,
        source_checkpoint_type = EXCLUDED.source_checkpoint_type,
        source_checkpoint_status = EXCLUDED.source_checkpoint_status,
        source_payload = EXCLUDED.source_payload,
        queue_status = CASE
            WHEN public.order_lifecycle_exception_queue.queue_status IN ('resolved', 'ignored')
            THEN public.order_lifecycle_exception_queue.queue_status
            ELSE 'open'
        END,
        updated_at = NOW()
    RETURNING id INTO v_exception_id;

    v_notification_dedupe_key := v_dedupe_key || ':admin_dashboard';

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
        v_exception_id,
        p_order_id,
        'admin_dashboard',
        'pending',
        'admin',
        jsonb_build_object(
            'order_id', p_order_id,
            'rule_code', p_rule_code,
            'exception_type', p_exception_type,
            'severity', COALESCE(p_severity, 'medium'),
            'title', p_title,
            'generated_by', 'migration_107'
        ),
        v_notification_dedupe_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (dedupe_key) DO NOTHING;

    RETURN v_exception_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Evaluate Reporting Read Model Alerts
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_order_lifecycle_alerts_for_order(
    p_order_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_report RECORD;
    v_created_count INTEGER := 0;
    v_pending_threshold_hours INTEGER := 48;
BEGIN
    IF p_order_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT *
    INTO v_report
    FROM public.order_lifecycle_reporting_read_models
    WHERE order_id = p_order_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Rule 1: Failed checkpoint detected
    IF EXISTS (
        SELECT 1
        FROM public.order_lifecycle_alert_rules
        WHERE rule_code = 'FAILED_CHECKPOINT_DETECTED'
        AND is_enabled = TRUE
    )
    AND COALESCE(v_report.failed_checkpoints, 0) > 0 THEN
        PERFORM public.enqueue_order_lifecycle_exception(
            p_order_id,
            'FAILED_CHECKPOINT_DETECTED',
            'checkpoint_failure',
            'critical',
            'Failed order lifecycle checkpoint detected',
            'One or more export or delivery checkpoints failed or were cancelled.',
            v_report.report_payload,
            v_report.latest_event_type,
            v_report.latest_event_status,
            v_report.latest_checkpoint_type,
            v_report.latest_checkpoint_status
        );

        v_created_count := v_created_count + 1;
    END IF;

    -- Rule 2: Pending checkpoint delayed
    SELECT
        COALESCE((rule_config ->> 'pending_threshold_hours')::INTEGER, 48)
    INTO v_pending_threshold_hours
    FROM public.order_lifecycle_alert_rules
    WHERE rule_code = 'PENDING_CHECKPOINT_DELAYED'
    AND is_enabled = TRUE
    LIMIT 1;

    IF v_pending_threshold_hours IS NULL THEN
        v_pending_threshold_hours := 48;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.order_lifecycle_alert_rules
        WHERE rule_code = 'PENDING_CHECKPOINT_DELAYED'
        AND is_enabled = TRUE
    )
    AND COALESCE(v_report.pending_checkpoints, 0) > 0
    AND v_report.last_checkpoint_at IS NOT NULL
    AND v_report.last_checkpoint_at < NOW() - make_interval(hours => v_pending_threshold_hours) THEN
        PERFORM public.enqueue_order_lifecycle_exception(
            p_order_id,
            'PENDING_CHECKPOINT_DELAYED',
            'checkpoint_delay',
            'medium',
            'Pending order lifecycle checkpoint delayed',
            'One or more export or delivery checkpoints are still pending beyond the configured threshold.',
            v_report.report_payload,
            v_report.latest_event_type,
            v_report.latest_event_status,
            v_report.latest_checkpoint_type,
            v_report.latest_checkpoint_status
        );

        v_created_count := v_created_count + 1;
    END IF;

    -- Rule 3: Failed lifecycle event status detected
    IF EXISTS (
        SELECT 1
        FROM public.order_lifecycle_alert_rules
        WHERE rule_code = 'FAILED_EVENT_STATUS_DETECTED'
        AND is_enabled = TRUE
    )
    AND v_report.latest_event_status IN ('failed', 'error', 'cancelled') THEN
        PERFORM public.enqueue_order_lifecycle_exception(
            p_order_id,
            'FAILED_EVENT_STATUS_DETECTED',
            'event_status_failure',
            'high',
            'Failed order lifecycle event status detected',
            'The latest lifecycle event status indicates a failure, error, or cancellation.',
            v_report.report_payload,
            v_report.latest_event_type,
            v_report.latest_event_status,
            v_report.latest_checkpoint_type,
            v_report.latest_checkpoint_status
        );

        v_created_count := v_created_count + 1;
    END IF;

    -- Rule 4: Checkpoint exists without lifecycle event
    IF EXISTS (
        SELECT 1
        FROM public.order_lifecycle_alert_rules
        WHERE rule_code = 'CHECKPOINT_WITHOUT_EVENT'
        AND is_enabled = TRUE
    )
    AND COALESCE(v_report.total_checkpoints, 0) > 0
    AND COALESCE(v_report.total_lifecycle_events, 0) = 0 THEN
        PERFORM public.enqueue_order_lifecycle_exception(
            p_order_id,
            'CHECKPOINT_WITHOUT_EVENT',
            'missing_lifecycle_event',
            'low',
            'Checkpoint exists without lifecycle audit event',
            'This order has export or delivery checkpoints but no lifecycle audit events.',
            v_report.report_payload,
            v_report.latest_event_type,
            v_report.latest_event_status,
            v_report.latest_checkpoint_type,
            v_report.latest_checkpoint_status
        );

        v_created_count := v_created_count + 1;
    END IF;

    RETURN v_created_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Evaluate All Orders Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_all_order_lifecycle_alerts()
RETURNS INTEGER AS $$
DECLARE
    v_order RECORD;
    v_total_count INTEGER := 0;
BEGIN
    FOR v_order IN
        SELECT order_id
        FROM public.order_lifecycle_reporting_read_models
        WHERE order_id IS NOT NULL
    LOOP
        v_total_count := v_total_count + public.evaluate_order_lifecycle_alerts_for_order(v_order.order_id);
    END LOOP;

    RETURN v_total_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Auto-Evaluate Trigger For Reporting Read Models
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_order_lifecycle_alerts_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_id IS NOT NULL THEN
        PERFORM public.evaluate_order_lifecycle_alerts_for_order(NEW.order_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_reporting_alert_evaluation
ON public.order_lifecycle_reporting_read_models;

CREATE TRIGGER trg_order_lifecycle_reporting_alert_evaluation
AFTER INSERT OR UPDATE ON public.order_lifecycle_reporting_read_models
FOR EACH ROW
EXECUTE FUNCTION public.evaluate_order_lifecycle_alerts_trigger();

-- ============================================================
-- 10. Admin Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_exception_dashboard_view AS
SELECT
    q.id,
    q.order_id,
    q.rule_code,
    q.exception_type,
    q.severity,
    q.queue_status,
    q.title,
    q.description,
    q.source_event_type,
    q.source_event_status,
    q.source_checkpoint_type,
    q.source_checkpoint_status,
    q.assigned_to,
    q.resolved_by,
    q.resolved_at,
    q.escalated_at,
    q.resolution_notes,
    q.source_payload,
    q.created_at,
    q.updated_at,
    COUNT(n.id) AS notification_count,
    COUNT(n.id) FILTER (WHERE n.notification_status = 'pending') AS pending_notification_count,
    COUNT(n.id) FILTER (WHERE n.notification_status = 'sent') AS sent_notification_count,
    COUNT(n.id) FILTER (WHERE n.notification_status = 'failed') AS failed_notification_count
FROM public.order_lifecycle_exception_queue q
LEFT JOIN public.order_lifecycle_alert_notifications n
ON n.exception_id = q.id
GROUP BY
    q.id,
    q.order_id,
    q.rule_code,
    q.exception_type,
    q.severity,
    q.queue_status,
    q.title,
    q.description,
    q.source_event_type,
    q.source_event_status,
    q.source_checkpoint_type,
    q.source_checkpoint_status,
    q.assigned_to,
    q.resolved_by,
    q.resolved_at,
    q.escalated_at,
    q.resolution_notes,
    q.source_payload,
    q.created_at,
    q.updated_at;

COMMENT ON VIEW public.order_lifecycle_exception_dashboard_view IS
'Admin-ready dashboard view for order lifecycle exceptions and alert notification status.';

-- ============================================================
-- 11. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_alert_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_exception_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_alert_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle alert rules"
ON public.order_lifecycle_alert_rules;

CREATE POLICY "Service role can manage order lifecycle alert rules"
ON public.order_lifecycle_alert_rules
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle exception queue"
ON public.order_lifecycle_exception_queue;

CREATE POLICY "Service role can manage order lifecycle exception queue"
ON public.order_lifecycle_exception_queue
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle alert notifications"
ON public.order_lifecycle_alert_notifications;

CREATE POLICY "Service role can manage order lifecycle alert notifications"
ON public.order_lifecycle_alert_notifications
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
    107,
    'migration_107_order_lifecycle_alerts_exception_queue',
    'Adds alert rules, exception queue, notification tracking, and auto-evaluation for order lifecycle reporting issues.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
