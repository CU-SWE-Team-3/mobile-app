import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../premium/presentation/providers/subscription_provider.dart';

class MockAudioAdState {
  final bool isShowing;
  final int secondsRemaining;
  final bool canSkip;

  const MockAudioAdState({
    this.isShowing = false,
    this.secondsRemaining = 0,
    this.canSkip = false,
  });

  MockAudioAdState copyWith({
    bool? isShowing,
    int? secondsRemaining,
    bool? canSkip,
  }) {
    return MockAudioAdState(
      isShowing: isShowing ?? this.isShowing,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canSkip: canSkip ?? this.canSkip,
    );
  }
}

class MockAudioAdNotifier extends StateNotifier<MockAudioAdState> {
  final Ref _ref;
  final Set<String> _preRollShownTrackIds = <String>{};
  Completer<void>? _activeAdCompleter;
  Timer? _countdownTimer;

  MockAudioAdNotifier(this._ref) : super(const MockAudioAdState());

  Future<void> maybeShowPreRollAd(String trackId) async {
    final subscription = _ref.read(subscriptionProvider);
    final planType = subscription.planType;

    if (_isAdFreePlan(planType)) {
      debugPrint(
        planType == 'Go+'
            ? '[Ads] Go+ — ad-free playback'
            : '[Ads] Artist Pro — ad-free playback',
      );
      return;
    }

    if (subscription.isPremium) {
      debugPrint('[Ads] premium unknown plan — skipping mock ads');
      return;
    }

    if (_preRollShownTrackIds.contains(trackId)) return;

    debugPrint('[Ads] Free user — showing pre-roll ad');
    await _showAd();
    _preRollShownTrackIds.add(trackId);
    debugPrint('[Ads] Ad completed — starting playback');
  }

  void completeAd() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = const MockAudioAdState();
    final completer = _activeAdCompleter;
    _activeAdCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _showAd() {
    if (_activeAdCompleter != null) {
      return _activeAdCompleter!.future;
    }

    final completer = Completer<void>();
    _activeAdCompleter = completer;
    state = const MockAudioAdState(
      isShowing: true,
      secondsRemaining: 5,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.secondsRemaining - 1;
      if (next <= 0) {
        state = state.copyWith(secondsRemaining: 0, canSkip: true);
        timer.cancel();
        _countdownTimer = Timer(const Duration(milliseconds: 700), completeAd);
        return;
      }
      state = state.copyWith(secondsRemaining: next);
    });

    return completer.future;
  }

  bool _isAdFreePlan(String? planType) {
    return planType == 'Pro' || planType == 'Artist Pro' || planType == 'Go+';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final mockAudioAdProvider =
    StateNotifierProvider<MockAudioAdNotifier, MockAudioAdState>((ref) {
  return MockAudioAdNotifier(ref);
});
