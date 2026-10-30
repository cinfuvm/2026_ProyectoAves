import 'dart:io';

import 'package:flutter/material.dart';

import '../models/avistamiento_propio.dart';
import '../models/foto_guardada.dart';
import '../models/foto_publica.dart';
import '../theme/app_theme.dart';

/// Sección de inicio con el saludo, el resumen de la bitácora, los
/// avistamientos recientes y el feed de la comunidad.
class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.nombreUsuario,
    required this.avistamientos,
    required this.fotosGuardadas,
    required this.fotosComunidad,
    required this.cargandoComunidad,
    required this.onAgregarFoto,
    required this.onVerColeccion,
    required this.onVerExplorar,
    required this.onVerCatalogo,
  });

  final String? nombreUsuario;
  final List<AvistamientoPropio> avistamientos;
  final List<FotoGuardada> fotosGuardadas;
  final List<FotoPublica> fotosComunidad;
  final bool cargandoComunidad;
  final VoidCallback onAgregarFoto;
  final VoidCallback onVerColeccion;
  final VoidCallback onVerExplorar;
  final VoidCallback onVerCatalogo;

  @override
  Widget build(BuildContext context) {
    final avistamientosRecientes = avistamientos.take(5).toList();
    final fotosComunidadRecientes = fotosComunidad.take(8).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        _construirEncabezado(context),
        const SizedBox(height: 14),
        _construirTiraResumen(context),
        const SizedBox(height: 28),
        if (avistamientosRecientes.isEmpty)
          _tarjetaVacia(
            context,
            icono: Icons.camera_alt_outlined,
            titulo: 'Aún no tienes avistamientos',
            mensaje: 'Agrega tu primera foto y guarda dónde la encontraste.',
            accion: 'Agregar foto',
            onAccion: onAgregarFoto,
          )
        else ...[
          _construirEncabezadoSeccion(
            context,
            titulo: 'Tus últimos avistamientos',
            onVerTodo: onVerColeccion,
            etiquetaVerTodo: 'Ver colección',
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avistamientosRecientes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final avistamiento = avistamientosRecientes[index];
                return _TarjetaAvistamientoReciente(
                  avistamiento: avistamiento,
                  fechaFormateada: formatearFecha(avistamiento.fecha),
                  onAbrir: onVerColeccion,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 28),
        if (cargandoComunidad)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: PaletaAves.morado),
            ),
          )
        else if (fotosComunidadRecientes.isEmpty)
          _tarjetaVacia(
            context,
            icono: Icons.explore_outlined,
            titulo: 'La comunidad está tranquila por ahora',
            mensaje:
                'Cuando la gente publique fotos aparecerán aquí. '
                'Mientras tanto, explora las aves de Chile.',
            accion: 'Explorar ahora',
            onAccion: onVerExplorar,
          )
        else ...[
          _construirEncabezadoSeccion(
            context,
            titulo: 'Recién en la comunidad',
            onVerTodo: onVerExplorar,
            etiquetaVerTodo: 'Ver todo',
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotosComunidadRecientes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final foto = fotosComunidadRecientes[index];
                return _TarjetaFotoComunidad(
                  foto: foto,
                  onAbrir: onVerExplorar,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 28),
        _construirEncabezadoSeccion(context, titulo: 'Descubre más'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _tarjetaAccesoRapido(
                context,
                icono: Icons.search_rounded,
                titulo: 'Buscar aves',
                mensaje: 'Catálogo de 216 especies de Chile.',
                onAccion: onVerCatalogo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaAccesoRapido(
                context,
                icono: Icons.explore_rounded,
                titulo: 'Comunidad',
                mensaje: 'Fotos de observadores como tú.',
                onAccion: onVerExplorar,
                destacado: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirEncabezado(BuildContext context) {
    final marca = context.marca;
    final esApaisada =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 600;
    final saludo = nombreUsuario == null || nombreUsuario!.isEmpty
        ? 'Hola, observador'
        : 'Hola, $nombreUsuario!';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esApaisada ? 16 : 22),
      decoration: BoxDecoration(
        gradient: marca.cabeceraGradiente,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  saludo,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: esApaisada ? 24 : 30,
                    height: 1.1,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pequeños encuentros, grandes historias.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 64,
                  height: 5,
                  decoration: BoxDecoration(
                    color: PaletaAves.amarillo,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: esApaisada ? 56 : 84,
            height: esApaisada ? 56 : 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(esApaisada ? 11 : 17),
              child: Image.asset(
                'assets/logo_isotipo_pink.png',
                fit: BoxFit.contain,
                semanticLabel: 'Isotipo de CORON',
                errorBuilder: (_, _, _) => const Icon(
                  Icons.flutter_dash_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTiraResumen(BuildContext context) {
    Widget dato({
      required IconData icono,
      required int valor,
      required String etiqueta,
    }) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              '$valor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: context.marca.barraGradiente,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          dato(
            icono: Icons.camera_alt_rounded,
            valor: avistamientos.length,
            etiqueta: avistamientos.length == 1
                ? 'Avistamiento'
                : 'Avistamientos',
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          dato(
            icono: Icons.bookmark_rounded,
            valor: fotosGuardadas.length,
            etiqueta: fotosGuardadas.length == 1
                ? 'Ave guardada'
                : 'Aves guardadas',
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezadoSeccion(
    BuildContext context, {
    required String titulo,
    VoidCallback? onVerTodo,
    String etiquetaVerTodo = 'Ver todo',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10, bottom: 1),
            decoration: BoxDecoration(
              color: PaletaAves.amarillo,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ),
          if (onVerTodo != null)
            TextButton(
              onPressed: onVerTodo,
              style: TextButton.styleFrom(
                foregroundColor: PaletaAves.violeta,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(etiquetaVerTodo),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaVacia(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String mensaje,
    required String accion,
    required VoidCallback onAccion,
  }) {
    final marca = context.marca;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: formaTarjetaAve(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 36, color: marca.iconoMarca),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(mensaje, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAccion,
              style: FilledButton.styleFrom(
                backgroundColor: PaletaAves.morado,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(accion),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAccesoRapido(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String mensaje,
    required VoidCallback onAccion,
    bool destacado = false,
  }) {
    final iconoColor = destacado ? PaletaAves.morado : Colors.white;
    final fondoIcono = destacado
        ? PaletaAves.amarillo
        : Colors.white.withValues(alpha: 0.18);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onAccion,
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: destacado
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PaletaAves.morado, PaletaAves.violeta],
                  ),
            color: destacado ? PaletaAves.amarillo : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, color: iconoColor, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: destacado ? PaletaAves.morado : Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mensaje,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: destacado
                      ? PaletaAves.morado.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.88),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaAvistamientoReciente extends StatelessWidget {
  const _TarjetaAvistamientoReciente({
    required this.avistamiento,
    required this.fechaFormateada,
    required this.onAbrir,
  });

  final AvistamientoPropio avistamiento;
  final String fechaFormateada;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: formaTarjetaAve(context),
        child: InkWell(
          onTap: onAbrir,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(avistamiento.rutaImagen),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: marca.placeholder,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: PaletaAves.violeta,
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avistamiento.nombreAve,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 13,
                          color: PaletaAves.amarillo,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${avistamiento.lugar} · $fechaFormateada',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaFotoComunidad extends StatelessWidget {
  const _TarjetaFotoComunidad({required this.foto, required this.onAbrir});

  final FotoPublica foto;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: formaTarjetaAve(context),
        child: InkWell(
          onTap: onAbrir,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                foto.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: marca.placeholder,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: PaletaAves.violeta,
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foto.autor ?? 'Observador',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          size: 13,
                          color: PaletaAves.amarillo,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            [
                              if (foto.categoria.isNotEmpty) foto.categoria,
                              if (foto.lugar != null && foto.lugar!.isNotEmpty)
                                foto.lugar!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
