import 'package:flutter/material.dart';

/// Navigation marks are painted as paths so release font subsetting cannot
/// silently remove a destination icon on Windows or Android.
enum AppNavigationSymbol { start, tasks, notes, costs }

class AppNavigationIcon extends StatelessWidget {
  const AppNavigationIcon({
    super.key,
    required this.symbol,
    required this.color,
    this.selected = false,
    this.size = 24,
  });

  final AppNavigationSymbol symbol;
  final Color color;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _NavigationPainter(symbol, color, selected)),
  );
}

class _NavigationPainter extends CustomPainter {
  const _NavigationPainter(this.symbol, this.color, this.selected);

  final AppNavigationSymbol symbol;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.25 : 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final tint = Paint()..color = color.withValues(alpha: selected ? .18 : 0);

    switch (symbol) {
      case AppNavigationSymbol.start:
        final roof = Path()
          ..moveTo(3.5, 10.5)
          ..lineTo(12, 3.5)
          ..lineTo(20.5, 10.5);
        canvas.drawPath(roof, stroke);
        final house = Path()
          ..moveTo(5.5, 9.5)
          ..lineTo(5.5, 20)
          ..lineTo(18.5, 20)
          ..lineTo(18.5, 9.5);
        canvas.drawPath(house, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 14, 4, 6),
            const Radius.circular(1),
          ),
          selected ? stroke : tint,
        );
      case AppNavigationSymbol.tasks:
        canvas.drawCircle(const Offset(12, 12), 9, tint);
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 12)
            ..lineTo(10.5, 15)
            ..lineTo(16.8, 8.7),
          stroke,
        );
      case AppNavigationSymbol.notes:
        final page = RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 2.5, 14, 19),
          const Radius.circular(2),
        );
        canvas.drawRRect(page, tint);
        canvas.drawRRect(page, stroke);
        for (final y in <double>[8.5, 12, 15.5]) {
          canvas.drawLine(
            Offset(8.5, y),
            Offset(y == 15.5 ? 14.0 : 16.0, y),
            stroke,
          );
        }
      case AppNavigationSymbol.costs:
        final wallet = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.2, 7, 17.6, 13.5),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(wallet, tint);
        canvas.drawRRect(wallet, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 7)
            ..lineTo(6.5, 4.5)
            ..lineTo(17.5, 4.5),
          stroke,
        );
        canvas.drawCircle(const Offset(16.4, 13.7), 1.5, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavigationPainter oldDelegate) =>
      symbol != oldDelegate.symbol ||
      color != oldDelegate.color ||
      selected != oldDelegate.selected;
}
