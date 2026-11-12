import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/design/colors.dart';

class PatrolProgressWidget extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final double size;

  const PatrolProgressWidget({
    super.key,
    required this.completedCount,
    required this.totalCount,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: ProgressPainter(
              progress: 1.0,
              color: Colors.grey[300]!,
              strokeWidth: 8,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: Size(size, size),
            painter: ProgressPainter(
              progress: progress,
              color: primaryColor,
              strokeWidth: 8,
            ),
          ),
          // Progress text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$completedCount/$totalCount',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalCount > 0 && completedCount == totalCount
                    ? 'Selesai'
                    : 'Progress',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Progress angle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}