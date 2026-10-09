import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Abre el visor a pantalla completa con vuelo Hero desde la tarjeta.
///
/// [construirImagen] debe devolver una imagen con el mismo [etiquetaHero]
/// que la tarjeta de origen; el Hero usa el destino como shuttle, así que
/// conviene usar `BoxFit.contain` aquí aunque la tarjeta use `cover`.
Future<void> mostrarVisorFoto(
  BuildContext contexto, {
  required String etiquetaHero,
  required String titulo,
  required String? subtitulo,
  required Widget Function(BuildContext) construirImagen,
}) {
  return Navigator.of(contexto).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: duracion(contexto, 480),
      reverseTransitionDuration: duracion(contexto, 360),
      pageBuilder: (contextoVisor, _, _) => VisorFoto(
        etiquetaHero: etiquetaHero,
        titulo: titulo,
        subtitulo: subtitulo,
        construirImagen: construirImagen,
      ),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: child,
      ),
    ),
  );
}

class VisorFoto extends StatelessWidget {
  const VisorFoto({
    super.key,
    required this.etiquetaHero,
    required this.titulo,
    required this.subtitulo,
    required this.construirImagen,
  });

  final String etiquetaHero;
  final String titulo;
  final String? subtitulo;
  final Widget Function(BuildContext) construirImagen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: etiquetaHero,
                  child: construirImagen(context),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Cerrar',
                        color: Colors.white,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (subtitulo != null && subtitulo!.isNotEmpty)
                              Text(
                                subtitulo!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.fraunces(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
