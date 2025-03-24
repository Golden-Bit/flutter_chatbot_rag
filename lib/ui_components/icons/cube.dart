import 'package:flutter/material.dart';

/// Widget che mostra un cubo wireframe disegnato a mano.
/// Puoi usarlo al posto di un Icon(...) in qualunque punto del tuo layout.
/// Esempio di utilizzo:
///
///   WireframeCubeIcon(
///     size: 24.0,
///     color: Colors.blue,
///   )
///
class WireframeCubeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WireframeCubeIcon({
    Key? key,
    this.size = 24.0,
    this.color = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WireframeCubePainter(color),
    );
  }
}

class _WireframeCubePainter extends CustomPainter {
  final Color color;
  _WireframeCubePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Impostiamo un Paint di base per tracciare linee blu con spessore 2
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Lavoriamo in un "sistema di riferimento" 24×24, poi facciamo scaling in base a size.
    final double ratio = size.width / 24.0;

    // Definiamo i punti della faccia "vicina" (near face)
    // E la faccia "lontana" (far face) per dare un effetto di cubo wireframe.
    // Puoi modificare i numeri per cambiare prospettiva o dimensioni.
    final nearTopLeft     = Offset( 4 * ratio,  8 * ratio);
    final nearTopRight    = Offset(16 * ratio,  8 * ratio);
    final nearBottomRight = Offset(16 * ratio, 20 * ratio);
    final nearBottomLeft  = Offset( 4 * ratio, 20 * ratio);

    final farTopLeft      = Offset( 8 * ratio,  4 * ratio);
    final farTopRight     = Offset(20 * ratio,  4 * ratio);
    final farBottomRight  = Offset(20 * ratio, 16 * ratio);
    final farBottomLeft   = Offset( 8 * ratio, 16 * ratio);

    // Disegniamo i quattro lati della faccia vicina
    canvas.drawLine(nearTopLeft,     nearTopRight,     paint);
    canvas.drawLine(nearTopRight,    nearBottomRight,  paint);
    canvas.drawLine(nearBottomRight, nearBottomLeft,   paint);
    canvas.drawLine(nearBottomLeft,  nearTopLeft,      paint);

    // Disegniamo i quattro lati della faccia lontana
    canvas.drawLine(farTopLeft,      farTopRight,      paint);
    canvas.drawLine(farTopRight,     farBottomRight,   paint);
    canvas.drawLine(farBottomRight,  farBottomLeft,    paint);
    canvas.drawLine(farBottomLeft,   farTopLeft,       paint);

    // Collegamenti fra la faccia vicina e la faccia lontana
    canvas.drawLine(nearTopLeft,     farTopLeft,       paint);
    canvas.drawLine(nearTopRight,    farTopRight,      paint);
    canvas.drawLine(nearBottomRight, farBottomRight,   paint);
    canvas.drawLine(nearBottomLeft,  farBottomLeft,    paint);
  }

  @override
  bool shouldRepaint(_WireframeCubePainter oldDelegate) {
    // Ridisegna solo se cambia il colore
    return color != oldDelegate.color;
  }
}
