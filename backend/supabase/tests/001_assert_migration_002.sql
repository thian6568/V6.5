-- Tables expected after 0001-0018.
-- This script must fail fast by raising exceptions when expected schema objects are missing.

-- Tables expected after 0001-0017.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'roles'),
      ('public', 'profiles'),
      ('public', 'audit_logs'),
      ('public', 'artworks'),
      ('public', 'artwork_assets'),
      ('public', 'artwork_authentication'),
      ('public', 'certificates'),
      ('public', 'ownership_history'),
      ('public', 'listings'),
      ('public', 'orders'),
      ('public', 'order_items'),
      ('public', 'escrow_records'),
      ('public', 'subscriptions'),
      ('public', 'refund_requests'),
      ('public', 'disputes'),
      ('public', 'shipping_records'),
      ('public', 'insurance_records'),
      ('public', 'environments'),
      ('public', 'environment_assignments'),
      ('public', 'homepage_content'),
      ('public', 'featured_content'),
      ('public', 'notifications'),
      ('public', 'review_events'),
      ('public', 'marketplace_categories'),
      ('public', 'artwork_category_assignments'),
      ('public', 'marketplace_sections'),
      ('public', 'marketplace_section_items'),
      ('public', 'marketplace_tags'),
      ('public', 'artwork_tag_assignments'),
      ('public', 'listing_filter_metadata'),
      ('public', 'marketplace_sort_options'),
      ('public', 'marketplace_facet_configs'),
      ('public', 'saved_searches'),
      ('public', 'saved_search_filters'),
      ('public', 'marketplace_collections'),
      ('public', 'marketplace_collection_items'),
      ('public', 'wishlists'),
      ('public', 'wishlist_items'),
      ('public', 'marketplace_share_links'),
      ('public', 'marketplace_share_events'),
      ('public', 'marketplace_inquiries'),
      ('public', 'marketplace_inquiry_messages'),
      ('public', 'marketplace_offers'),
      ('public', 'marketplace_offer_events'),
      ('public', 'marketplace_carts'),
      ('public', 'marketplace_cart_items'),
      ('public', 'marketplace_checkout_intents'),
      ('public', 'marketplace_checkout_intent_items')
  ) as expected(schema_name, table_name)
  left join information_schema.tables t
    on t.table_schema = expected.schema_name
   and t.table_name = expected.table_name
  where t.table_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected tables after migration apply: %', missing_count;
  end if;
end
$$;

-- Enum existence checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'role_name'),
      ('public', 'profile_status'),
      ('public', 'publish_status'),
      ('public', 'visibility_mode'),
      ('public', 'authentication_status'),
      ('public', 'listing_status'),
      ('public', 'order_status'),
      ('public', 'escrow_status'),
      ('public', 'subscription_status'),
      ('public', 'refund_status'),
      ('public', 'dispute_type'),
      ('public', 'dispute_status'),
      ('public', 'shipping_status'),
      ('public', 'insurance_status'),
      ('public', 'environment_status'),
      ('public', 'performance_tier'),
      ('public', 'assignment_status'),
      ('public', 'homepage_visibility_status'),
      ('public', 'featured_content_type'),
      ('public', 'featured_content_status'),
      ('public', 'notification_type'),
      ('public', 'notification_status'),
      ('public', 'submission_review_status'),
      ('public', 'publication_status'),
      ('public', 'review_event_type'),
      ('public', 'marketplace_section_type'),
      ('public', 'marketplace_visibility_status'),
      ('public', 'marketplace_tag_type'),
      ('public', 'marketplace_price_bucket'),
      ('public', 'marketplace_size_bucket'),
      ('public', 'marketplace_orientation'),
      ('public', 'marketplace_availability_bucket'),
      ('public', 'marketplace_sort_direction'),
      ('public', 'marketplace_sort_key'),
      ('public', 'marketplace_facet_source_type'),
      ('public', 'marketplace_share_channel'),
      ('public', 'marketplace_inquiry_status'),
      ('public', 'marketplace_inquiry_sender_role'),
      ('public', 'marketplace_contact_request_type'),
      ('public', 'marketplace_offer_status'),
      ('public', 'marketplace_offer_event_type'),
      ('public', 'marketplace_checkout_intent_status'),
      ('public', 'marketplace_checkout_item_source_type')
  ) as expected(schema_name, type_name)
  left join pg_type t on t.typname = expected.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = expected.schema_name
  where n.oid is null;

  if missing_count > 0 then
    raise exception 'Missing expected enums after migration apply: %', missing_count;
  end if;
end
$$;

