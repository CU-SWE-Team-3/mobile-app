// ─────────────────────────────────────────────────────────────────────────────
// BioBeats — Integration Test Keys  (Phase 4 — Modules 7 · 8 · 9 · 10 · 12)
// Single source-of-truth. Update here when the app renames a key.
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════
// MODULE 7 — Sets & Playlists
// ══════════════════════════════════════════════════════════════
const String kPlaylistsCreateFab        = 'playlists_create_fab';
const String kPlaylistTile              = 'playlist_tile';
String       kPlaylistTileById(String id) => 'playlist_tile_$id';

const String kPlaylistNameField         = 'playlist_name_field';
const String kPlaylistDescField         = 'playlist_description_field';
const String kPlaylistPrivacyToggle     = 'playlist_privacy_toggle';
const String kPlaylistSaveButton        = 'playlist_save_button';
const String kPlaylistBackButton        = 'playlist_back_button';

const String kPlaylistTrackTile         = 'playlist_track_tile';
String       kPlaylistTrackTileById(String id) => 'playlist_track_tile_$id';
String       kPlaylistTrackTileByIdx(int i)    => 'playlist_track_tile_$i';

const String kPlaylistDragHandle        = 'playlist_drag_handle';
String       kPlaylistDragHandleByIdx(int i)   => 'playlist_drag_handle_$i';
const String kPlaylistRemoveTrackBtn    = 'playlist_remove_track_button';
const String kPlaylistAddTracksButton   = 'playlist_add_tracks_button';
const String kPlaylistDeleteButton      = 'playlist_delete_button';

// ══════════════════════════════════════════════════════════════
// MODULE 8 — Feed, Search & Discovery
// ══════════════════════════════════════════════════════════════

// Home page
const String kHomeScaffold              = 'home_scaffold';
const String kHomeGetProButton          = 'home_get_pro_button';
const String kHomeUploadButton          = 'home_upload_button';
const String kHomeMessagesButton        = 'home_messages_button';
const String kHomeNotificationsButton   = 'home_notifications_button';
const String kHomeContentList           = 'home_content_list';
const String kHomeRecommendedList       = 'home_recommended_list';
const String kHomeMixedList             = 'home_mixed_list';
const String kHomeCuratedList           = 'home_curated_list';
const String kHomeLikedByList           = 'home_liked_by_list';
const String kHomeStationList           = 'home_station_list';
const String kHomeBuzzingList           = 'home_buzzing_list';
const String kHomeLikedByFollowingList  = 'home_liked_by_following_list';
const String kHomeLoading               = 'home_loading';
const String kHomeError                 = 'home_error';
String       kHomeGenreChip(String g)   => 'home_genre_chip_${g.toLowerCase()}';

// Following feed page
const String kFeedFollowingScaffold    = 'feed_following_scaffold';
const String kFeedFollowingLoading     = 'feed_following_loading';
const String kFeedFollowingError       = 'feed_following_error';
const String kFeedFollowingEmpty       = 'feed_following_empty';
const String kFeedTrackList            = 'feed_track_list';
const String kFeedTrackTile            = 'feed_track_tile';
const String kFeedRetryButton          = 'feed_retry_button';

// Search page
const String kSearchScaffold           = 'search_scaffold';
const String kSearchField              = 'search_field';
const String kSearchClearButton        = 'search_clear_button';
const String kSearchFilterTabBar       = 'search_filter_tab_bar';
const String kSearchTabTracks          = 'search_tab_tracks';
const String kSearchTabUsers           = 'search_tab_users';
const String kSearchTabPlaylists       = 'search_tab_playlists';
const String kSearchHistoryEmpty       = 'search_history_empty';
const String kSearchHistoryList        = 'search_history_list';
const String kSearchResultsLoading     = 'search_results_loading';
const String kSearchResultsError       = 'search_results_error';
const String kSearchRetryButton        = 'search_retry_button';
const String kSearchNoResults          = 'search_no_results';
const String kSearchResultsList        = 'search_results_list';
const String kSearchTrackTile          = 'search_track_tile';
const String kSearchUserTile           = 'search_user_tile';
const String kSearchPlaylistTile       = 'search_playlist_tile';
const String kSearchVibesGrid          = 'search_vibes_grid';
String       kSearchGenreCard(String g) => 'search_genre_card_$g';

// Trending
const String kTrendingTrackTile        = 'trending_track_tile';
const String kTrendingLoading          = 'trending_loading';

// ══════════════════════════════════════════════════════════════
// MODULE 9 — Messaging & Track Sharing
// ══════════════════════════════════════════════════════════════
const String kConversationsList              = 'conversations_list';
const String kMessagingComposeButton         = 'messaging_compose_button';
const String kMessagingRetryButton           = 'messaging_retry_button';
const String kChatBackButton                 = 'chat_back_button';
String       kConversationTile(int i)        => 'conversation_tile_$i';

const String kMessageList                    = 'message_list';
const String kMessageInputField              = 'message_input_field';
const String kMessageSendButton              = 'message_send_button';
const String kMessageAttachButton            = 'message_attach_button';
const String kMessageStatusIndicator         = 'message_status_indicator';
const String kMessageTrackCard               = 'message_track_card';
String       kMessageBubble(int i)           => 'message_bubble_$i';

const String kMessagingRecipientSearchField  = 'messaging_recipient_search_field';

// ══════════════════════════════════════════════════════════════
// MODULE 10 — Real-Time Notifications
// ══════════════════════════════════════════════════════════════
const String kNotificationsBackButton    = 'notifications_back_button';
const String kNotificationsMarkAllRead   = 'notifications_mark_all_read_button';
const String kNotificationsFilterButton  = 'notifications_filter_button';
const String kNotificationsRetryButton   = 'notifications_retry_button';
const String kNotificationsList          = 'notifications_list';
const String kNotificationUnreadDot      = 'notification_unread_dot';
String       kNotificationTile(int i)    => 'notification_tile_$i';
String       kNotificationDismiss(String id) => 'notification_dismiss_$id';

// ══════════════════════════════════════════════════════════════
// MODULE 12 — Premium Subscription
// ══════════════════════════════════════════════════════════════
const String kPremiumSubscribeButton   = 'premium_subscribe_button';
const String kPremiumCurrentPlanLabel  = 'premium_current_plan_label';
const String kPremiumPlanTile          = 'premium_plan_tile';
const String kPremiumConfirmButton     = 'premium_confirm_button';
const String kPremiumDownloadButton    = 'premium_download_button';
const String kPaywallDismissButton     = 'paywall_dismiss_button';
String       kPremiumPlanTileByIdx(int i) => 'premium_plan_tile_$i';