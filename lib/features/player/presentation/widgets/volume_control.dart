import 'package:flutter/material.dart';

class VolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, color: Colors.white70, size: 20),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFF5500),
                inactiveTrackColor: const Color(0xFFFF5500).withOpacity(0.3),
                thumbColor: const Color(0xFFFF5500),
                overlayColor: const Color(0xFFFF5500).withOpacity(0.2),
                trackHeight: 3.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14.0),
              ),
              child: Slider(
                key: const ValueKey('player_volume_slider'),
                value: volume.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: onChanged,
                semanticFormatterCallback: (value) =>
                    'Volume ${(value * 100).round()}%',
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}
