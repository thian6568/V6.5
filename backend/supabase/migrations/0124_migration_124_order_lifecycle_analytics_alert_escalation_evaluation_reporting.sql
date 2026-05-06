-- Migration 124: Order Lifecycle Analytics Alert Escalation Evaluation Reporting
-- Purpose:
-- Adds report definitions, report run tracking, report sections, export tracking,
-- report generation functions, dashboard views, and health reporting for
-- analytics alert escalation evaluation analytics.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Escalation Evaluation Report Definitions
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_report_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_code TEXT NOT NULL UNIQUE,
    report_name TEXT NOT NULL,
    report_description TEXT,

    report_scope TEXT NOT NULL DEFAULT 'all',
    default_lookback_days INTEGER NOT NULL DEFAULT 30,

    output_format TEXT NOT NULL DEFAULT 'json',

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    report_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    delivery_config JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_report_definitions_scope
    CHECK (
        report_scope IN (
            'all',
            'daily_evaluation',
            'schedule_evaluation',
            'kpi_snapshot',
            'health'
        )
    ),

    CONSTRAINT chk_oiaa_eval_report_definitions_format
    CHECK (output_format IN ('json', 'csv', 'pdf', 'html')),

    CONSTRAINT chk_oiaa_eval_report_definitions_lookback
    CHECK (default_lookback_days >= 0)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_report_definitions IS
'Stores report definitions for analytics alert escalation evaluation analytics.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_def_code
ON public.oiaa_escalation_evaluation_report_definitions(report_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_def_scope
ON public.oiaa_escalation_evaluation_report_definitions(report_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_def_enabled
ON public.oiaa_escalation_evaluation_report_definitions(is_enabled);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_def_config
ON public.oiaa_escalation_evaluation_report_definitions USING GIN(report_config);

-- ============================================================
-- 2. Default Report Definitions
-- ============================================================

INSERT INTO public.oiaa_escalation_evaluation_report_definitions (
    report_code,
    report_name,
    report_description,
    report_scope,
    default_lookback_days,
    output_format,
    is_enabled,
    report_config,
    delivery_config
)
VALUES
(
    'DAILY_OIAA_ESCALATION_EVALUATION_REPORT',
    'Daily Analytics Alert Escalation Evaluation Report',
    'Daily report covering escalation evaluation runs, schedules, KPI snapshots, and health.',
    'all',
    30,
    'json',
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_124',
        'recommended_for', 'admin_daily_review'
    ),
    jsonb_build_object(
        'delivery_mode', 'manual_download',
        'created_by', 'migration_124'
    )
),
(
    'WEEKLY_OIAA_ESCALATION_EVALUATION_REPORT',
    'Weekly Analytics Alert Escalation Evaluation Report',
    'Weekly report covering escalation evaluation trends and system health.',
    'all',
    90,
    'json',
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_124',
        'recommended_for', 'weekly_operations_review'
    ),
    jsonb_build_object(
        'delivery_mode', 'manual_download',
        'created_by', 'migration_124'
    )
),
(
    'OIAA_ESCALATION_EVALUATION_HEALTH_REPORT',
    'Analytics Alert Escalation Evaluation Health Report',
    'Focused report for latest KPI and health status of escalation evaluation analytics.',
    'health',
    7,
    'json',
    TRUE,
    jsonb_build_object(
        'created_by', 'migration_124',
        'recommended_for', 'health_monitoring'
    ),
    jsonb_build_object(
        'delivery_mode', 'admin_dashboard',
        'created_by', 'migration_124'
    )
)
ON CONFLICT (report_code) DO UPDATE
SET
    report_name = EXCLUDED.report_name,
    report_description = EXCLUDED.report_description,
    report_scope = EXCLUDED.report_scope,
    default_lookback_days = EXCLUDED.default_lookback_days,
    output_format = EXCLUDED.output_format,
    is_enabled = EXCLUDED.is_enabled,
    report_config = EXCLUDED.report_config,
    delivery_config = EXCLUDED.delivery_config,
    updated_at = NOW();