-- Foreign key checks for shared artwork rule dependencies.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('profiles', 'profiles_role_id_fkey'),
      ('profiles', 'profiles_auth_user_id_fkey'),
      ('audit_logs', 'audit_logs_actor_profile_id_fkey'),
      ('artworks', 'artworks_artist_profile_id_fkey'),
      ('artwork_assets', 'artwork_assets_artwork_id_fkey'),
      ('artwork_authentication', 'artwork_authentication_artwork_id_fkey'),
      ('artwork_authentication', 'artwork_authentication_verified_by_profile_id_fkey'),
      ('certificates', 'certificates_artwork_id_fkey'),
      ('certificates', 'certificates_issued_by_profile_id_fkey'),
      ('ownership_history', 'ownership_history_artwork_id_fkey'),
      ('ownership_history', 'ownership_history_owner_profile_id_fkey'),
      ('listings', 'listings_artwork_id_fkey'),
      ('listings', 'listings_seller_profile_id_fkey'),
      ('orders', 'orders_buyer_profile_id_fkey'),
      ('order_items', 'order_items_order_id_fkey'),
      ('order_items', 'order_items_artwork_id_fkey'),
      ('escrow_records', 'escrow_records_order_id_fkey'),
      ('subscriptions', 'subscriptions_profile_id_fkey'),
      ('refund_requests', 'refund_requests_order_id_fkey'),
      ('refund_requests', 'refund_requests_requester_profile_id_fkey'),
      ('refund_requests', 'refund_requests_reviewed_by_profile_id_fkey'),
      ('disputes', 'disputes_order_id_fkey'),
      ('disputes', 'disputes_artwork_id_fkey'),
      ('disputes', 'disputes_opened_by_profile_id_fkey'),
      ('disputes', 'disputes_assigned_admin_profile_id_fkey'),
      ('disputes', 'disputes_order_item_artwork_fk'),
      ('shipping_records', 'shipping_records_order_id_fkey'),
      ('insurance_records', 'insurance_records_order_id_fkey'),
      ('environment_assignments', 'environment_assignments_environment_id_fkey'),
      ('environment_assignments', 'environment_assignments_artwork_id_fkey'),
      ('homepage_content', 'homepage_content_created_by_profile_id_fkey'),
      ('homepage_content', 'homepage_content_updated_by_profile_id_fkey'),
      ('featured_content', 'featured_content_artwork_id_fkey'),
      ('featured_content', 'featured_content_created_by_profile_id_fkey'),
      ('featured_content', 'featured_content_updated_by_profile_id_fkey'),
      ('notifications', 'notifications_profile_id_fkey'),
      ('notifications', 'notifications_artwork_id_fkey'),
      ('notifications', 'notifications_created_by_profile_id_fkey'),
      ('review_events', 'review_events_actor_profile_id_fkey'),
      ('review_events', 'review_events_artwork_id_fkey'),
      ('review_events', 'review_events_listing_id_fkey'),
      ('marketplace_categories', 'marketplace_categories_parent_category_id_fkey'),
      ('artwork_category_assignments', 'artwork_category_assignments_artwork_id_fkey'),
      ('artwork_category_assignments', 'artwork_category_assignments_category_id_fkey'),
      ('marketplace_sections', 'marketplace_sections_created_by_profile_id_fkey'),
      ('marketplace_sections', 'marketplace_sections_updated_by_profile_id_fkey'),
      ('marketplace_section_items', 'marketplace_section_items_section_id_fkey'),
      ('marketplace_section_items', 'marketplace_section_items_artwork_id_fkey'),
      ('marketplace_section_items', 'marketplace_section_items_listing_id_fkey'),
      ('artwork_tag_assignments', 'artwork_tag_assignments_artwork_id_fkey'),
      ('artwork_tag_assignments', 'artwork_tag_assignments_tag_id_fkey'),
      ('listing_filter_metadata', 'listing_filter_metadata_listing_id_fkey'),
      ('saved_searches', 'saved_searches_profile_id_fkey'),
      ('saved_searches', 'saved_searches_sort_option_id_fkey'),
      ('saved_search_filters', 'saved_search_filters_saved_search_id_fkey'),
      ('marketplace_collections', 'marketplace_collections_created_by_profile_id_fkey'),
      ('marketplace_collections', 'marketplace_collections_updated_by_profile_id_fkey'),
      ('marketplace_collection_items', 'marketplace_collection_items_collection_id_fkey'),
      ('marketplace_collection_items', 'marketplace_collection_items_artwork_id_fkey'),
      ('marketplace_collection_items', 'marketplace_collection_items_listing_id_fkey'),
      ('wishlists', 'wishlists_profile_id_fkey'),
      ('wishlist_items', 'wishlist_items_wishlist_id_fkey'),
      ('wishlist_items', 'wishlist_items_artwork_id_fkey'),
      ('wishlist_items', 'wishlist_items_listing_id_fkey'),
      ('marketplace_share_links', 'marketplace_share_links_profile_id_fkey'),
      ('marketplace_share_links', 'marketplace_share_links_artwork_id_fkey'),
      ('marketplace_share_links', 'marketplace_share_links_listing_id_fkey'),
      ('marketplace_share_events', 'marketplace_share_events_share_link_id_fkey'),
      ('marketplace_share_events', 'marketplace_share_events_viewer_profile_id_fkey'),
      ('marketplace_inquiries', 'marketplace_inquiries_buyer_profile_id_fkey'),
      ('marketplace_inquiries', 'marketplace_inquiries_seller_profile_id_fkey'),
      ('marketplace_inquiries', 'marketplace_inquiries_artwork_id_fkey'),
      ('marketplace_inquiries', 'marketplace_inquiries_listing_id_fkey'),
      ('marketplace_inquiry_messages', 'marketplace_inquiry_messages_inquiry_id_fkey'),
      ('marketplace_inquiry_messages', 'marketplace_inquiry_messages_sender_profile_id_fkey'),
      ('marketplace_offers', 'marketplace_offers_buyer_profile_id_fkey'),
      ('marketplace_offers', 'marketplace_offers_seller_profile_id_fkey'),
      ('marketplace_offers', 'marketplace_offers_artwork_id_fkey'),
      ('marketplace_offers', 'marketplace_offers_listing_id_fkey'),
      ('marketplace_offers', 'marketplace_offers_inquiry_id_fkey'),
      ('marketplace_offer_events', 'marketplace_offer_events_offer_id_fkey'),
      ('marketplace_offer_events', 'marketplace_offer_events_actor_profile_id_fkey'),
      ('marketplace_carts', 'marketplace_carts_buyer_profile_id_fkey'),
      ('marketplace_cart_items', 'marketplace_cart_items_cart_id_fkey'),
      ('marketplace_cart_items', 'marketplace_cart_items_artwork_id_fkey'),
      ('marketplace_cart_items', 'marketplace_cart_items_listing_id_fkey'),
      ('marketplace_cart_items', 'marketplace_cart_items_added_from_offer_id_fkey'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_buyer_profile_id_fkey'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_cart_id_fkey'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_checkout_intent_id_fkey'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_cart_item_id_fkey'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_artwork_id_fkey'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_listing_id_fkey'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_offer_id_fkey')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'FOREIGN KEY'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected foreign keys after migration apply: %', missing_count;
  end if;
end
$$;

-- Check constraint checks including Migration 008, 009, 010, 011, 012, 013, 014, 015, and 016.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('artworks', 'artworks_width_cm_positive_chk'),
      ('artworks', 'artworks_height_cm_positive_chk'),
      ('artworks', 'artworks_thickness_cm_positive_chk'),
      ('artworks', 'artworks_width_in_positive_chk'),
      ('artworks', 'artworks_height_in_positive_chk'),
      ('artworks', 'artworks_thickness_in_positive_chk'),
      ('artworks', 'artworks_reviewed_after_submitted_chk'),
      ('artworks', 'artworks_published_after_scheduled_chk'),
      ('listings', 'listings_price_amount_nonnegative_chk'),
      ('listings', 'listings_price_currency_upper_chk'),
      ('listings', 'listings_sale_price_amount_nonnegative_chk'),
      ('listings', 'listings_sale_price_currency_upper_chk'),
      ('listings', 'listings_sale_price_not_above_price_chk'),
      ('listings', 'listings_sale_currency_requires_sale_price_chk'),
      ('listings', 'listings_reviewed_after_submitted_chk'),
      ('listings', 'listings_published_after_scheduled_chk'),
      ('listings', 'listings_price_parity_with_legacy_chk'),
      ('listings', 'listings_discovery_rank_nonnegative_chk'),
      ('listings', 'listings_available_window_chk'),
      ('review_events', 'review_events_exactly_one_target_chk'),
      ('marketplace_categories', 'marketplace_categories_slug_nonblank_chk'),
      ('marketplace_categories', 'marketplace_categories_name_nonblank_chk'),
      ('marketplace_categories', 'marketplace_categories_sort_order_nonnegative_chk'),
      ('marketplace_sections', 'marketplace_sections_slug_nonblank_chk'),
      ('marketplace_sections', 'marketplace_sections_title_nonblank_chk'),
      ('marketplace_sections', 'marketplace_sections_sort_order_nonnegative_chk'),
      ('marketplace_section_items', 'marketplace_section_items_exactly_one_target_chk'),
      ('marketplace_tags', 'marketplace_tags_slug_nonblank_chk'),
      ('marketplace_tags', 'marketplace_tags_name_nonblank_chk'),
      ('marketplace_tags', 'marketplace_tags_sort_order_nonnegative_chk'),
      ('listings', 'listings_search_keywords_nonblank_chk'),
      ('listings', 'listings_search_document_nonblank_chk'),
      ('marketplace_sort_options', 'marketplace_sort_options_slug_nonblank_chk'),
      ('marketplace_sort_options', 'marketplace_sort_options_name_nonblank_chk'),
      ('marketplace_sort_options', 'marketplace_sort_options_sort_order_nonnegative_chk'),
      ('marketplace_facet_configs', 'marketplace_facet_configs_facet_key_nonblank_chk'),
      ('marketplace_facet_configs', 'marketplace_facet_configs_label_nonblank_chk'),
      ('marketplace_facet_configs', 'marketplace_facet_configs_sort_order_nonnegative_chk'),
      ('saved_searches', 'saved_searches_name_nonblank_chk'),
      ('saved_searches', 'saved_searches_query_text_nonblank_chk'),
      ('saved_search_filters', 'saved_search_filters_filter_key_nonblank_chk'),
      ('saved_search_filters', 'saved_search_filters_filter_value_nonblank_chk'),
      ('marketplace_collections', 'marketplace_collections_slug_nonblank_chk'),
      ('marketplace_collections', 'marketplace_collections_title_nonblank_chk'),
      ('marketplace_collections', 'marketplace_collections_sort_order_nonnegative_chk'),
      ('marketplace_collection_items', 'marketplace_collection_items_sort_order_nonnegative_chk'),
      ('marketplace_collection_items', 'marketplace_collection_items_exactly_one_target_chk'),
      ('wishlists', 'wishlists_name_nonblank_chk'),
      ('wishlist_items', 'wishlist_items_exactly_one_target_chk'),
      ('marketplace_share_links', 'marketplace_share_links_exactly_one_target_chk'),
      ('marketplace_share_links', 'marketplace_share_links_share_token_nonblank_chk'),
      ('marketplace_share_links', 'marketplace_share_links_destination_url_nonblank_chk'),
      ('marketplace_share_events', 'marketplace_share_events_event_type_nonblank_chk'),
      ('marketplace_share_events', 'marketplace_share_events_metadata_object_chk'),
      ('marketplace_inquiries', 'marketplace_inquiries_exactly_one_target_chk'),
      ('marketplace_inquiries', 'marketplace_inquiries_buyer_seller_different_chk'),
      ('marketplace_inquiries', 'marketplace_inquiries_subject_nonblank_chk'),
      ('marketplace_inquiries', 'marketplace_inquiries_initial_message_nonblank_chk'),
      ('marketplace_inquiry_messages', 'marketplace_inquiry_messages_message_body_nonblank_chk'),
      ('marketplace_inquiry_messages', 'marketplace_inquiry_messages_metadata_object_chk'),
      ('marketplace_offers', 'marketplace_offers_exactly_one_target_chk'),
      ('marketplace_offers', 'marketplace_offers_buyer_seller_different_chk'),
      ('marketplace_offers', 'marketplace_offers_offer_amount_positive_chk'),
      ('marketplace_offers', 'marketplace_offers_offer_currency_code_chk'),
      ('marketplace_offers', 'marketplace_offers_terminal_timestamps_exclusive_chk'),
      ('marketplace_offers', 'marketplace_offers_accepted_status_timestamp_chk'),
      ('marketplace_offers', 'marketplace_offers_declined_status_timestamp_chk'),
      ('marketplace_offers', 'marketplace_offers_cancelled_status_timestamp_chk'),
      ('marketplace_offer_events', 'marketplace_offer_events_event_amount_positive_chk'),
      ('marketplace_offer_events', 'marketplace_offer_events_event_currency_code_chk'),
      ('marketplace_offer_events', 'marketplace_offer_events_note_nonblank_chk'),
      ('marketplace_offer_events', 'marketplace_offer_events_metadata_object_chk'),
      ('marketplace_carts', 'marketplace_carts_name_nonblank_chk'),
      ('marketplace_cart_items', 'marketplace_cart_items_exactly_one_target_chk'),
      ('marketplace_cart_items', 'marketplace_cart_items_quantity_positive_chk'),
      ('marketplace_cart_items', 'marketplace_cart_items_note_nonblank_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_currency_code_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_subtotal_nonnegative_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_discount_nonnegative_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_total_nonnegative_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_discount_not_above_subtotal_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_total_amount_consistency_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_submitted_status_timestamp_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_cancelled_status_timestamp_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_terminal_timestamps_exclusive_chk'),
      ('marketplace_checkout_intents', 'marketplace_checkout_intents_metadata_object_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_unit_amount_nonnegative_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_quantity_positive_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_line_subtotal_nonnegative_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_line_subtotal_consistency_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_metadata_object_chk'),
      ('marketplace_checkout_intent_items', 'marketplace_checkout_intent_items_source_link_chk')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'CHECK'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected check constraints after migration apply: %', missing_count;
  end if;
end
$$;

-- Unique constraints / unique indexes checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'roles_name_key'),
      ('public', 'profiles_auth_user_id_key'),
      ('public', 'artwork_assets_unique_path_per_artwork'),
      ('public', 'artwork_authentication_artwork_id_key'),
      ('public', 'certificates_certificate_number_key'),
      ('public', 'ownership_history_one_current_owner_idx'),
      ('public', 'orders_order_number_key'),
      ('public', 'order_items_order_id_artwork_id_key'),
      ('public', 'escrow_records_order_id_key'),
      ('public', 'subscriptions_one_active_per_profile_idx'),
      ('public', 'shipping_records_order_id_key'),
      ('public', 'insurance_records_order_id_key'),
      ('public', 'environments_name_key'),
      ('public', 'environments_runtime_key_key'),
      ('public', 'environment_assignments_unique_active_artwork_idx'),
      ('public', 'environment_assignments_unique_active_anchor_idx'),
      ('public', 'homepage_content_slug_key'),
      ('public', 'featured_content_one_active_artwork_idx'),
      ('public', 'marketplace_categories_slug_key'),
      ('public', 'artwork_category_assignments_artwork_id_category_id_key'),
      ('public', 'artwork_category_assignments_one_primary_per_artwork_idx'),
      ('public', 'marketplace_sections_slug_key'),
      ('public', 'marketplace_tags_slug_key'),
      ('public', 'artwork_tag_assignments_artwork_id_tag_id_key'),
      ('public', 'listing_filter_metadata_listing_id_key'),
      ('public', 'marketplace_sort_options_slug_key'),
      ('public', 'marketplace_facet_configs_facet_key_key'),
      ('public', 'marketplace_collections_slug_key'),
      ('public', 'marketplace_collection_items_collection_artwork_unique_idx'),
      ('public', 'marketplace_collection_items_collection_listing_unique_idx'),
      ('public', 'wishlists_one_default_per_profile_idx'),
      ('public', 'wishlist_items_wishlist_artwork_unique_idx'),
      ('public', 'wishlist_items_wishlist_listing_unique_idx'),
      ('public', 'marketplace_share_links_share_token_key'),
      ('public', 'marketplace_carts_one_default_per_buyer_idx')
  ) as expected(schema_name, object_name)
  left join (
    select connamespace as namespace_oid, conname as object_name
    from pg_constraint
    where contype = 'u'
    union all
    select i.schemaname::regnamespace::oid as namespace_oid, i.indexname as object_name
    from pg_indexes i
  ) existing
    on existing.object_name = expected.object_name
   and existing.namespace_oid = expected.schema_name::regnamespace::oid
  where existing.object_name is null;

  if missing_count > 0 then
    raise exception 'Missing expected unique constraints/indexes after migration apply: %', missing_count;
  end if;
