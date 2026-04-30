-- Migration 034 order retention disposition export delivery foundation checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'marketplace_order_retention_disposition_export_delivery_records'),
      ('public', 'marketplace_order_retention_disposition_export_delivery_events')
  ) as expected(schema_name, table_name)
  left join information_schema.tables t
    on t.table_schema = expected.schema_name
   and t.table_name = expected.table_name
  where t.table_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 034 expected tables: %', missing_count;
  end if;
end
$$;

do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'marketplace_order_ret_disp_export_delivery_status'),
      ('public', 'marketplace_order_ret_disp_export_delivery_method'),
      ('public', 'marketplace_order_ret_disp_export_delivery_event'),
      ('public', 'marketplace_order_ret_disp_export_delivery_actor')
  ) as expected(schema_name, type_name)
  left join pg_type t on t.typname = expected.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = expected.schema_name
  where n.oid is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 034 expected enums: %', missing_count;
  end if;
end
$$;

do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_order_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_export_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_evidence_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_requested_by_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_prepared_by_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_sent_by_fk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_received_by_fk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_record_fk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_order_fk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_actor_profile_fk')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'FOREIGN KEY'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 034 expected foreign keys: %', missing_count;
  end if;
end
$$;

do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_reference_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_uri_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_hash_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_recipient_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_note_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_failure_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_failed_reason_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_ready_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_requested_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_prepared_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_sent_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_received_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_failed_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_cancelled_status_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_terminal_exclusive_chk'),
      ('marketplace_order_retention_disposition_export_delivery_records', 'ord_ret_disp_exp_del_records_metadata_object_chk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_status_change_chk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_note_chk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_manual_note_chk'),
      ('marketplace_order_retention_disposition_export_delivery_events', 'ord_ret_disp_exp_del_events_metadata_object_chk')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'CHECK'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 034 expected check constraints: %', missing_count;
  end if;
end
$$;

do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('ord_ret_disp_exp_del_records_reference_key'),
      ('ord_ret_disp_exp_del_records_one_active_per_order_idx'),
      ('ord_ret_disp_exp_del_records_order_id_idx'),
      ('ord_ret_disp_exp_del_records_export_id_idx'),
      ('ord_ret_disp_exp_del_records_evidence_id_idx'),
      ('ord_ret_disp_exp_del_records_requested_by_idx'),
      ('ord_ret_disp_exp_del_records_prepared_by_idx'),
      ('ord_ret_disp_exp_del_records_sent_by_idx'),
      ('ord_ret_disp_exp_del_records_received_by_idx'),
      ('ord_ret_disp_exp_del_records_status_idx'),
      ('ord_ret_disp_exp_del_records_method_idx'),
      ('ord_ret_disp_exp_del_records_ready_at_idx'),
      ('ord_ret_disp_exp_del_records_requested_at_idx'),
      ('ord_ret_disp_exp_del_records_prepared_at_idx'),
      ('ord_ret_disp_exp_del_records_sent_at_idx'),
      ('ord_ret_disp_exp_del_records_received_at_idx'),
      ('ord_ret_disp_exp_del_records_created_at_idx'),
      ('ord_ret_disp_exp_del_events_record_id_idx'),
      ('ord_ret_disp_exp_del_events_order_id_idx'),
      ('ord_ret_disp_exp_del_events_actor_profile_id_idx'),
      ('ord_ret_disp_exp_del_events_actor_role_idx'),
      ('ord_ret_disp_exp_del_events_event_type_idx'),
      ('ord_ret_disp_exp_del_events_previous_status_idx'),
      ('ord_ret_disp_exp_del_events_new_status_idx'),
      ('ord_ret_disp_exp_del_events_created_at_idx')
  ) as expected(index_name)
  left join pg_indexes i
    on i.schemaname = 'public'
   and i.indexname = expected.index_name
  where i.indexname is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 034 expected indexes: %', missing_count;
  end if;
end
$$;