-- ============================================================
-- 3. Escalation Evaluation Report Runs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_report_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_definition_id UUID REFERENCES public.oiaa_escalation_evaluation_report_definitions(id) ON DELETE SET NULL,
    report_code TEXT,

    report_scope TEXT NOT NULL DEFAULT 'all',
    report_status TEXT NOT NULL DEFAULT 'created',

    from_date DATE,
    to_date DATE,

    generated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,

    total_sections INTEGER NOT NULL DEFAULT 0,
    total_export_records INTEGER NOT NULL DEFAULT 0,

    error_message TEXT,

    report_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_report_runs_scope
    CHECK (
        report_scope IN (
            'all',
            'daily_evaluation',
            'schedule_evaluation',
            'kpi_snapshot',
            'health'
        )
    ),

    CONSTRAINT chk_oiaa_eval_report_runs_status
    CHECK (
        report_status IN (
            'created',
            'running',
            'completed',
            'failed',
            'cancelled',
            'skipped'
        )
    ),

    CONSTRAINT chk_oiaa_eval_report_runs_counts
    CHECK (
        total_sections >= 0
        AND total_export_records >= 0
    )
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_report_runs IS
'Stores report generation runs for analytics alert escalation evaluation analytics.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_definition
ON public.oiaa_escalation_evaluation_report_runs(report_definition_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_code
ON public.oiaa_escalation_evaluation_report_runs(report_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_status
ON public.oiaa_escalation_evaluation_report_runs(report_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_scope
ON public.oiaa_escalation_evaluation_report_runs(report_scope);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_created
ON public.oiaa_escalation_evaluation_report_runs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_runs_payload
ON public.oiaa_escalation_evaluation_report_runs USING GIN(report_payload);

-- ============================================================
-- 4. Escalation Evaluation Report Sections
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_report_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_run_id UUID NOT NULL REFERENCES public.oiaa_escalation_evaluation_report_runs(id) ON DELETE CASCADE,

    section_code TEXT NOT NULL,
    section_name TEXT NOT NULL,
    section_order INTEGER NOT NULL DEFAULT 100,

    section_status TEXT NOT NULL DEFAULT 'generated',

    row_count INTEGER NOT NULL DEFAULT 0,

    section_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_report_sections_status
    CHECK (section_status IN ('generated', 'empty', 'failed', 'skipped')),

    CONSTRAINT chk_oiaa_eval_report_sections_rows
    CHECK (row_count >= 0),

    CONSTRAINT uq_oiaa_eval_report_section
    UNIQUE (report_run_id, section_code)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_report_sections IS
'Stores generated report sections for analytics alert escalation evaluation reports.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_sections_run
ON public.oiaa_escalation_evaluation_report_sections(report_run_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_sections_code
ON public.oiaa_escalation_evaluation_report_sections(section_code);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_sections_status
ON public.oiaa_escalation_evaluation_report_sections(section_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_sections_payload
ON public.oiaa_escalation_evaluation_report_sections USING GIN(section_payload);

-- ============================================================
-- 5. Escalation Evaluation Report Exports
-- ============================================================

CREATE TABLE IF NOT EXISTS public.oiaa_escalation_evaluation_report_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    report_run_id UUID NOT NULL REFERENCES public.oiaa_escalation_evaluation_report_runs(id) ON DELETE CASCADE,

    export_format TEXT NOT NULL DEFAULT 'json',
    export_status TEXT NOT NULL DEFAULT 'pending',

    file_name TEXT,
    export_uri TEXT,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    checksum TEXT,

    generated_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,

    error_message TEXT,

    export_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_oiaa_eval_report_exports_format
    CHECK (export_format IN ('json', 'csv', 'pdf', 'html')),

    CONSTRAINT chk_oiaa_eval_report_exports_status
    CHECK (
        export_status IN (
            'pending',
            'generated',
            'delivered',
            'failed',
            'cancelled'
        )
    ),

    CONSTRAINT chk_oiaa_eval_report_exports_size
    CHECK (file_size_bytes >= 0)
);

COMMENT ON TABLE public.oiaa_escalation_evaluation_report_exports IS
'Stores export records for analytics alert escalation evaluation reports.';

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_exports_run
ON public.oiaa_escalation_evaluation_report_exports(report_run_id);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_exports_format
ON public.oiaa_escalation_evaluation_report_exports(export_format);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_exports_status
ON public.oiaa_escalation_evaluation_report_exports(export_status);

CREATE INDEX IF NOT EXISTS idx_oiaa_eval_report_exports_payload
ON public.oiaa_escalation_evaluation_report_exports USING GIN(export_payload);

-- ============================================================
-- 6. updated_at Trigger Helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_oiaa_escalation_evaluation_reporting_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oiaa_eval_report_definitions_updated_at
ON public.oiaa_escalation_evaluation_report_definitions;

CREATE TRIGGER trg_oiaa_eval_report_definitions_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_report_definitions
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_reporting_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_eval_report_runs_updated_at
ON public.oiaa_escalation_evaluation_report_runs;

CREATE TRIGGER trg_oiaa_eval_report_runs_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_report_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_reporting_updated_at();

DROP TRIGGER IF EXISTS trg_oiaa_eval_report_exports_updated_at
ON public.oiaa_escalation_evaluation_report_exports;

CREATE TRIGGER trg_oiaa_eval_report_exports_updated_at
BEFORE UPDATE ON public.oiaa_escalation_evaluation_report_exports
FOR EACH ROW
EXECUTE FUNCTION public.set_oiaa_escalation_evaluation_reporting_updated_at();

-- ============================================================
-- 7. Record Report Section Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_oiaa_escalation_evaluation_report_section(
    p_report_run_id UUID,
    p_section_code TEXT,
    p_section_name TEXT,
    p_section_order INTEGER DEFAULT 100,
    p_section_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_section_id UUID;
    v_row_count INTEGER := 0;
BEGIN
    IF p_report_run_id IS NULL
       OR p_section_code IS NULL
       OR p_section_name IS NULL THEN
        RETURN NULL;
    END IF;

    v_row_count := CASE
        WHEN jsonb_typeof(COALESCE(p_section_payload, '{}'::jsonb)) = 'array'
        THEN jsonb_array_length(COALESCE(p_section_payload, '[]'::jsonb))
        WHEN COALESCE(p_section_payload, '{}'::jsonb) = '{}'::jsonb
        THEN 0
        ELSE 1
    END;

    INSERT INTO public.oiaa_escalation_evaluation_report_sections (
        report_run_id,
        section_code,
        section_name,
        section_order,
        section_status,
        row_count,
        section_payload,
        created_at
    )
    VALUES (
        p_report_run_id,
        p_section_code,
        p_section_name,
        COALESCE(p_section_order, 100),
        CASE WHEN v_row_count = 0 THEN 'empty' ELSE 'generated' END,
        v_row_count,
        COALESCE(p_section_payload, '{}'::jsonb),
        NOW()
    )
    ON CONFLICT (report_run_id, section_code) DO UPDATE
    SET
        section_name = EXCLUDED.section_name,
        section_order = EXCLUDED.section_order,
        section_status = EXCLUDED.section_status,
        row_count = EXCLUDED.row_count,
        section_payload = EXCLUDED.section_payload
    RETURNING id INTO v_section_id;

    RETURN v_section_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8. Generate Report Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.generate_oiaa_escalation_evaluation_report(
    p_report_code TEXT,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_definition RECORD;
    v_report_run_id UUID;
    v_export_id UUID;

    v_from_date DATE;
    v_to_date DATE;

    v_daily_payload JSONB := '[]'::jsonb;
    v_schedule_payload JSONB := '[]'::jsonb;
    v_kpi_payload JSONB := '{}'::jsonb;
    v_health_payload JSONB := '{}'::jsonb;
    v_refresh_health_payload JSONB := '{}'::jsonb;

    v_report_payload JSONB := '{}'::jsonb;
    v_total_sections INTEGER := 0;
BEGIN
    IF p_report_code IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT *
    INTO v_definition
    FROM public.oiaa_escalation_evaluation_report_definitions
    WHERE report_code = p_report_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_to_date := COALESCE(p_to_date, CURRENT_DATE);
    v_from_date := COALESCE(
        p_from_date,
        CURRENT_DATE - COALESCE(v_definition.default_lookback_days, 30)
    );

    IF v_definition.is_enabled = FALSE THEN
        INSERT INTO public.oiaa_escalation_evaluation_report_runs (
            report_definition_id,
            report_code,
            report_scope,
            report_status,
            from_date,
            to_date,
            report_payload,
            created_at,
            updated_at
        )
        VALUES (
            v_definition.id,
            v_definition.report_code,
            v_definition.report_scope,
            'skipped',
            v_from_date,
            v_to_date,
            jsonb_build_object(
                'reason', 'report_definition_disabled',
                'report_code', v_definition.report_code,
                'generated_by', 'migration_124'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_report_run_id;

        RETURN v_report_run_id;
    END IF;

    INSERT INTO public.oiaa_escalation_evaluation_report_runs (
        report_definition_id,
        report_code,
        report_scope,
        report_status,
        from_date,
        to_date,
        generated_at,
        report_payload,
        created_at,
        updated_at
    )
    VALUES (
        v_definition.id,
        v_definition.report_code,
        v_definition.report_scope,
        'running',
        v_from_date,
        v_to_date,
        NOW(),
        jsonb_build_object(
            'report_code', v_definition.report_code,
            'report_scope', v_definition.report_scope,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'generated_by', 'migration_124'
        ),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_report_run_id;

    BEGIN
        IF v_definition.report_scope IN ('all', 'daily_evaluation') THEN
            SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.analytics_date DESC), '[]'::jsonb)
            INTO v_daily_payload
            FROM (
                SELECT *
                FROM public.oiaa_escalation_evaluation_daily_analytics
                WHERE analytics_date BETWEEN v_from_date AND v_to_date
                ORDER BY analytics_date DESC
            ) d;

            PERFORM public.record_oiaa_escalation_evaluation_report_section(
                v_report_run_id,
                'daily_evaluation_analytics',
                'Daily Escalation Evaluation Analytics',
                10,
                v_daily_payload
            );
        END IF;

        IF v_definition.report_scope IN ('all', 'schedule_evaluation') THEN
            SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.analytics_date DESC, s.schedule_code ASC), '[]'::jsonb)
            INTO v_schedule_payload
            FROM (
                SELECT *
                FROM public.oiaa_escalation_evaluation_schedule_analytics
                WHERE analytics_date BETWEEN v_from_date AND v_to_date
                ORDER BY analytics_date DESC, schedule_code ASC
            ) s;

            PERFORM public.record_oiaa_escalation_evaluation_report_section(
                v_report_run_id,
                'schedule_evaluation_analytics',
                'Schedule Escalation Evaluation Analytics',
                20,
                v_schedule_payload
            );
        END IF;

        IF v_definition.report_scope IN ('all', 'kpi_snapshot', 'health') THEN
            SELECT COALESCE(
                (
                    SELECT to_jsonb(k)
                    FROM (
                        SELECT *
                        FROM public.oiaa_escalation_evaluation_latest_kpi_view
                        LIMIT 1
                    ) k
                ),
                '{}'::jsonb
            )
            INTO v_kpi_payload;

            PERFORM public.record_oiaa_escalation_evaluation_report_section(
                v_report_run_id,
                'latest_kpi_snapshot',
                'Latest Escalation Evaluation KPI Snapshot',
                30,
                v_kpi_payload
            );
        END IF;

        IF v_definition.report_scope IN ('all', 'health') THEN
            SELECT jsonb_build_object(
                'analytics_health',
                COALESCE(
                    (
                        SELECT jsonb_agg(to_jsonb(h))
                        FROM public.oiaa_escalation_evaluation_analytics_health_view h
                    ),
                    '[]'::jsonb
                ),
                'scheduled_refresh_health',
                COALESCE(
                    (
                        SELECT to_jsonb(rh)
                        FROM public.oiaa_escalation_evaluation_analytics_scheduled_refresh_health_view rh
                        LIMIT 1
                    ),
                    '{}'::jsonb
                )
            )
            INTO v_health_payload;

            PERFORM public.record_oiaa_escalation_evaluation_report_section(
                v_report_run_id,
                'health_summary',
                'Escalation Evaluation Analytics Health Summary',
                40,
                v_health_payload
            );
        END IF;

        SELECT COUNT(*)::INTEGER
        INTO v_total_sections
        FROM public.oiaa_escalation_evaluation_report_sections
        WHERE report_run_id = v_report_run_id;

        v_report_payload := jsonb_build_object(
            'report_run_id', v_report_run_id,
            'report_code', v_definition.report_code,
            'report_name', v_definition.report_name,
            'report_scope', v_definition.report_scope,
            'from_date', v_from_date,
            'to_date', v_to_date,
            'output_format', v_definition.output_format,
            'total_sections', v_total_sections,
            'generated_by', 'migration_124',
            'generated_at', NOW()
        );

        INSERT INTO public.oiaa_escalation_evaluation_report_exports (
            report_run_id,
            export_format,
            export_status,
            file_name,
            generated_at,
            export_payload,
            created_at,
            updated_at
        )
        VALUES (
            v_report_run_id,
            v_definition.output_format,
            'generated',
            lower(v_definition.report_code) || '_' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '.' || v_definition.output_format,
            NOW(),
            jsonb_build_object(
                'report_run_id', v_report_run_id,
                'report_code', v_definition.report_code,
                'export_format', v_definition.output_format,
                'delivery_mode', COALESCE(v_definition.delivery_config ->> 'delivery_mode', 'manual_download'),
                'generated_by', 'migration_124'
            ),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_export_id;

        UPDATE public.oiaa_escalation_evaluation_report_runs
        SET
            report_status = 'completed',
            completed_at = NOW(),
            total_sections = v_total_sections,
            total_export_records = 1,
            report_payload = v_report_payload || jsonb_build_object('export_id', v_export_id),
            updated_at = NOW()
        WHERE id = v_report_run_id;

        INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'generate_oiaa_escalation_evaluation_report',
            'completed',
            v_report_payload || jsonb_build_object('export_id', v_export_id),
            NOW()
        );

    EXCEPTION WHEN OTHERS THEN
        UPDATE public.oiaa_escalation_evaluation_report_runs
        SET
            report_status = 'failed',
            failed_at = NOW(),
            error_message = SQLERRM,
            report_payload = jsonb_build_object(
                'report_code', v_definition.report_code,
                'error_message', SQLERRM,
                'generated_by', 'migration_124'
            ),
            updated_at = NOW()
        WHERE id = v_report_run_id;

        INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
            event_type,
            event_status,
            event_payload,
            created_at
        )
        VALUES (
            'generate_oiaa_escalation_evaluation_report',
            'failed',
            jsonb_build_object(
                'report_run_id', v_report_run_id,
                'report_code', v_definition.report_code,
                'error_message', SQLERRM,
                'generated_by', 'migration_124'
            ),
            NOW()
        );
    END;

    RETURN v_report_run_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. Generate All Enabled Reports Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.generate_all_enabled_oiaa_escalation_evaluation_reports()
RETURNS JSONB AS $$
DECLARE
    v_definition RECORD;
    v_report_run_id UUID;
    v_run_count INTEGER := 0;
    v_run_ids JSONB := '[]'::jsonb;
BEGIN
    FOR v_definition IN
        SELECT *
        FROM public.oiaa_escalation_evaluation_report_definitions
        WHERE is_enabled = TRUE
        ORDER BY report_code ASC
    LOOP
        v_report_run_id := public.generate_oiaa_escalation_evaluation_report(
            v_definition.report_code,
            CURRENT_DATE - COALESCE(v_definition.default_lookback_days, 30),
            CURRENT_DATE
        );

        IF v_report_run_id IS NOT NULL THEN
            v_run_count := v_run_count + 1;
            v_run_ids := v_run_ids || jsonb_build_array(v_report_run_id);
        END IF;
    END LOOP;

    INSERT INTO public.oiaa_escalation_evaluation_analytics_events (
        event_type,
        event_status,
        event_payload,
        created_at
    )
    VALUES (
        'generate_all_enabled_oiaa_escalation_evaluation_reports',
        'completed',
        jsonb_build_object(
            'run_count', v_run_count,
            'run_ids', v_run_ids,
            'generated_by', 'migration_124'
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'run_count', v_run_count,
        'run_ids', v_run_ids,
        'generated_by', 'migration_124'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 10. Mark Report Export Delivered Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.mark_oiaa_escalation_evaluation_report_export_delivered(
    p_export_id UUID,
    p_export_uri TEXT DEFAULT NULL,
    p_checksum TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_export_id IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.oiaa_escalation_evaluation_report_exports
    SET
        export_status = 'delivered',
        export_uri = COALESCE(p_export_uri, export_uri),
        checksum = COALESCE(p_checksum, checksum),
        delivered_at = NOW(),
        updated_at = NOW()
    WHERE id = p_export_id;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. Dashboard Views
-- ============================================================

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_report_definition_dashboard_view AS
SELECT
    d.id,
    d.report_code,
    d.report_name,
    d.report_description,
    d.report_scope,
    d.default_lookback_days,
    d.output_format,
    d.is_enabled,

    latest_run.id AS latest_report_run_id,
    latest_run.report_status AS latest_report_status,
    latest_run.generated_at AS latest_generated_at,
    latest_run.completed_at AS latest_completed_at,
    latest_run.failed_at AS latest_failed_at,
    latest_run.error_message AS latest_error_message,

    d.report_config,
    d.delivery_config,
    d.created_at,
    d.updated_at
FROM public.oiaa_escalation_evaluation_report_definitions d
LEFT JOIN LATERAL (
    SELECT r.*
    FROM public.oiaa_escalation_evaluation_report_runs r
    WHERE r.report_definition_id = d.id
    ORDER BY r.created_at DESC
    LIMIT 1
) latest_run ON TRUE;

COMMENT ON VIEW public.oiaa_escalation_evaluation_report_definition_dashboard_view IS
'Admin dashboard view for escalation evaluation report definitions and latest run status.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_report_run_dashboard_view AS
SELECT
    r.id AS report_run_id,
    r.report_definition_id,
    r.report_code,
    r.report_scope,
    r.report_status,
    r.from_date,
    r.to_date,
    r.generated_at,
    r.completed_at,
    r.failed_at,
    r.total_sections,
    r.total_export_records,
    r.error_message,

    COUNT(s.id)::INTEGER AS section_count,
    COUNT(s.id) FILTER (WHERE s.section_status = 'generated')::INTEGER AS generated_section_count,
    COUNT(s.id) FILTER (WHERE s.section_status = 'empty')::INTEGER AS empty_section_count,
    COUNT(s.id) FILTER (WHERE s.section_status = 'failed')::INTEGER AS failed_section_count,

    COUNT(e.id)::INTEGER AS export_count,
    COUNT(e.id) FILTER (WHERE e.export_status = 'generated')::INTEGER AS generated_export_count,
    COUNT(e.id) FILTER (WHERE e.export_status = 'delivered')::INTEGER AS delivered_export_count,
    COUNT(e.id) FILTER (WHERE e.export_status = 'failed')::INTEGER AS failed_export_count,

    CASE
        WHEN r.report_status = 'failed' THEN 'attention_required'
        WHEN COUNT(s.id) FILTER (WHERE s.section_status = 'failed') > 0 THEN 'section_failure'
        WHEN COUNT(e.id) FILTER (WHERE e.export_status = 'failed') > 0 THEN 'export_failure'
        WHEN r.report_status = 'completed'
             AND COUNT(e.id) FILTER (WHERE e.export_status = 'delivered') > 0 THEN 'delivered'
        WHEN r.report_status = 'completed' THEN 'generated'
        WHEN r.report_status = 'running' THEN 'running'
        WHEN r.report_status = 'skipped' THEN 'skipped'
        ELSE 'created'
    END AS report_run_dashboard_status,

    r.report_payload,
    r.created_at,
    r.updated_at
FROM public.oiaa_escalation_evaluation_report_runs r
LEFT JOIN public.oiaa_escalation_evaluation_report_sections s
ON s.report_run_id = r.id
LEFT JOIN public.oiaa_escalation_evaluation_report_exports e
ON e.report_run_id = r.id
GROUP BY
    r.id,
    r.report_definition_id,
    r.report_code,
    r.report_scope,
    r.report_status,
    r.from_date,
    r.to_date,
    r.generated_at,
    r.completed_at,
    r.failed_at,
    r.total_sections,
    r.total_export_records,
    r.error_message,
    r.report_payload,
    r.created_at,
    r.updated_at;

COMMENT ON VIEW public.oiaa_escalation_evaluation_report_run_dashboard_view IS
'Admin dashboard view for escalation evaluation report run history, sections, and exports.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_report_export_dashboard_view AS
SELECT
    e.id AS export_id,
    e.report_run_id,
    r.report_code,
    r.report_scope,
    e.export_format,
    e.export_status,
    e.file_name,
    e.export_uri,
    e.file_size_bytes,
    e.checksum,
    e.generated_at,
    e.delivered_at,
    e.error_message,

    CASE
        WHEN e.export_status = 'failed' THEN 'attention_required'
        WHEN e.export_status = 'delivered' THEN 'delivered'
        WHEN e.export_status = 'generated' THEN 'ready'
        WHEN e.export_status = 'pending' THEN 'pending'
        ELSE e.export_status
    END AS export_dashboard_status,

    e.export_payload,
    e.created_at,
    e.updated_at
FROM public.oiaa_escalation_evaluation_report_exports e
JOIN public.oiaa_escalation_evaluation_report_runs r
ON r.id = e.report_run_id;

COMMENT ON VIEW public.oiaa_escalation_evaluation_report_export_dashboard_view IS
'Admin dashboard view for escalation evaluation report exports.';

CREATE OR REPLACE VIEW public.oiaa_escalation_evaluation_reporting_health_view AS
SELECT
    COUNT(*)::INTEGER AS total_report_definitions,
    COUNT(*) FILTER (WHERE is_enabled = TRUE)::INTEGER AS enabled_report_definitions,
    COUNT(*) FILTER (WHERE is_enabled = FALSE)::INTEGER AS disabled_report_definitions,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.oiaa_escalation_evaluation_report_runs
    ) AS total_report_runs,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.oiaa_escalation_evaluation_report_runs
        WHERE report_status = 'failed'
    ) AS failed_report_runs,

    (
        SELECT COUNT(*)::INTEGER
        FROM public.oiaa_escalation_evaluation_report_exports
        WHERE export_status = 'failed'
    ) AS failed_exports,

    (
        SELECT MAX(created_at)
        FROM public.oiaa_escalation_evaluation_report_runs
    ) AS latest_report_run_at,

    CASE
        WHEN COUNT(*) = 0 THEN 'not_configured'
        WHEN (
            SELECT COUNT(*)
            FROM public.oiaa_escalation_evaluation_report_runs
            WHERE report_status = 'failed'
        ) > 0 THEN 'report_failure_attention'
        WHEN (
            SELECT COUNT(*)
            FROM public.oiaa_escalation_evaluation_report_exports
            WHERE export_status = 'failed'
        ) > 0 THEN 'export_failure_attention'
        WHEN (
            SELECT MAX(created_at)
            FROM public.oiaa_escalation_evaluation_report_runs
        ) IS NULL THEN 'not_started'
        WHEN (
            SELECT MAX(created_at)
            FROM public.oiaa_escalation_evaluation_report_runs
        ) < NOW() - INTERVAL '7 days' THEN 'stale'
        ELSE 'healthy'
    END AS reporting_health_status
FROM public.oiaa_escalation_evaluation_report_definitions;

COMMENT ON VIEW public.oiaa_escalation_evaluation_reporting_health_view IS
'Shows overall health status for analytics alert escalation evaluation reporting.';

-- ============================================================
-- 12. Initial Report Generation
-- ============================================================

SELECT public.generate_oiaa_escalation_evaluation_report(
    'OIAA_ESCALATION_EVALUATION_HEALTH_REPORT',
    CURRENT_DATE - 7,
    CURRENT_DATE
);

-- ============================================================
-- 13. Row Level Security
-- ============================================================

ALTER TABLE public.oiaa_escalation_evaluation_report_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_report_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_report_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oiaa_escalation_evaluation_report_exports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_report_definitions"
ON public.oiaa_escalation_evaluation_report_definitions;

CREATE POLICY "svc_manage_oiaa_eval_report_definitions"
ON public.oiaa_escalation_evaluation_report_definitions
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_report_runs"
ON public.oiaa_escalation_evaluation_report_runs;

CREATE POLICY "svc_manage_oiaa_eval_report_runs"
ON public.oiaa_escalation_evaluation_report_runs
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_report_sections"
ON public.oiaa_escalation_evaluation_report_sections;

CREATE POLICY "svc_manage_oiaa_eval_report_sections"
ON public.oiaa_escalation_evaluation_report_sections
FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "svc_manage_oiaa_eval_report_exports"
ON public.oiaa_escalation_evaluation_report_exports;

CREATE POLICY "svc_manage_oiaa_eval_report_exports"
ON public.oiaa_escalation_evaluation_report_exports
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
    124,
    'migration_124_order_lifecycle_analytics_alert_escalation_evaluation_reporting',
    'Adds report definitions, report run tracking, report sections, export tracking, report generation functions, dashboard views, and health reporting for analytics alert escalation evaluation analytics.'
)
ON CONFLICT (migration_number) DO UPDATE
SET
    migration_name = EXCLUDED.migration_name,
    migration_scope = EXCLUDED.migration_scope,
    applied_at = NOW();

COMMIT;
