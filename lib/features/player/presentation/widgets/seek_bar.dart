import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';

/// A live seek bar that reads position/duration directly from [playerProvider]
/// and calls [PlayerNotifier.seekTo] when the user drags.
///
/// Drag-handling strategy: while the thumb is being dragged, a local
/// [_draggingPosition] shadows the provider value so the stream of incoming
/// position updates cannot fight the user's gesture. The shadow is cleared —
/// and [seekTo] is called — only when the drag ends ([onChangeEnd]).
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key});

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  /// Non-null only while the thumb is being dragged.
  Duration? _draggingPosition;

  static String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    // During a drag use the local shadow; otherwise follow the provider live.
    final position = _draggingPosition ?? playerState.position;
    final duration = playerState.duration;

    final totalMs = duration.inMilliseconds.toDouble();
    // Clamp to avoid NaN / out-of-range when duration is not yet known.
    final sliderValue = totalMs > 0
        ? (position.inMilliseconds.toDouble() / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF5500),
              inactiveTrackColor:
                  const Color(0xFFFF5500).withOpacity(0.30),
              thumbColor: const Color(0xFFFF5500),
              overlayColor: const Color(0xFFFF5500).withOpacity(0.20),
              trackHeight: 3.0,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              value: sliderValue,
              min: 0.0,
              max: 1.0,
              // Snapshot the current position the moment the user touches the
              // thumb so we start the drag from the correct spot.
              onChangeStart: (_) {
                setState(() => _draggingPosition = playerState.position);
              },
              // Update the local shadow on every drag frame — this is what
              // the user *sees* moving while they scrub.
              onChanged: (value) {
                setState(() {
                  _draggingPosition = Duration(
                    milliseconds: (value * totalMs).round(),
                  );
                });
              },
              // Commit to the provider and release the shadow only when
              // the user lifts their finger.
              onChangeEnd: (value) {
                final committed = Duration(
                  milliseconds: (value * totalMs).round(),
                );
                notifier.seekTo(committed);
                setState(() => _draggingPosition = null);
              },
              semanticFormatterCallback: (value) =>
                  _format(Duration(milliseconds: (value * totalMs).round())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(position),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 12.0,
                      ),
                ),
                Text(
                  _format(duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 12.0,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
