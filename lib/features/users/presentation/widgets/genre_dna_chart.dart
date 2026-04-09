import 'dart:math';
import 'package:flutter/material.dart';

/// A premium radar chart widget that visually represents
/// the user's movie genre DNA.
class GenreDnaChart extends StatefulWidget {
  /// Genre data as a map of genre name → movie count.
  final Map<String, int> genreData;

  const GenreDnaChart({super.key, required this.genreData});

  @override
  State<GenreDnaChart> createState() => _GenreDnaChartState();
}

class _GenreDnaChartState extends State<GenreDnaChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.genreData.isEmpty) {
      return _buildEmptyState();
    }

    // Take top 6 genres for the radar chart
    final sorted = widget.genreData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sorted.take(6).toList();
    final maxValue = topGenres.first.value.toDouble();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 260),
          painter: _RadarChartPainter(
            genres: topGenres,
            maxValue: maxValue,
            animationValue: _animation.value,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint_rounded,
              size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            'Film DNA\'n oluşuyor...\nDaha fazla film keşfet!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> genres;
  final double maxValue;
  final double animationValue;

  // Genre name → Turkish label mapping
  static const _genreLabels = {
    'Action': 'Aksiyon',
    'Comedy': 'Komedi',
    'Drama': 'Drama',
    'Horror': 'Korku',
    'Science Fiction': 'Bilim Kurgu',
    'Sci-Fi': 'Bilim Kurgu',
    'Romance': 'Romantik',
    'Animation': 'Animasyon',
    'Documentary': 'Belgesel',
    'Thriller': 'Gerilim',
    'Fantasy': 'Fantastik',
    'Crime': 'Suç',
    'Mystery': 'Gizem',
    'Adventure': 'Macera',
    'Family': 'Aile',
    'War': 'Savaş',
    'History': 'Tarih',
    'Music': 'Müzik',
    'Western': 'Western',
  };

  _RadarChartPainter({
    required this.genres,
    required this.maxValue,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 40;
    final sides = genres.length;
    final angleStep = (2 * pi) / sides;
    // Rotate so first point is at the top
    const startAngle = -pi / 2;

    // Draw grid rings (3 levels)
    _drawGridRings(canvas, center, radius, sides, angleStep, startAngle);

    // Draw data polygon
    _drawDataPolygon(
        canvas, center, radius, sides, angleStep, startAngle);

    // Draw data points
    _drawDataPoints(
        canvas, center, radius, sides, angleStep, startAngle);

    // Draw labels
    _drawLabels(canvas, center, radius, sides, angleStep, startAngle, size);
  }

  void _drawGridRings(Canvas canvas, Offset center, double radius, int sides,
      double angleStep, double startAngle) {
    for (int ring = 1; ring <= 3; ring++) {
      final ringRadius = radius * (ring / 3);
      final ringPath = Path();

      for (int i = 0; i < sides; i++) {
        final angle = startAngle + angleStep * i;
        final x = center.dx + ringRadius * cos(angle);
        final y = center.dy + ringRadius * sin(angle);
        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();

      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(ringPath, ringPaint);
    }

    // Draw axis lines from center to each vertex
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1.0;
      canvas.drawLine(center, Offset(x, y), linePaint);
    }
  }

  void _drawDataPolygon(Canvas canvas, Offset center, double radius, int sides,
      double angleStep, double startAngle) {
    final dataPath = Path();
    
    for (int i = 0; i < sides; i++) {
      final value = genres[i].value / maxValue;
      final animatedValue = value * animationValue;
      // Minimum 10% radius so the shape is always visible
      final r = radius * max(animatedValue, 0.1);
      final angle = startAngle + angleStep * i;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    // Fill with gradient-like effect
    final fillPaint = Paint()
      ..color = const Color(0xFFE94560).withValues(alpha: 0.15 * animationValue)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = const Color(0xFFE94560).withValues(alpha: 0.7 * animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);
  }

  void _drawDataPoints(Canvas canvas, Offset center, double radius, int sides,
      double angleStep, double startAngle) {
    for (int i = 0; i < sides; i++) {
      final value = genres[i].value / maxValue;
      final animatedValue = value * animationValue;
      final r = radius * max(animatedValue, 0.1);
      final angle = startAngle + angleStep * i;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      // Outer glow
      final glowPaint = Paint()
        ..color =
            const Color(0xFFE94560).withValues(alpha: 0.3 * animationValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), 5, glowPaint);

      // Solid dot
      final dotPaint = Paint()
        ..color = const Color(0xFFE94560).withValues(alpha: animationValue)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);

      // White center
      final centerDotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * animationValue)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 1.5, centerDotPaint);
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, int sides,
      double angleStep, double startAngle, Size size) {
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final labelRadius = radius + 24;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final genreName = genres[i].key;
      final label = _genreLabels[genreName] ?? genreName;
      final count = genres[i].value;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label\n',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8 * animationValue),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: '$count',
              style: TextStyle(
                color: const Color(0xFFE94560)
                    .withValues(alpha: 0.9 * animationValue),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // Offset the text so it's centered on the label point
      final textOffset = Offset(
        x - textPainter.width / 2,
        y - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.genres != genres;
  }
}
