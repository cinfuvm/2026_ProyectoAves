import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Entrada escalonada aplicada a los elementos de una lista.
///
/// Al establecer [activa] en `false` después de la primera aparición, se
/// evita repetir la animación al cambiar de pestaña o aplicar filtros.
/// Si [activa] es `false` o el sistema reduce las animaciones, el elemento
/// aparece directamente en su estado final.
class AparicionDiferida extends StatelessWidget {
  const AparicionDiferida({
    super.key,
    required this.indice,
    required this.activa,
    required this.child,
    this.retrasoPorIndice = 0.08,
    this.retrasoMaximo = 0.4,
    this.duracionMs = 600,
  });

  final int indice;
  final bool activa;
  final Widget child;
  final double retrasoPorIndice;
  final double retrasoMaximo;
  final int duracionMs;

  @override
  Widget build(BuildContext context) {
    final retraso = (indice * retrasoPorIndice).clamp(0.0, retrasoMaximo);
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: (activa && !sinAnimaciones)
          ? duracion(context, duracionMs)
          : Duration.zero,
      curve: Curves.linear,
      builder: (contexto, t, _) {
        final avance = activa
            ? Interval(retraso, 1, curve: Curves.easeOutCubic).transform(t)
            : 1.0;
        return Opacity(
          opacity: avance,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - avance)),
            child: child,
          ),
        );
      },
    );
  }
}
