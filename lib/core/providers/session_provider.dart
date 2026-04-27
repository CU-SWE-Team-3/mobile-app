import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the currently-authenticated userId.
/// Set to a non-empty string on login, empty string on logout.
/// Widgets that depend on session state (e.g. ProfilePage) listen to this
/// so they can reload data when the user signs in or switches accounts.
final sessionUserIdProvider = StateProvider<String>((ref) => '');
