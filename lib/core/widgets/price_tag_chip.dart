import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:flutter/material.dart';

class PriceTagChip extends StatelessWidget {

  const PriceTagChip({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.accent,
    this.textColor = Colors.white,
    this.cutSize = 10.0,
  });
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double cutSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PriceTagPainter(
        color: backgroundColor,
        cutSize: cutSize,
      ),
      child: Container(
        padding: EdgeInsets.only(
          left: cutSize + 10,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class _PriceTagPainter extends CustomPainter {

  _PriceTagPainter({required this.color, required this.cutSize});
  final Color color;
  final double cutSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Create the outer tag shape
    final path = Path()
      ..moveTo(cutSize, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cutSize)
      ..close();

    // Create the hole shape (punched circle)
    // Center it relative to the cut
    final holeCenter = Offset(cutSize / 2 + 2, cutSize / 2 + 2);
    final holePath = Path()
      ..addOval(Rect.fromCircle(center: holeCenter, radius: 2.0));

    // Subtract hole from tag shape to make a real see-through hole
    final finalPath = Path.combine(PathOperation.difference, path, holePath);

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _PriceTagPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.cutSize != cutSize;
  }
}
