import 'package:flutter/material.dart';

class SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;

  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
  });

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final current = position.inMilliseconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
    final sliderValue = total > 0 ? current / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF5500),
              inactiveTrackColor: const Color(0xFFFF5500).withOpacity(0.3),
              thumbColor: const Color(0xFFFF5500),
              overlayColor: const Color(0xFFFF5500).withOpacity(0.2),
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              key: const ValueKey('player_seek_slider'),
              value: sliderValue,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * total).round(),
                );
                onChanged(newPosition);
              },
              semanticFormatterCallback: (value) =>
                  _format(Duration(milliseconds: (value * total).round())),
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