end
$$;

-- Index checks for Migration 002 + 003 + 004 + 008 + 009 + 010 + 011 + 012 + 013 + 014 + 015 + 016 performance paths.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('artworks_artist_profile_id_idx'),
      ('artworks_publish_status_idx'),
      ('artworks_visibility_mode_idx'),
      ('artwork_assets_artwork_id_idx'),
      ('artwork_assets_primary_idx'),
      ('artwork_authentication_status_idx'),
      ('artwork_authentication_verified_by_idx'),
      ('certificates_artwork_id_idx'),
      ('ownership_history_artwork_id_idx'),
      ('ownership_history_owner_profile_id_idx'),
      ('ownership_history_one_current_owner_idx'),
      ('listings_artwork_id_idx'),
      ('listings_seller_profile_id_idx'),
      ('listings_status_idx'),
      ('orders_buyer_profile_id_idx'),
      ('orders_status_idx'),
      ('orders_placed_at_idx'),
      ('order_items_order_id_idx'),
      ('order_items_artwork_id_idx'),
      ('escrow_records_status_idx'),
      ('subscriptions_profile_id_idx'),
      ('subscriptions_status_idx'),
      ('subscriptions_one_active_per_profile_idx'),
      ('refund_requests_order_id_idx'),
      ('refund_requests_requester_profile_id_idx'),
      ('refund_requests_status_idx'),
      ('disputes_order_id_idx'),
      ('disputes_artwork_id_idx'),
      ('disputes_opened_by_profile_id_idx'),
      ('disputes_assigned_admin_profile_id_idx'),
      ('disputes_type_status_idx'),
      ('shipping_records_status_idx'),
      ('shipping_records_tracking_number_idx'),
      ('insurance_records_status_idx'),
      ('insurance_records_policy_number_idx'),
      ('environments_status_idx'),
      ('environments_performance_tier_idx'),
      ('environment_assignments_environment_id_idx'),
      ('environment_assignments_artwork_id_idx'),
      ('environment_assignments_status_idx'),
      ('environment_assignments_unique_active_artwork_idx'),
      ('environment_assignments_unique_active_anchor_idx'),
      ('homepage_content_visibility_status_idx'),
      ('homepage_content_sort_order_idx'),
      ('featured_content_status_idx'),
      ('featured_content_type_idx'),
      ('featured_content_sort_order_idx'),
      ('featured_content_artwork_id_idx'),
      ('featured_content_one_active_artwork_idx'),
      ('notifications_profile_id_idx'),
      ('notifications_status_idx'),
      ('notifications_notification_type_idx'),
      ('notifications_profile_status_created_at_idx'),
      ('artworks_review_status_idx'),
      ('artworks_publication_status_idx'),
      ('artworks_scheduled_publish_at_idx'),
      ('listings_review_status_idx'),
      ('listings_publication_status_idx'),
      ('listings_scheduled_publish_at_idx'),
      ('review_events_actor_profile_id_idx'),
      ('review_events_artwork_id_idx'),
      ('review_events_listing_id_idx'),
      ('review_events_event_type_idx'),
      ('marketplace_categories_parent_category_id_idx'),
      ('marketplace_categories_is_active_idx'),
      ('marketplace_categories_is_active_sort_order_idx'),
      ('artwork_category_assignments_artwork_id_idx'),
      ('artwork_category_assignments_category_id_idx'),
      ('artwork_category_assignments_one_primary_per_artwork_idx'),
      ('marketplace_sections_section_type_idx'),
      ('marketplace_sections_is_active_idx'),
      ('marketplace_sections_is_active_sort_order_idx'),
      ('marketplace_section_items_section_id_idx'),
      ('marketplace_section_items_artwork_id_idx'),
      ('marketplace_section_items_listing_id_idx'),
      ('marketplace_section_items_section_id_sort_order_idx'),
      ('listings_marketplace_visibility_idx'),
      ('listings_is_featured_idx'),
      ('listings_discovery_rank_idx'),
      ('listings_available_from_idx'),
      ('listings_available_until_idx'),
      ('marketplace_tags_tag_type_idx'),
      ('marketplace_tags_is_active_idx'),
      ('marketplace_tags_is_active_sort_order_idx'),
      ('artwork_tag_assignments_artwork_id_idx'),
      ('artwork_tag_assignments_tag_id_idx'),
      ('artwork_tag_assignments_primary_artwork_idx'),
      ('listing_filter_metadata_price_bucket_idx'),
      ('listing_filter_metadata_size_bucket_idx'),
      ('listing_filter_metadata_orientation_idx'),
      ('listing_filter_metadata_availability_bucket_idx'),
      ('listings_is_searchable_idx'),
      ('marketplace_sort_options_is_active_idx'),
      ('marketplace_sort_options_is_active_sort_order_idx'),
      ('marketplace_sort_options_sort_key_idx'),
      ('marketplace_facet_configs_source_type_idx'),
      ('marketplace_facet_configs_is_active_idx'),
      ('marketplace_facet_configs_is_active_sort_order_idx'),
      ('saved_searches_profile_id_idx'),
      ('saved_searches_sort_option_id_idx'),
      ('saved_searches_profile_id_is_active_idx'),
      ('saved_search_filters_saved_search_id_idx'),
      ('saved_search_filters_filter_key_idx'),
      ('saved_search_filters_saved_search_id_filter_key_idx'),
      ('marketplace_collections_created_by_profile_id_idx'),
      ('marketplace_collections_updated_by_profile_id_idx'),
      ('marketplace_collections_is_active_idx'),
      ('marketplace_collections_is_active_sort_order_idx'),
      ('marketplace_collection_items_collection_id_idx'),
      ('marketplace_collection_items_artwork_id_idx'),
      ('marketplace_collection_items_listing_id_idx'),
      ('marketplace_collection_items_collection_id_sort_order_idx'),
      ('wishlists_profile_id_idx'),
      ('wishlists_profile_id_is_active_idx'),
      ('wishlist_items_wishlist_id_idx'),
      ('wishlist_items_artwork_id_idx'),
      ('wishlist_items_listing_id_idx'),
      ('marketplace_share_links_profile_id_idx'),
      ('marketplace_share_links_artwork_id_idx'),
      ('marketplace_share_links_listing_id_idx'),
      ('marketplace_share_links_share_channel_idx'),
      ('marketplace_share_links_is_active_idx'),
      ('marketplace_share_links_expires_at_idx'),
      ('marketplace_share_events_share_link_id_idx'),
      ('marketplace_share_events_viewer_profile_id_idx'),
      ('marketplace_share_events_event_type_idx'),
      ('marketplace_share_events_created_at_idx'),
      ('marketplace_inquiries_buyer_profile_id_idx'),
      ('marketplace_inquiries_seller_profile_id_idx'),
      ('marketplace_inquiries_artwork_id_idx'),
      ('marketplace_inquiries_listing_id_idx'),
      ('marketplace_inquiries_status_idx'),
      ('marketplace_inquiries_is_active_idx'),
      ('marketplace_inquiries_last_message_at_idx'),
      ('marketplace_inquiries_created_at_idx'),
      ('marketplace_inquiry_messages_inquiry_id_idx'),
      ('marketplace_inquiry_messages_sender_profile_id_idx'),
      ('marketplace_inquiry_messages_sender_role_idx'),
      ('marketplace_inquiry_messages_created_at_idx'),
      ('marketplace_offers_buyer_profile_id_idx'),
      ('marketplace_offers_seller_profile_id_idx'),
      ('marketplace_offers_artwork_id_idx'),
      ('marketplace_offers_listing_id_idx'),
      ('marketplace_offers_inquiry_id_idx'),
      ('marketplace_offers_status_idx'),
      ('marketplace_offers_expires_at_idx'),
      ('marketplace_offers_last_event_at_idx'),
      ('marketplace_offers_created_at_idx'),
      ('marketplace_offer_events_offer_id_idx'),
      ('marketplace_offer_events_actor_profile_id_idx'),
      ('marketplace_offer_events_event_type_idx'),
      ('marketplace_offer_events_created_at_idx'),
      ('marketplace_carts_buyer_profile_id_idx'),
      ('marketplace_carts_buyer_profile_id_is_active_idx'),
      ('marketplace_carts_one_default_per_buyer_idx'),
      ('marketplace_cart_items_cart_id_idx'),
      ('marketplace_cart_items_artwork_id_idx'),
      ('marketplace_cart_items_listing_id_idx'),
      ('marketplace_cart_items_added_from_offer_id_idx'),
      ('marketplace_checkout_intents_buyer_profile_id_idx'),
      ('marketplace_checkout_intents_cart_id_idx'),
      ('marketplace_checkout_intents_status_idx'),
      ('marketplace_checkout_intents_expires_at_idx'),
      ('marketplace_checkout_intents_created_at_idx'),
      ('marketplace_checkout_intent_items_checkout_intent_id_idx'),
      ('marketplace_checkout_intent_items_cart_item_id_idx'),
      ('marketplace_checkout_intent_items_artwork_id_idx'),
      ('marketplace_checkout_intent_items_listing_id_idx'),
      ('marketplace_checkout_intent_items_offer_id_idx'),
      ('marketplace_checkout_intent_items_source_type_idx')
  ) as expected(index_name)
  left join pg_indexes i
    on i.schemaname = 'public'
   and i.indexname = expected.index_name
  where i.indexname is null;

  if missing_count > 0 then
    raise exception 'Missing expected indexes after migration apply: %', missing_count;
  end if;
