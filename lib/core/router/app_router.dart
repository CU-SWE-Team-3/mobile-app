import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/start_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/email_verification_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/oauth_login_page.dart';

import '../../features/feed/presentation/pages/home_page.dart';
import '../../features/feed/presentation/pages/search_page.dart';
import '../../features/feed/presentation/pages/discover_page.dart';
import '../../features/feed/presentation/pages/following_feed_page.dart';
import '../../features/feed/presentation/pages/search_results_tracks_page.dart';
import '../../features/feed/presentation/pages/search_results_users_page.dart';
import '../../features/feed/presentation/pages/search_results_playlists_page.dart';
import '../../features/feed/presentation/pages/electronic_genre_page.dart';
import '../../features/feed/presentation/pages/hiphop_genre_page.dart';
import '../../features/feed/presentation/pages/pop_genre_page.dart';
import '../../features/feed/presentation/pages/trending_charts_page.dart';
import '../../features/feed/presentation/pages/cast_page.dart';

import '../../features/upload/presentation/pages/upload_page.dart';
import '../../features/upload/presentation/pages/upload_progress_page.dart';
import '../../features/upload/presentation/pages/metadata_input_page.dart';
import '../../features/upload/presentation/pages/waveform_preview_page.dart';

import '../../features/library/presentation/pages/library_page.dart';
import '../../features/library/presentation/pages/library_albums_page.dart';
import '../../features/library/presentation/pages/library_stations_page.dart';
import '../../features/library/presentation/pages/library_uploads_page.dart';
import '../../features/library/presentation/pages/library_playlists_page.dart';
import '../../features/library/presentation/pages/library_likes_page.dart';
import '../../features/library/presentation/pages/your_insights_page.dart';
import '../../features/library/presentation/pages/library_following_page.dart';

import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_tracks_page.dart';
import '../../features/profile/presentation/pages/profile_reposts_page.dart';
import '../../features/profile/presentation/pages/profile_insights_page.dart';
import '../../features/profile/presentation/pages/avatar_upload_page.dart';
import '../../features/profile/presentation/pages/cover_photo_upload_page.dart';
import '../../features/profile/presentation/pages/avatar_viewer_page.dart';

import '../../features/followers/presentation/pages/followers_list_page.dart';
import '../../features/followers/presentation/pages/following_list_page.dart';
import '../../features/followers/presentation/pages/suggested_users_page.dart';



import '../../features/player/presentation/pages/full_player_page.dart';
import '../../features/player/presentation/pages/player_queue_page.dart';
import '../../features/player/presentation/pages/recently_played_page.dart';
import '../../features/player/presentation/pages/listening_history_page.dart';

import '../../features/engagement/presentation/pages/comments_sheet.dart';
import '../../features/engagement/presentation/pages/likers_list_page.dart';
import '../../features/engagement/presentation/pages/reposters_list_page.dart';

import '../../features/playlist/presentation/pages/playlist_details_page.dart';
import '../../features/playlist/presentation/pages/create_playlist_page.dart';
import '../../features/playlist/presentation/pages/edit_playlist_page.dart';
import '../../features/playlist/presentation/pages/playlist_privacy_page.dart';
import '../../features/playlist/presentation/pages/share_playlist_page.dart';

import '../../features/messaging/presentation/pages/chat_inbox_page.dart';
import '../../features/messaging/presentation/pages/chat_room_page.dart';

import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/push_notification_settings_page.dart';

import '../../features/premium/presentation/pages/premium_paywall_page.dart';
import '../../features/premium/presentation/pages/pricing_tiers_page.dart';
import '../../features/premium/presentation/pages/subscription_status_page.dart';
import '../../features/premium/presentation/pages/offline_download_page.dart';

