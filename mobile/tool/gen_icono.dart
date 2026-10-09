// Genera assets/icono_app.png (1024x1024): pajarito flutter_dash morado sobre fondo amarillo.
// Uso: dart run tool/gen_icono.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

void main() {
  const s = 1024;
  final img = Image(width: s, height: s);

  final amarillo = ColorRgb8(0xFD, 0xD8, 0x35);
  final morado = ColorRgb8(0x6A, 0x1B, 0x9A);
  final moradoOscuro = ColorRgb8(0x4A, 0x14, 0x8C);

  // Fondo amarillo completo
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      img.setPixel(x, y, amarillo);
    }
  }

  final cx = s ~/ 2;
  final cy = s ~/ 2;

  // --- Cuerpo del pajarito (elipse grande) ---
  _elipse(img, cx, cy + 40, 220, 180, morado);

  // --- Cabeza (círculo arriba-derecha) ---
  final hx = cx + 120;
  final hy = cy - 140;
  _circulo(img, hx, hy, 130, morado);

  // --- Pico (triángulo hacia la derecha) ---
  _triangulo(
    img,
    hx + 100,
    hy - 20,
    hx + 220,
    hy + 15,
    hx + 100,
    hy + 50,
    morado,
  );

  // --- Ala (elipse sobre el cuerpo) ---
  _elipse(img, cx - 40, cy + 20, 140, 90, moradoOscuro);

  // --- Cola (triángulo largo hacia atrás-izquierda) ---
  _triangulo(
    img,
    cx - 160,
    cy + 20,
    cx - 380,
    cy - 40,
    cx - 160,
    cy + 120,
    morado,
  );
  // Segundo pluma de cola
  _triangulo(
    img,
    cx - 150,
    cy + 60,
    cx - 340,
    cy + 80,
    cx - 140,
    cy + 150,
    morado,
  );

  // --- Patas (dos líneas cortas hacia abajo) ---
  _elipse(img, cx - 40, cy + 210, 18, 50, morado);
  _elipse(img, cx + 40, cy + 210, 18, 50, morado);

  // --- Ojo (círculo amarillo en la cabeza) ---
  _circulo(img, hx + 40, hy - 30, 35, amarillo);
  // Pupila
  _circulo(img, hx + 48, hy - 28, 16, moradoOscuro);

  // --- Cresta (triángulos pequeños arriba de la cabeza) ---
  _triangulo(img, hx - 40, hy - 110, hx - 10, hy - 190, hx + 20, hy - 100, morado);
  _triangulo(img, hx + 10, hy - 120, hx + 50, hy - 200, hx + 80, hy - 100, morado);

  // Guardar
  final dir = Directory('assets');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('assets/icono_app.png').writeAsBytesSync(encodePng(img));
  stdout.writeln('assets/icono_app.png generado (${img.width}x${img.height})');
}

void _circulo(Image img, int cx, int cy, int r, Color c) {
  final r2 = r * r;
  for (var y = cy - r; y <= cy + r; y++) {
    for (var x = cx - r; x <= cx + r; x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        img.setPixel(x, y, c);
      }
    }
  }
}

void _elipse(Image img, int cx, int cy, int rx, int ry, Color c) {
  for (var y = cy - ry; y <= cy + ry; y++) {
    for (var x = cx - rx; x <= cx + rx; x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) {
        img.setPixel(x, y, c);
      }
    }
  }
}

void _triangulo(
  Image img,
  int x1,
  int y1,
  int x2,
  int y2,
  int x3,
  int y3,
  Color c,
) {
  final minX = math.min(x1, math.min(x2, x3));
  final maxX = math.max(x1, math.max(x2, x3));
  final minY = math.min(y1, math.min(y2, y3));
  final maxY = math.max(y1, math.max(y2, y3));
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      if (_enTriangulo(x, y, x1, y1, x2, y2, x3, y3)) {
        img.setPixel(x, y, c);
      }
    }
  }
}

bool _enTriangulo(
  int px,
  int py,
  int x1,
  int y1,
  int x2,
  int y2,
  int x3,
  int y3,
) {
  final d1 = _sign(px, py, x1, y1, x2, y2);
  final d2 = _sign(px, py, x2, y2, x3, y3);
  final d3 = _sign(px, py, x3, y3, x1, y1);
  final neg = d1 < 0 || d2 < 0 || d3 < 0;
  final pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}

double _sign(int px, int py, int x1, int y1, int x2, int y2) {
  return ((px - x2) * (y1 - y2) - (x1 - x2) * (py - y2)).toDouble();
}