end
$$;

-- Shared artwork rule checks: single main artwork identity table and no VR-specific duplicate.
do $$
declare
  duplicate_count integer;
begin
  select count(*) into duplicate_count
  from information_schema.tables
  where table_schema = 'public'
    and table_name in ('vr_artworks', 'gallery_artworks', 'marketplace_artworks');

  if duplicate_count > 0 then
    raise exception 'Found duplicate/VR-specific artwork table(s): %', duplicate_count;
  end if;
end
$$;

-- Migration 018 checkout order draft conversion checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'marketplace_order_drafts'),
      ('public', 'marketplace_order_draft_items'),
      ('public', 'marketplace_order_conversion_events')
  ) as expected(schema_name, table_name)
  left join information_schema.tables t
    on t.table_schema = expected.schema_name
   and t.table_name = expected.table_name
  where t.table_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 018 expected tables: %', missing_count;
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
      ('public', 'marketplace_order_draft_status'),
      ('public', 'marketplace_order_conversion_event_type'),
      ('public', 'marketplace_order_draft_item_source_type')
  ) as expected(schema_name, type_name)
  left join pg_type t on t.typname = expected.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = expected.schema_name
  where n.oid is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 018 expected enums: %', missing_count;
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
      ('marketplace_order_drafts', 'marketplace_order_drafts_checkout_intent_id_fkey'),
      ('marketplace_order_drafts', 'marketplace_order_drafts_invoice_draft_id_fkey'),
      ('marketplace_order_drafts', 'marketplace_order_drafts_buyer_profile_id_fkey'),
      ('marketplace_order_drafts', 'marketplace_order_drafts_target_order_id_fkey'),
      ('marketplace_order_draft_items', 'marketplace_order_draft_items_order_draft_id_fkey'),
      ('marketplace_order_draft_items', 'marketplace_order_draft_items_invoice_draft_item_id_fkey'),
      ('marketplace_order_draft_items', 'marketplace_order_draft_items_checkout_intent_item_id_fkey'),
      ('marketplace_order_conversion_events', 'marketplace_order_conversion_events_order_draft_id_fkey'),
      ('marketplace_order_conversion_events', 'marketplace_order_conversion_events_actor_profile_id_fkey')
  ) as expected(table_name, constraint_name)
  left join information_schema.table_constraints tc
    on tc.table_schema = 'public'
   and tc.table_name = expected.table_name
   and tc.constraint_name = expected.constraint_name
   and tc.constraint_type = 'FOREIGN KEY'
  where tc.constraint_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 018 expected foreign keys: %', missing_count;
  end if;
