import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Badge de marca de la app: cuadro redondeado amarillo con el isotipo de
/// Coron (el loro con corona). Reemplaza al búho `flutter_dash` que se usaba
/// como marcador de posición antes de que existiera el logo.
class LogoMarca extends StatelessWidget {
  const LogoMarca({super.key, this.tamano = 38});

  /// Lado del cuadro amarillo; el isotipo se dibuja con un pequeño respiro
  /// para que la corona no toque el borde.
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final icono = tamano * 0.66;
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: PaletaAves.amarillo,
        borderRadius: BorderRadius.circular(tamano * 0.37),
      ),
      padding: EdgeInsets.all(tamano * 0.09),
      child: Image.asset(
        'assets/logo_isotipo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(
          width: icono,
          height: icono,
          child: const Icon(
            Icons.flutter_dash_rounded,
            color: PaletaAves.morado,
          ),
        ),
      ),
    );
  }
}
