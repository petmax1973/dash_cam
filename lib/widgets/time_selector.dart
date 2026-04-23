import 'package:flutter/material.dart';

/// Circular time selector widget for choosing recording duration in minutes.
class TimeSelector extends StatelessWidget {
  final int minutes;
  final int minMinutes;
  final int maxMinutes;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const TimeSelector({
    super.key,
    required this.minutes,
    this.minMinutes = 1,
    this.maxMinutes = 30,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          'DURATA REGISTRAZIONE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),

        // Minutes display with +/- buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Decrease button
            _buildStepButton(
              icon: Icons.remove,
              onPressed: enabled && minutes > minMinutes
                  ? () => onChanged(minutes - 1)
                  : null,
            ),
            const SizedBox(width: 16),

            // Minutes value
            Column(
              children: [
                Text(
                  '$minutes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  minutes == 1 ? 'MINUTO' : 'MINUTI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Increase button
            _buildStepButton(
              icon: Icons.add,
              onPressed: enabled && minutes < maxMinutes
                  ? () => onChanged(minutes + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Slider
        SizedBox(
        width: 280,
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFE53935),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: const Color(0xFFE53935),
            overlayColor: const Color(0xFFE53935).withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: minutes.toDouble(),
            min: minMinutes.toDouble(),
            max: maxMinutes.toDouble(),
            divisions: maxMinutes - minMinutes,
            onChanged: enabled
                ? (v) => onChanged(v.round())
                : null,
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            size: 20,
          ),
        ),
      ),
    );
  }
}
