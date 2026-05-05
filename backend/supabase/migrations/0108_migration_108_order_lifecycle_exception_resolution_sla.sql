-- Migration 108: Order Lifecycle Exception Resolution SLA
-- Purpose:
-- Adds SLA policies, SLA tracking, resolution action history,
-- escalation support, and dashboard views for order lifecycle exceptions.

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Order Lifecycle SLA Policies
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_exception_sla_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    policy_code TEXT NOT NULL UNIQUE,
    policy_name TEXT NOT NULL,
    policy_description TEXT,

    severity TEXT NOT NULL,
    response_due_hours INTEGER NOT NULL DEFAULT 24,
    resolution_due_hours INTEGER NOT NULL DEFAULT 72,
    escalation_due_hours INTEGER NOT NULL DEFAULT 48,

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    policy_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_exception_sla_policies_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_exception_sla_policies_hours
    CHECK (
        response_due_hours > 0
        AND resolution_due_hours > 0
        AND escalation_due_hours > 0
    )
);

COMMENT ON TABLE public.order_lifecycle_exception_sla_policies IS
'Stores SLA policy settings for order lifecycle exception response, escalation, and resolution timing.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_policies_severity
ON public.order_lifecycle_exception_sla_policies(severity);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_policies_enabled
ON public.order_lifecycle_exception_sla_policies(is_enabled);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_policies_config
ON public.order_lifecycle_exception_sla_policies USING GIN(policy_config);

-- ============================================================
-- 2. Default SLA Policies
-- ============================================================

INSERT INTO public.order_lifecycle_exception_sla_policies (
    policy_code,
    policy_name,
    policy_description,
    severity,
    response_due_hours,
    resolution_due_hours,
    escalation_due_hours,
    is_enabled,
    policy_config
)
VALUES
(
    'LOW_EXCEPTION_SLA',
    'Low Exception SLA',
    'Default SLA for low severity order lifecycle exceptions.',
    'low',
    48,
    120,
    96,
    TRUE,
    jsonb_build_object('created_by', 'migration_108')
),
(
    'MEDIUM_EXCEPTION_SLA',
    'Medium Exception SLA',
    'Default SLA for medium severity order lifecycle exceptions.',
    'medium',
    24,
    72,
    48,
    TRUE,
    jsonb_build_object('created_by', 'migration_108')
),
(
    'HIGH_EXCEPTION_SLA',
    'High Exception SLA',
    'Default SLA for high severity order lifecycle exceptions.',
    'high',
    8,
    24,
    12,
    TRUE,
    jsonb_build_object('created_by', 'migration_108')
),
(
    'CRITICAL_EXCEPTION_SLA',
    'Critical Exception SLA',
    'Default SLA for critical order lifecycle exceptions.',
    'critical',
    2,
    8,
    4,
    TRUE,
    jsonb_build_object('created_by', 'migration_108')
)
ON CONFLICT (policy_code) DO UPDATE
SET
    policy_name = EXCLUDED.policy_name,
    policy_description = EXCLUDED.policy_description,
    severity = EXCLUDED.severity,
    response_due_hours = EXCLUDED.response_due_hours,
    resolution_due_hours = EXCLUDED.resolution_due_hours,
    escalation_due_hours = EXCLUDED.escalation_due_hours,
    is_enabled = EXCLUDED.is_enabled,
    policy_config = EXCLUDED.policy_config,
    updated_at = NOW();

-- ============================================================
-- 3. Order Lifecycle Exception SLA Tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_exception_sla_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exception_id UUID NOT NULL UNIQUE REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

    severity TEXT NOT NULL,
    sla_policy_code TEXT,

    response_due_at TIMESTAMPTZ,
    resolution_due_at TIMESTAMPTZ,
    escalation_due_at TIMESTAMPTZ,

    first_response_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,

    sla_status TEXT NOT NULL DEFAULT 'active',

    response_breached BOOLEAN NOT NULL DEFAULT FALSE,
    resolution_breached BOOLEAN NOT NULL DEFAULT FALSE,
    escalation_breached BOOLEAN NOT NULL DEFAULT FALSE,

    tracking_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_exception_sla_tracking_severity
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    CONSTRAINT chk_order_lifecycle_exception_sla_tracking_status
    CHECK (sla_status IN ('active', 'responded', 'resolved', 'breached', 'escalated', 'ignored'))
);