end
$$;

-- Migration 019 order finalization foundation checks.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (
    values
      ('public', 'marketplace_order_finalizations'),
      ('public', 'marketplace_order_finalization_events')
  ) as expected(schema_name, table_name)
  left join information_schema.tables t
    on t.table_schema = expected.schema_name
   and t.table_name = expected.table_name
  where t.table_name is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 019 expected tables: %', missing_count;
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
      ('public', 'marketplace_order_finalization_status'),
      ('public', 'marketplace_order_finalization_event_type')
  ) as expected(schema_name, type_name)
  left join pg_type t on t.typname = expected.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = expected.schema_name
  where n.oid is null;

  if missing_count > 0 then
    raise exception 'Missing Migration 019 expected enums: %', missing_count;
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
      ('marketplace_order_finalizations', 'order_draft_id', 'marketplace_order_drafts'),
      ('marketplace_order_finalizations', 'order_id', 'orders'),
      ('marketplace_order_finalizations', 'buyer_profile_id', 'profiles'),
      ('marketplace_order_finalization_events', 'order_finalization_id', 'marketplace_order_finalizations'),
      ('marketplace_order_finalization_events', 'actor_profile_id', 'profiles')
  ) as expected(table_name, column_name, referenced_table_name)
  where not exists (
    select 1
    from pg_constraint con
    join pg_class tbl on tbl.oid = con.conrelid
    join pg_namespace ns on ns.oid = tbl.relnamespace
    join pg_class ref_tbl on ref_tbl.oid = con.confrelid
    join pg_namespace ref_ns on ref_ns.oid = ref_tbl.relnamespace
    join lateral (
      select array_agg(att.attname order by keys.ordinality) as column_names
      from unnest(con.conkey) with ordinality as keys(attnum, ordinality)
      join pg_attribute att
        on att.attrelid = con.conrelid
       and att.attnum = keys.attnum
    ) fk_columns on true
    where con.contype = 'f'
      and ns.nspname = 'public'
      and tbl.relname = expected.table_name
      and ref_ns.nspname = 'public'
      and ref_tbl.relname = expected.referenced_table_name
      and fk_columns.column_names = array[expected.column_name::name]
  );

  if missing_count > 0 then
    raise exception 'Missing Migration 019 expected foreign key relationships: %', missing_count;
  end if;
end
$$;

