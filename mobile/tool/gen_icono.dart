// Genera assets/icono_app.png (1024x1024): cámara + pajarito.
// Uso: dart run tool/gen_icono.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

void main() {
  const s = 1024;
  final img = Image(width: s, height: s);

  // Fondo: gradiente vertical morado #6A1B9A -> #4A148C
  final top = ColorRgb8(0x6A, 0x1B, 0x9A);
  final bottom = ColorRgb8(0x4A, 0x14, 0x8C);
  for (var y = 0; y < s; y++) {
    final t = y / (s - 1);
    final r = (top.r + (bottom.r - top.r) * t).round();
    final g = (top.g + (bottom.g - top.g) * t).round();
    final b = (top.b + (bottom.b - top.b) * t).round();
    final c = ColorRgb8(r, g, b);
    for (var x = 0; x < s; x++) {
      img.setPixel(x, y, c);
    }
  }

  final amarillo = ColorRgb8(0xFD, 0xD8, 0x35);
  final moradoOscuro = ColorRgb8(0x3E, 0x0F, 0x6E);

  // --- Cuerpo de la cámara (rectángulo redondeado) ---
  final cx = s ~/ 2;
  final cy = s ~/ 2 + 40;
  final cw = 520;
  final ch = 360;
  final radio = 60;
  _rectRedondeado(img, cx - cw ~/ 2, cy - ch ~/ 2, cw, ch, radio, amarillo);

  // --- Bump del visor (pequeño rectángulo arriba, centrado-izquierda) ---
  final bx = cx - cw ~/ 2 + 90;
  final by = cy - ch ~/ 2 - 50;
  _rectRedondeado(img, bx, by, 120, 70, 24, amarillo);

  // --- Lente: círculos concéntricos ---
  final lensR = 130;
  _circulo(img, cx, cy, lensR, amarillo);
  _circulo(img, cx, cy, lensR - 28, moradoOscuro);
  _circulo(img, cx, cy, lensR - 60, amarillo);
  _circulo(img, cx, cy, lensR - 90, moradoOscuro);

  // --- Destello pequeño (esquina superior derecha de la cámara) ---
  final fx = cx + cw ~/ 2 - 70;
  final fy = cy - ch ~/ 2 + 40;
  _circulo(img, fx, fy, 22, moradoOscuro);

  // --- Pajarito silhouette (sobre el lente, ligeramente a la derecha) ---
  _pajarito(img, cx + 40, cy - 190, scale: 1.15, color: amarillo);

  // Guardar
  final dir = Directory('assets');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('assets/icono_app.png').writeAsBytesSync(encodePng(img));
  stdout.writeln('assets/icono_app.png generado (${img.width}x${img.height})');
}

void _rectRedondeado(
  Image img,
  int x,
  int y,
  int w,
  int h,
  int r,
  Color c,
) {
  for (var py = y; py < y + h; py++) {
    for (var px = x; px < x + w; px++) {
      if (_dentroRedondeado(px - x, py - y, w, h, r)) {
        img.setPixel(px, py, c);
      }
    }
  }
}

bool _dentroRedondeado(int lx, int ly, int w, int h, int r) {
  if (lx >= r && lx < w - r) return true;
  if (ly >= r && ly < h - r) return true;
  // Esquinas
  final corners = [
    (r, r),
    (w - r - 1, r),
    (r, h - r - 1),
    (w - r - 1, h - r - 1),
  ];
  for (final (ccx, ccy) in corners) {
    final dx = lx - ccx;
    final dy = ly - ccy;
    if (dx * dx + dy * dy <= r * r) {
      // Solo dentro del cuadrante de la esquina
      final inCornerX = lx < r || lx >= w - r;
      final inCornerY = ly < r || ly >= h - r;
      if (inCornerX && inCornerY) return true;
    }
  }
  return false;
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

/// Dibuja un pajarito silhouette simple (cuerpo elipse + cabeza + pico + cola + ala).
void _pajarito(
  Image img,
  int cx,
  int cy, {
  double scale = 1.0,
  Color? color,
}) {
  final c = color ?? ColorRgb8(0xFD, 0xD8, 0x35);
  final s = scale;

  // Cuerpo: elipse
  _elipse(img, cx, cy, (55 * s).round(), (35 * s).round(), c);

  // Cabeza: círculo
  final hx = cx + (48 * s).round();
  final hy = cy - (28 * s).round();
  _circulo(img, hx, hy, (28 * s).round(), c);

  // Pico: triángulo hacia la derecha
  _triangulo(
    img,
    hx + (24 * s).round(),
    hy - (4 * s).round(),
    hx + (50 * s).round(),
    hy + (2 * s).round(),
    hx + (24 * s).round(),
    hy + (10 * s).round(),
    c,
  );

  // Cola: triángulo hacia atrás-izquierda
  final tx = cx - (50 * s).round();
  final ty = cy - (5 * s).round();
  _triangulo(
    img,
    tx,
    ty - (12 * s).round(),
    tx - (45 * s).round(),
    ty + (5 * s).round(),
    tx,
    ty + (18 * s).round(),
    c,
  );

  // Ala: elipse rotada (aproximada con elipse)
  _elipse(img, cx - (5 * s).round(), cy + (5 * s).round(), (32 * s).round(),
      (16 * s).round(), c);

  // Ojo: punto morado
  _circulo(img, hx + (10 * s).round(), hy - (6 * s).round(),
      (5 * s).round().clamp(1, 999), ColorRgb8(0x3E, 0x0F, 0x6E));
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
