import 'package:flutter/material.dart';

/// Widget with the large record/stop button and recording indicator.
class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final String elapsedTime;
  final VoidCallback onStartStop;
  final bool enabled;

  const RecordingControls({
    super.key,
    required this.isRecording,
    required this.elapsedTime,
    required this.onStartStop,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recording indicator
        if (isRecording) ...[
          _buildRecordingIndicator(),
          const SizedBox(height: 16),
        ],

        // Main button
        GestureDetector(
          onTap: enabled ? onStartStop : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isRecording ? 64 : 80,
            height: isRecording ? 64 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? Colors.transparent
                  : const Color(0xFFE53935),
              border: Border.all(
                color: isRecording
                    ? const Color(0xFFE53935)
                    : Colors.white.withValues(alpha: 0.3),
                width: isRecording ? 3 : 4,
              ),
              boxShadow: isRecording
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isRecording
                    ? Container(
                        key: const ValueKey('stop'),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : const Icon(
                        key: ValueKey('record'),
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Label
        Text(
          isRecording ? 'STOP' : 'AVVIA',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsating red dot
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE53935).withValues(alpha: value),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFFE53935).withValues(alpha: value * 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
          onEnd: () {},
        ),
        const SizedBox(width: 10),

        // Elapsed time
        Text(
          'REC $elapsedTime',
          style: const TextStyle(
            color: Color(0xFFE53935),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
