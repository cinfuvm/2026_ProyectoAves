import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ave_catalogo.dart';
import '../models/avistamiento_propio.dart';
import '../models/categoria_ave.dart';
import '../models/filtro_coleccion.dart';
import '../models/foto_guardada.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_reportar.dart';
import '../widgets/hoja_filtros_coleccion.dart';
import '../widgets/texto_expandible.dart';
import '../widgets/visor_foto.dart';

/// Sección de colección local: avistamientos propios y aves guardadas,
/// con filtros por tipo, categoría y búsqueda.
class ColeccionScreen extends StatelessWidget {
  const ColeccionScreen({
    super.key,
    required this.cargando,
    required this.error,
    required this.fotosGuardadas,
    required this.avistamientosPropios,
    required this.avesCargadas,
    required this.filtro,
    required this.onReintentarCarga,
    required this.onFiltroChanged,
    required this.onQuitarAvistamiento,
    required this.onAvistamientoQuitado,
    required this.onQuitarFoto,
    required this.onFotoQuitada,
    required this.onReportarAvistamiento,
    required this.onReportarFoto,
    required this.onAbrirFicha,
  });

  final bool cargando;
  final String? error;
  final List<FotoGuardada> fotosGuardadas;
  final List<AvistamientoPropio> avistamientosPropios;
  final List<AveCatalogo> avesCargadas;
  final FiltroColeccion filtro;
  final VoidCallback onReintentarCarga;
  final ValueChanged<FiltroColeccion> onFiltroChanged;
  final Future<bool> Function(AvistamientoPropio avistamiento)
  onQuitarAvistamiento;
  final ValueChanged<AvistamientoPropio> onAvistamientoQuitado;
  final Future<bool> Function(FotoGuardada foto) onQuitarFoto;
  final ValueChanged<FotoGuardada> onFotoQuitada;
  final ValueChanged<AvistamientoPropio> onReportarAvistamiento;
  final ValueChanged<FotoGuardada> onReportarFoto;
  final ValueChanged<String> onAbrirFicha;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: PaletaAves.morado),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: PaletaAves.violeta,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'No se pudo cargar tu colección: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReintentarCarga,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final aplicador = AplicadorFiltrosColeccion(
      fotos: fotosGuardadas,
      avistamientos: avistamientosPropios,
      categoriaDeAvistamiento: _categoriaAvistamiento,
    );
    final fotosVisibles = aplicador.fotosVisibles(filtro);
    final avistamientosVisibles = aplicador.avistamientosVisibles(filtro);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tu colección',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _construirBarraFiltros(context, aplicador: aplicador),
        const SizedBox(height: 16),
        if (fotosGuardadas.isEmpty && avistamientosPropios.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 48,
                  color: context.marca.iconoMarca,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu colección está vacía',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Guarda aves del catálogo o agrega una foto con sus datos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (avistamientosVisibles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Avistamientos propios',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ...avistamientosVisibles.map(
          (avistamiento) => _TarjetaConSalida(
            key: ValueKey<String>('avistamiento:${avistamiento.rutaImagen}'),
            eliminar: () => onQuitarAvistamiento(avistamiento),
            alEliminar: () => onAvistamientoQuitado(avistamiento),
            construir: (onQuitar, quitando) => _TarjetaAvistamientoPropio(
              avistamiento: avistamiento,
              fechaFormateada: formatearFecha(avistamiento.fecha),
              onQuitar: onQuitar,
              quitando: quitando,
              onReportar: () => onReportarAvistamiento(avistamiento),
            ),
          ),
        ),
        if (fotosVisibles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'Aves guardadas',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ...fotosVisibles.map(
          (foto) => _TarjetaConSalida(
            key: ValueKey<String>('guardada:${foto.id}'),
            eliminar: () => onQuitarFoto(foto),
            alEliminar: () => onFotoQuitada(foto),
            construir: (onQuitar, quitando) => _TarjetaFotoGuardada(
              foto: foto,
              onQuitar: onQuitar,
              quitando: quitando,
              onAbrirFicha: foto.urlFicha == null
                  ? null
                  : () => onAbrirFicha(foto.urlFicha!),
              onReportar: () => onReportarFoto(foto),
            ),
          ),
        ),
        if ((fotosGuardadas.isNotEmpty || avistamientosPropios.isNotEmpty) &&
            fotosVisibles.isEmpty &&
            avistamientosVisibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Text(
              'No hay registros que coincidan con estos filtros.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// Una sola fila compacta: el botón que abre la hoja de filtros y, al lado,
  /// los filtros activos como chips que se quitan al tocar la ✕.
  Widget _construirBarraFiltros(
    BuildContext context, {
    required AplicadorFiltrosColeccion aplicador,
  }) {
    final marca = context.marca;
    final estiloChip = TextStyle(
      color: marca.chipTexto,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    final resumenes = <Widget>[
      if (filtro.tipo != FiltroColeccion.tipoPorDefecto)
        _chipResumen(context, filtro.tipo, () {
          onFiltroChanged(filtro.copiarCon(tipo: FiltroColeccion.tipoPorDefecto));
        }),
      if (filtro.categoria != FiltroColeccion.categoriaPorDefecto)
        _chipResumen(context, filtro.categoria, () {
          onFiltroChanged(
            filtro.copiarCon(categoria: FiltroColeccion.categoriaPorDefecto),
          );
        }),
      if (filtro.busqueda.trim().isNotEmpty)
        _chipResumen(context, '“${filtro.busqueda.trim()}”', () {
          onFiltroChanged(filtro.copiarCon(busqueda: ''));
        }),
    ];

    return Row(
      children: [
        ActionChip(
          avatar: const Icon(Icons.tune, size: 17),
          label: Text(
            filtro.ejesActivos == 0
                ? 'Filtrar'
                : 'Filtrar (${filtro.ejesActivos})',
          ),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: marca.chipBorde),
          backgroundColor: marca.chipFondo,
          labelStyle: estiloChip,
          onPressed: () => mostrarHojaFiltrosColeccion(
            context,
            filtro: filtro,
            aplicador: aplicador,
            onFiltroChanged: onFiltroChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: resumenes.isEmpty
              ? const SizedBox.shrink()
              : Wrap(spacing: 6, runSpacing: 6, children: resumenes),
        ),
      ],
    );
  }

  Widget _chipResumen(
    BuildContext context,
    String etiqueta,
    VoidCallback onQuitar,
  ) {
    final marca = context.marca;
    return InputChip(
      label: Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis),
      onDeleted: onQuitar,
      deleteIcon: const Icon(Icons.close, size: 15),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: marca.chipBorde),
      backgroundColor: marca.chipFondo,
      labelStyle: TextStyle(
        color: marca.chipTexto,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  String _categoriaAvistamiento(AvistamientoPropio avistamiento) {
    final categoria = avistamiento.categoria.trim();
    if (categoria.isNotEmpty) return categoriaGeneralAves(categoria);

    final nombreAve = avistamiento.nombreAve.trim().toLowerCase();
    final nombreCientifico = avistamiento.nombreCientifico.trim().toLowerCase();
    for (final ave in avesCargadas) {
      if (ave.nombre.toLowerCase() == nombreAve ||
          (nombreCientifico.isNotEmpty &&
              ave.nombreCientifico.toLowerCase() == nombreCientifico)) {
        return ave.categoria;
      }
    }
    return 'Sin clasificar';
  }
}

class _TarjetaConSalida extends StatefulWidget {
  const _TarjetaConSalida({
    super.key,
    required this.construir,
    required this.eliminar,
    required this.alEliminar,
  });

  final Widget Function(VoidCallback onQuitar, bool quitando) construir;
  final Future<bool> Function() eliminar;
  final VoidCallback alEliminar;

  @override
  State<_TarjetaConSalida> createState() => _TarjetaConSalidaState();
}

class _TarjetaConSalidaState extends State<_TarjetaConSalida> {
  bool _quitando = false;
  bool _saliendo = false;

  Future<void> _eliminar() async {
    if (_quitando || _saliendo) return;
    final eliminar = widget.eliminar;
    final alEliminar = widget.alEliminar;
    setState(() {
      _quitando = true;
    });

    final eliminado = await eliminar();
    if (!eliminado) {
      if (mounted) {
        setState(() {
          _quitando = false;
        });
      }
      return;
    }
    if (!mounted) {
      alEliminar();
      return;
    }

    setState(() {
      _saliendo = true;
    });
    await Future<void>.delayed(duracion(context, 220));
    alEliminar();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: _saliendo ? 0 : 1),
      duration: duracion(context, 220),
      curve: Curves.easeInOutCubic,
      builder: (context, avance, child) {
        final direccion = Directionality.of(context) == TextDirection.ltr
            ? 1.0
            : -1.0;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: avance,
            child: Opacity(
              opacity: avance,
              child: Transform.translate(
                offset: Offset(direccion * 14 * (1 - avance), 0),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.construir(_eliminar, _quitando),
    );
  }
}

class _TarjetaAvistamientoPropio extends StatelessWidget {
  const _TarjetaAvistamientoPropio({
    required this.avistamiento,
    required this.fechaFormateada,
    required this.onQuitar,
    required this.quitando,
    required this.onReportar,
  });

  final AvistamientoPropio avistamiento;
  final String fechaFormateada;
  final VoidCallback onQuitar;
  final bool quitando;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'avist:${avistamiento.rutaImagen}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: formaTarjetaAve(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => mostrarVisorFoto(
                  context,
                  etiquetaHero: etiquetaHero,
                  titulo: avistamiento.nombreAve,
                  subtitulo: null,
                  construirImagen: (_) => Image.file(
                    File(avistamiento.rutaImagen),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Hero(
                  tag: etiquetaHero,
                  child: Image.file(
                    File(avistamiento.rutaImagen),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 240,
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: BotonReportar(onPressed: onReportar),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avistamiento.nombreAve,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (avistamiento.nombreCientifico.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    avistamiento.nombreCientifico,
                    style: GoogleFonts.fraunces(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: marca.textoCientifico,
                    ),
                  ),
                ],
                if (avistamiento.categoria.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: PaletaAves.morado,
                    ),
                    label: Text(avistamiento.categoria),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: marca.chipBorde),
                    backgroundColor: marca.chipFondo,
                    labelStyle: TextStyle(color: marca.chipTexto),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: PaletaAves.violeta,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        avistamiento.lugar,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: PaletaAves.violeta,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(fechaFormateada),
                  ],
                ),
                const SizedBox(height: 12),
                TextoExpandible(
                  texto: avistamiento.comentario,
                  estilo: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  'Avistamiento guardado en este dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: marca.textoSecundario),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: quitando ? null : onQuitar,
                    style: TextButton.styleFrom(
                      foregroundColor: PaletaAves.morado,
                    ),
                    icon: quitando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(quitando ? 'Quitando…' : 'Quitar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaFotoGuardada extends StatelessWidget {
  const _TarjetaFotoGuardada({
    required this.foto,
    required this.onQuitar,
    required this.quitando,
    required this.onAbrirFicha,
    required this.onReportar,
  });

  final FotoGuardada foto;
  final VoidCallback onQuitar;
  final bool quitando;
  final VoidCallback? onAbrirFicha;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'foto:${foto.id}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: formaTarjetaAve(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => mostrarVisorFoto(
                  context,
                  etiquetaHero: etiquetaHero,
                  titulo: foto.nombre,
                  subtitulo: foto.nombreCientifico,
                  construirImagen: (_) => Image.file(
                    File(foto.rutaImagen),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Hero(
                  tag: etiquetaHero,
                  child: Image.file(
                    File(foto.rutaImagen),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 220,
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: BotonReportar(onPressed: onReportar),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  foto.nombreCientifico,
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: marca.textoCientifico,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(foto.categoria),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                TextoExpandible(texto: foto.descripcion),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      if (onAbrirFicha != null)
                        TextButton.icon(
                          onPressed: onAbrirFicha,
                          style: TextButton.styleFrom(
                            foregroundColor: PaletaAves.morado,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Aves de Chile'),
                        ),
                      TextButton.icon(
                        onPressed: quitando ? null : onQuitar,
                        style: TextButton.styleFrom(
                          foregroundColor: PaletaAves.morado,
                        ),
                        icon: quitando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bookmark_remove_outlined),
                        label: Text(quitando ? 'Quitando…' : 'Quitar'),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Imagen guardada en este dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: marca.textoSecundario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