COMMENT ON TABLE public.order_lifecycle_exception_sla_tracking IS
'Tracks SLA deadlines, breach status, escalation status, and resolution timing for order lifecycle exceptions.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_tracking_exception_id
ON public.order_lifecycle_exception_sla_tracking(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_tracking_order_id
ON public.order_lifecycle_exception_sla_tracking(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_tracking_status
ON public.order_lifecycle_exception_sla_tracking(sla_status);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_tracking_resolution_due_at
ON public.order_lifecycle_exception_sla_tracking(resolution_due_at);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_sla_tracking_payload
ON public.order_lifecycle_exception_sla_tracking USING GIN(tracking_payload);

-- ============================================================
-- 4. Exception Resolution Action History
-- ============================================================

CREATE TABLE IF NOT EXISTS public.order_lifecycle_exception_resolution_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exception_id UUID NOT NULL REFERENCES public.order_lifecycle_exception_queue(id) ON DELETE CASCADE,
    order_id UUID NOT NULL,

    action_type TEXT NOT NULL,
    action_status TEXT NOT NULL DEFAULT 'recorded',

    actor_id UUID,
    actor_type TEXT NOT NULL DEFAULT 'system',

    previous_queue_status TEXT,
    new_queue_status TEXT,

    action_notes TEXT,
    action_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_order_lifecycle_exception_resolution_actions_status
    CHECK (action_status IN ('recorded', 'completed', 'failed', 'cancelled'))
);

COMMENT ON TABLE public.order_lifecycle_exception_resolution_actions IS
'Stores action history for exception review, response, escalation, ignore, and resolution workflows.';

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_resolution_actions_exception_id
ON public.order_lifecycle_exception_resolution_actions(exception_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_resolution_actions_order_id
ON public.order_lifecycle_exception_resolution_actions(order_id);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_resolution_actions_action_type
ON public.order_lifecycle_exception_resolution_actions(action_type);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_resolution_actions_created_at
ON public.order_lifecycle_exception_resolution_actions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_lifecycle_exception_resolution_actions_payload
ON public.order_lifecycle_exception_resolution_actions USING GIN(action_payload);

-- ============================================================
-- 5. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_order_lifecycle_exception_sla_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_exception_sla_policies_updated_at
ON public.order_lifecycle_exception_sla_policies;

CREATE TRIGGER trg_order_lifecycle_exception_sla_policies_updated_at
BEFORE UPDATE ON public.order_lifecycle_exception_sla_policies
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_exception_sla_updated_at();

DROP TRIGGER IF EXISTS trg_order_lifecycle_exception_sla_tracking_updated_at
ON public.order_lifecycle_exception_sla_tracking;

CREATE TRIGGER trg_order_lifecycle_exception_sla_tracking_updated_at
BEFORE UPDATE ON public.order_lifecycle_exception_sla_tracking
FOR EACH ROW
EXECUTE FUNCTION public.set_order_lifecycle_exception_sla_updated_at();

-- ============================================================
-- 6. Ensure SLA Tracking Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.ensure_order_lifecycle_exception_sla_tracking(
    p_exception_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_exception RECORD;
    v_policy RECORD;
    v_tracking_id UUID;
BEGIN
    IF p_exception_id IS NULL THEN
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
    INTO v_policy
    FROM public.order_lifecycle_exception_sla_policies
    WHERE severity = v_exception.severity
    AND is_enabled = TRUE
    ORDER BY created_at DESC
    LIMIT 1;

    INSERT INTO public.order_lifecycle_exception_sla_tracking (
        exception_id,
        order_id,
        severity,
        sla_policy_code,
        response_due_at,
        resolution_due_at,
        escalation_due_at,
        sla_status,
        tracking_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_exception.id,
        v_exception.order_id,
        v_exception.severity,
        COALESCE(v_policy.policy_code, NULL),
        v_exception.created_at + make_interval(hours => COALESCE(v_policy.response_due_hours, 24)),
        v_exception.created_at + make_interval(hours => COALESCE(v_policy.resolution_due_hours, 72)),
        v_exception.created_at + make_interval(hours => COALESCE(v_policy.escalation_due_hours, 48)),
        CASE
            WHEN v_exception.queue_status = 'resolved' THEN 'resolved'
            WHEN v_exception.queue_status = 'ignored' THEN 'ignored'
            WHEN v_exception.queue_status = 'escalated' THEN 'escalated'
            ELSE 'active'
        END,
        jsonb_build_object(
            'exception_id', v_exception.id,
            'order_id', v_exception.order_id,
            'severity', v_exception.severity,
            'queue_status', v_exception.queue_status,
            'generated_by', 'migration_108'
        ),
        NOW(),
        NOW()
    )
    ON CONFLICT (exception_id) DO UPDATE
    SET
        order_id = EXCLUDED.order_id,
        severity = EXCLUDED.severity,
        sla_policy_code = EXCLUDED.sla_policy_code,
        response_due_at = COALESCE(public.order_lifecycle_exception_sla_tracking.response_due_at, EXCLUDED.response_due_at),
        resolution_due_at = COALESCE(public.order_lifecycle_exception_sla_tracking.resolution_due_at, EXCLUDED.resolution_due_at),
        escalation_due_at = COALESCE(public.order_lifecycle_exception_sla_tracking.escalation_due_at, EXCLUDED.escalation_due_at),
        sla_status = CASE
            WHEN v_exception.queue_status = 'resolved' THEN 'resolved'
            WHEN v_exception.queue_status = 'ignored' THEN 'ignored'
            WHEN v_exception.queue_status = 'escalated' THEN 'escalated'
            WHEN public.order_lifecycle_exception_sla_tracking.sla_status IN ('breached', 'responded')
            THEN public.order_lifecycle_exception_sla_tracking.sla_status
            ELSE 'active'
        END,
        updated_at = NOW()
    RETURNING id INTO v_tracking_id;

    RETURN v_tracking_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Record Exception Resolution Action Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_order_lifecycle_exception_action(
    p_exception_id UUID,
    p_action_type TEXT,
    p_actor_id UUID DEFAULT NULL,
    p_actor_type TEXT DEFAULT 'system',
    p_new_queue_status TEXT DEFAULT NULL,
    p_action_notes TEXT DEFAULT NULL,
    p_action_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_exception RECORD;
    v_action_id UUID;
    v_new_status TEXT;
BEGIN
    IF p_exception_id IS NULL OR p_action_type IS NULL THEN
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

    v_new_status := COALESCE(p_new_queue_status, v_exception.queue_status);

    INSERT INTO public.order_lifecycle_exception_resolution_actions (
        exception_id,
        order_id,
        action_type,
        action_status,
        actor_id,
        actor_type,
        previous_queue_status,
        new_queue_status,
        action_notes,
        action_payload,
        created_at
    )
    VALUES (
        v_exception.id,
        v_exception.order_id,
        p_action_type,
        'recorded',
        p_actor_id,
        COALESCE(p_actor_type, 'system'),
        v_exception.queue_status,
        v_new_status,
        p_action_notes,
        COALESCE(p_action_payload, '{}'::jsonb),
        NOW()
    )
    RETURNING id INTO v_action_id;

    UPDATE public.order_lifecycle_exception_queue
    SET
        queue_status = v_new_status,
        resolved_by = CASE
            WHEN v_new_status = 'resolved' THEN p_actor_id
            ELSE resolved_by
        END,
        resolved_at = CASE
            WHEN v_new_status = 'resolved' THEN NOW()
            ELSE resolved_at
        END,
        escalated_at = CASE
            WHEN v_new_status = 'escalated' THEN NOW()
            ELSE escalated_at
        END,
        resolution_notes = CASE
            WHEN p_action_notes IS NOT NULL THEN p_action_notes
            ELSE resolution_notes
        END,
        updated_at = NOW()
    WHERE id = v_exception.id;

    PERFORM public.ensure_order_lifecycle_exception_sla_tracking(v_exception.id);

    UPDATE public.order_lifecycle_exception_sla_tracking
    SET
        first_response_at = CASE
            WHEN p_action_type IN ('respond', 'review', 'assign')
            AND first_response_at IS NULL
            THEN NOW()
            ELSE first_response_at
        END,
        resolved_at = CASE
            WHEN v_new_status = 'resolved' THEN NOW()
            ELSE resolved_at
        END,
        escalated_at = CASE
            WHEN v_new_status = 'escalated' THEN NOW()
            ELSE escalated_at
        END,
        sla_status = CASE
            WHEN v_new_status = 'resolved' THEN 'resolved'
            WHEN v_new_status = 'ignored' THEN 'ignored'
            WHEN v_new_status = 'escalated' THEN 'escalated'
            WHEN p_action_type IN ('respond', 'review', 'assign') THEN 'responded'
            ELSE sla_status
        END,
        updated_at = NOW()
    WHERE exception_id = v_exception.id;

    RETURN v_action_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Evaluate SLA Breaches Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.evaluate_order_lifecycle_exception_sla_breaches()
RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER := 0;
BEGIN
    UPDATE public.order_lifecycle_exception_sla_tracking
    SET
        response_breached = CASE
            WHEN first_response_at IS NULL
            AND response_due_at IS NOT NULL
            AND response_due_at < NOW()
            THEN TRUE
            ELSE response_breached
        END,
        resolution_breached = CASE
            WHEN resolved_at IS NULL
            AND resolution_due_at IS NOT NULL
            AND resolution_due_at < NOW()
            THEN TRUE
            ELSE resolution_breached
        END,
        escalation_breached = CASE
            WHEN escalated_at IS NULL
            AND escalation_due_at IS NOT NULL
            AND escalation_due_at < NOW()
            THEN TRUE
            ELSE escalation_breached
        END,
        sla_status = CASE
            WHEN sla_status IN ('resolved', 'ignored') THEN sla_status
            WHEN (
                first_response_at IS NULL
                AND response_due_at IS NOT NULL
                AND response_due_at < NOW()
            )
            OR (
                resolved_at IS NULL
                AND resolution_due_at IS NOT NULL
                AND resolution_due_at < NOW()
            )
            OR (
                escalated_at IS NULL
                AND escalation_due_at IS NOT NULL
                AND escalation_due_at < NOW()
            )
            THEN 'breached'
            ELSE sla_status
        END,
        updated_at = NOW()
    WHERE sla_status NOT IN ('resolved', 'ignored');

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Auto SLA Tracking Trigger
-- ============================================================

CREATE OR REPLACE FUNCTION public.order_lifecycle_exception_sla_tracking_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM public.ensure_order_lifecycle_exception_sla_tracking(NEW.id);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        PERFORM public.ensure_order_lifecycle_exception_sla_tracking(NEW.id);
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_lifecycle_exception_sla_tracking
ON public.order_lifecycle_exception_queue;

CREATE TRIGGER trg_order_lifecycle_exception_sla_tracking
AFTER INSERT OR UPDATE ON public.order_lifecycle_exception_queue
FOR EACH ROW
EXECUTE FUNCTION public.order_lifecycle_exception_sla_tracking_trigger();

-- ============================================================
-- 10. Backfill Existing Exceptions
-- ============================================================

DO $$
DECLARE
    v_exception RECORD;
BEGIN
    FOR v_exception IN
        SELECT id
        FROM public.order_lifecycle_exception_queue
    LOOP
        PERFORM public.ensure_order_lifecycle_exception_sla_tracking(v_exception.id);
    END LOOP;
END;
$$;

-- ============================================================
-- 11. SLA Dashboard View
-- ============================================================

CREATE OR REPLACE VIEW public.order_lifecycle_exception_sla_dashboard_view AS
SELECT
    q.id AS exception_id,
    q.order_id,
    q.rule_code,
    q.exception_type,
    q.severity,
    q.queue_status,
    q.title,
    q.description,
    q.created_at AS exception_created_at,
    q.updated_at AS exception_updated_at,

    s.sla_policy_code,
    s.response_due_at,
    s.resolution_due_at,
    s.escalation_due_at,
    s.first_response_at,
    s.resolved_at,
    s.escalated_at,
    s.sla_status,
    s.response_breached,
    s.resolution_breached,
    s.escalation_breached,

    CASE
        WHEN s.sla_status = 'resolved' THEN 'completed'
        WHEN s.sla_status = 'ignored' THEN 'ignored'
        WHEN s.response_breached = TRUE
          OR s.resolution_breached = TRUE
          OR s.escalation_breached = TRUE
        THEN 'breached'
        WHEN s.resolution_due_at IS NOT NULL
          AND s.resolution_due_at < NOW() + INTERVAL '6 hours'
        THEN 'due_soon'
        ELSE 'on_track'
    END AS sla_dashboard_status,

    s.tracking_payload
FROM public.order_lifecycle_exception_queue q
LEFT JOIN public.order_lifecycle_exception_sla_tracking s
ON s.exception_id = q.id;

COMMENT ON VIEW public.order_lifecycle_exception_sla_dashboard_view IS
'Admin dashboard view for exception SLA deadlines, breach status, escalation, and resolution tracking.';

-- ============================================================
-- 12. Row Level Security
-- ============================================================

ALTER TABLE public.order_lifecycle_exception_sla_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_exception_sla_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_lifecycle_exception_resolution_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage order lifecycle exception SLA policies"
ON public.order_lifecycle_exception_sla_policies;

CREATE POLICY "Service role can manage order lifecycle exception SLA policies"
ON public.order_lifecycle_exception_sla_policies
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle exception SLA tracking"
ON public.order_lifecycle_exception_sla_tracking;

CREATE POLICY "Service role can manage order lifecycle exception SLA tracking"
ON public.order_lifecycle_exception_sla_tracking
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage order lifecycle exception resolution actions"
ON public.order_lifecycle_exception_resolution_actions;

CREATE POLICY "Service role can manage order lifecycle exception resolution actions"
ON public.order_lifecycle_exception_resolution_actions
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
    108,
    'migration_108_order_lifecycle_exception_resolution_sla',
    'Adds SLA policies, SLA tracking, resolution action history, escalation support, and dashboard view for order lifecycle exceptions.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