import '../../features/settings/presentation/pages/settings_main_page.dart';
import '../../features/settings/presentation/pages/account_settings_page.dart';
import '../../features/settings/presentation/pages/basic_settings_page.dart';
import '../../features/settings/presentation/pages/social_settings_page.dart';
import '../../features/settings/presentation/pages/notifications_settings_page.dart';
import '../../features/settings/presentation/pages/privacy_settings_page.dart';
import '../../features/settings/presentation/pages/communications_settings_page.dart';
import '../../features/settings/presentation/pages/advertising_settings_page.dart';
import '../../features/settings/presentation/pages/import_music_page.dart';
import '../../features/settings/presentation/pages/inbox_settings_page.dart';
import '../../features/settings/presentation/pages/legal_page.dart';
import '../../features/settings/presentation/pages/add_widget_page.dart';
import '../../features/settings/presentation/pages/analytics_page.dart';
import '../../features/settings/presentation/pages/sign_out_page.dart';

import '../widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // ── AUTH (outside shell) ──────────────────────────────────────────
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/start', builder: (_, __) => const StartPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
<<<<<<< Awad
    GoRoute(path: '/login', builder: (_, __) =>  LoginPage()),
    GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage()),
=======
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
>>>>>>> main
    GoRoute(path: '/oauth-login', builder: (_, __) => const OAuthLoginPage()),
    GoRoute(path: '/email-verification', builder: (_, __) => const EmailVerificationPage()),

    // ── MAIN SHELL (persistent bottom nav) ───────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // ── Branch 0: HOME ──────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomePage(),
              routes: [
                GoRoute(path: 'discover', builder: (_, __) => const DiscoverPage()),
                GoRoute(path: 'following-feed', builder: (_, __) => const FollowingFeedPage()),
                GoRoute(path: 'trending', builder: (_, __) => const TrendingChartsPage()),
                GoRoute(path: 'cast', builder: (_, __) => const CastPage()),
                GoRoute(path: 'genre/electronic', builder: (_, __) => const ElectronicGenrePage()),
                GoRoute(path: 'genre/hiphop', builder: (_, __) => const HiphopGenrePage()),
                GoRoute(path: 'genre/pop', builder: (_, __) => const PopGenrePage()),
              ],
            ),
          ],
        ),

        // ── Branch 1: SEARCH ────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (_, __) => const SearchPage(),
              routes: [
                GoRoute(path: 'tracks', builder: (_, __) => const SearchResultsTracksPage()),
                GoRoute(path: 'users', builder: (_, __) => const SearchResultsUsersPage()),
                GoRoute(path: 'playlists', builder: (_, __) => const SearchResultsPlaylistsPage()),
              ],
            ),
          ],
        ),

        // ── Branch 2: UPLOAD ────────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/upload',
              builder: (_, __) => const UploadPage(),
              routes: [
                GoRoute(path: 'metadata', builder: (_, __) => const MetadataInputPage()),
                GoRoute(path: 'waveform', builder: (_, __) => const WaveformPreviewPage()),
                GoRoute(path: 'progress', builder: (_, __) => const UploadProgressPage()),
              ],
            ),
          ],
        ),

        // ── Branch 3: LIBRARY ───────────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (_, __) => const LibraryPage(),
              routes: [
                GoRoute(path: 'albums', builder: (_, __) => const LibraryAlbumsPage()),
                GoRoute(path: 'stations', builder: (_, __) => const LibraryStationsPage()),
                GoRoute(path: 'uploads', builder: (_, __) => const LibraryUploadsPage()),
                GoRoute(path: 'playlists', builder: (_, __) => const LibraryPlaylistsPage()),
                GoRoute(path: 'likes', builder: (_, __) => const LibraryLikesPage()),
                GoRoute(path: 'insights', builder: (_, __) => const YourInsightsPage()),
                GoRoute(path: 'following', builder: (_, __) => const LibraryFollowingPage()),
              ],
            ),
          ],
        ),

        // ── Branch 4: PROFILE / YOU ─────────────────────────────────
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfilePage(),
              routes: [
                GoRoute(path: 'edit', builder: (_, __) => const EditProfilePage()),
                GoRoute(path: 'tracks', builder: (_, __) => const ProfileTracksPage()),
                GoRoute(path: 'reposts', builder: (_, __) => const ProfileRepostsPage()),
                GoRoute(path: 'insights', builder: (_, __) => const ProfileInsightsPage()),
                GoRoute(path: 'avatar', builder: (_, __) => const AvatarUploadPage()),
                GoRoute(path: 'avatar-view', builder: (_, __) => const AvatarViewerPage()),
                GoRoute(path: 'cover', builder: (_, __) => const CoverPhotoUploadPage()),
                GoRoute(path: 'followers', builder: (_, __) => const FollowersListPage()),
                GoRoute(path: 'following', builder: (_, __) => const FollowingListPage()),
                GoRoute(path: 'suggested', builder: (_, __) => const SuggestedUsersPage()),
                
              ],
            ),
          ],
        ),
      ],
    ),

    // ── PLAYER (global, accessible from anywhere) ─────────────────────
    GoRoute(
      path: '/player',
      builder: (_, __) => const FullPlayerPage(),
      routes: [
        GoRoute(path: 'queue', builder: (_, __) => const PlayerQueuePage()),
        GoRoute(path: 'recent', builder: (_, __) => const RecentlyPlayedPage()),
        GoRoute(path: 'history', builder: (_, __) => const ListeningHistoryPage()),
      ],
    ),

    // ── ENGAGEMENT ────────────────────────────────────────────────────
    GoRoute(path: '/comments', builder: (_, __) => const CommentsSheet()),
    GoRoute(path: '/likers', builder: (_, __) => const LikersListPage()),
    GoRoute(path: '/reposters', builder: (_, __) => const RepostersListPage()),

    // ── PLAYLISTS ─────────────────────────────────────────────────────
    GoRoute(
      path: '/playlist',
      builder: (_, __) => const PlaylistDetailsPage(),
      routes: [
        GoRoute(path: 'create', builder: (_, __) => const CreatePlaylistPage()),
        GoRoute(path: 'edit', builder: (_, __) => const EditPlaylistPage()),
        GoRoute(path: 'privacy', builder: (_, __) => const PlaylistPrivacyPage()),
        GoRoute(path: 'share', builder: (_, __) => const SharePlaylistPage()),
      ],
    ),

    // ── MESSAGING ─────────────────────────────────────────────────────
    GoRoute(
      path: '/messages',
      builder: (_, __) => const ChatInboxPage(),
      routes: [
        GoRoute(path: 'chat', builder: (_, __) => const ChatRoomPage()),
      ],
    ),

    // ── NOTIFICATIONS ─────────────────────────────────────────────────
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsPage(),
      routes: [
        GoRoute(path: 'settings', builder: (_, __) => const PushNotificationSettingsPage()),
      ],
    ),

    // ── PREMIUM ───────────────────────────────────────────────────────
    GoRoute(
      path: '/premium',
      builder: (_, __) => const PremiumPaywallPage(),
      routes: [
        GoRoute(path: 'pricing', builder: (_, __) => const PricingTiersPage()),
        GoRoute(path: 'status', builder: (_, __) => const SubscriptionStatusPage()),
        GoRoute(path: 'offline', builder: (_, __) => const OfflineDownloadPage()),
      ],
    ),

    // ── SETTINGS ──────────────────────────────────────────────────────
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsMainPage(),
      routes: [
        GoRoute(path: 'account', builder: (_, __) => const AccountSettingsPage()),
        GoRoute(path: 'basic', builder: (_, __) => const BasicSettingsPage()),
        GoRoute(path: 'social', builder: (_, __) => const SocialSettingsPage()),
        GoRoute(path: 'notifications', builder: (_, __) => const NotificationsSettingsPage()),
        GoRoute(path: 'privacy', builder: (_, __) => const PrivacySettingsPage()),
        GoRoute(path: 'communications', builder: (_, __) => const CommunicationsSettingsPage()),
        GoRoute(path: 'advertising', builder: (_, __) => const AdvertisingSettingsPage()),
        GoRoute(path: 'import-music', builder: (_, __) => const ImportMusicPage()),
        GoRoute(path: 'inbox', builder: (_, __) => const InboxSettingsPage()),
        GoRoute(path: 'legal', builder: (_, __) => const LegalPage()),
        GoRoute(path: 'add-widget', builder: (_, __) => const AddWidgetPage()),
        GoRoute(path: 'analytics', builder: (_, __) => const AnalyticsPage()),
        GoRoute(path: 'sign-out', builder: (_, __) => const SignOutPage()),
      ],
    ),
  ],
);
