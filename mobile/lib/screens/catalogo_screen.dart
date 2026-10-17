import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ave_catalogo.dart';
import '../models/foto_guardada.dart';
import '../theme/app_theme.dart';
import '../widgets/aparicion_diferida.dart';
import '../widgets/boton_reportar.dart';
import '../widgets/texto_expandible.dart';
import '../widgets/visor_foto.dart';

/// Sección de búsqueda y catálogo de aves de Chile.
class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({
    super.key,
    required this.aves,
    required this.avesCargadas,
    required this.fichasCargadas,
    required this.entradaCatalogoPendiente,
    required this.consulta,
    required this.categoriaSeleccionada,
    required this.controladorBusqueda,
    required this.fotosGuardadas,
    required this.avesGuardandose,
    required this.onConsultaChanged,
    required this.onCategoriaChanged,
    required this.onReintentar,
    required this.onReintentarCarga,
    required this.onAbrirFicha,
    required this.onReportar,
    required this.onGuardar,
    required this.onQuitar,
  });

  final Future<List<AveCatalogo>> aves;
  final List<AveCatalogo> avesCargadas;
  final int fichasCargadas;
  final bool entradaCatalogoPendiente;
  final String consulta;
  final String categoriaSeleccionada;
  final TextEditingController controladorBusqueda;
  final List<FotoGuardada> fotosGuardadas;
  final Set<String> avesGuardandose;
  final ValueChanged<String> onConsultaChanged;
  final ValueChanged<String> onCategoriaChanged;
  final VoidCallback onReintentar;
  final VoidCallback onReintentarCarga;
  final ValueChanged<AveCatalogo> onAbrirFicha;
  final ValueChanged<AveCatalogo> onReportar;
  final ValueChanged<AveCatalogo> onGuardar;
  final ValueChanged<AveCatalogo> onQuitar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AveCatalogo>>(
      future: aves,
      builder: (context, snapshot) {
        final avesVisiblesCargadas = snapshot.data ?? avesCargadas;
        if (snapshot.connectionState == ConnectionState.waiting &&
            avesVisiblesCargadas.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: PaletaAves.morado),
          );
        }
        if (snapshot.hasError && avesVisiblesCargadas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_outlined,
                    size: 48,
                    color: PaletaAves.violeta,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las aves de Chile. '
                    'Revisa tu conexión e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final categorias = [
          'Todas',
          ...avesVisiblesCargadas
              .map((ave) => ave.categoria)
              .where((categoria) => categoria.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        ];
        final avesVisibles = avesVisiblesCargadas.where((ave) {
          final consultaActual = consulta.toLowerCase().trim();
          final coincideCategoria =
              categoriaSeleccionada == 'Todas' ||
              ave.categoria == categoriaSeleccionada;
          final coincideTexto =
              consultaActual.isEmpty ||
              ave.nombre.toLowerCase().contains(consultaActual) ||
              ave.nombreCientifico.toLowerCase().contains(consultaActual) ||
              ave.descripcion.toLowerCase().contains(consultaActual) ||
              ave.palabrasClave.toLowerCase().contains(consultaActual);
          return coincideCategoria && coincideTexto;
        }).toList();

        final contenidoFijo = <Widget>[_construirEncabezadoBusqueda(context)];
        if (snapshot.connectionState == ConnectionState.waiting) {
          contenidoFijo.addAll([
            Text(
              'Cargando fichas: $fichasCargadas de ${avesVisiblesCargadas.length}',
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: fichasCargadas / avesVisiblesCargadas.length,
            ),
            const SizedBox(height: 12),
          ]);
        }
        if (snapshot.hasError) {
          contenidoFijo.addAll([
            Text(
              'No se completó la carga de todas las fichas. '
              'Puedes reintentar.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReintentarCarga,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar carga'),
              ),
            ),
          ]);
        }
        contenidoFijo.addAll([
          const SizedBox(height: 16),
          TextField(
            controller: controladorBusqueda,
            onChanged: onConsultaChanged,
            decoration: InputDecoration(
              hintText: 'Nombre común o científico',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: AnimatedSwitcher(
                duration: duracion(context, 150),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (hijo, anim) =>
                    FadeTransition(opacity: anim, child: hijo),
                child: consulta.isEmpty
                    ? const SizedBox.shrink(
                        key: ValueKey<String>('sin-consulta'),
                      )
                    : IconButton(
                        key: const ValueKey<String>('limpiar-consulta'),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          controladorBusqueda.clear();
                          onConsultaChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Explorar por categoría',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final categoria = categorias[index];
                final marca = context.marca;
                return ChoiceChip(
                  label: Text(categoria),
                  selected: categoriaSeleccionada == categoria,
                  selectedColor: PaletaAves.morado,
                  backgroundColor: marca.chipFondo,
                  labelStyle: TextStyle(
                    color: categoriaSeleccionada == categoria
                        ? Colors.white
                        : marca.chipTexto,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: categoriaSeleccionada == categoria
                        ? PaletaAves.morado
                        : marca.chipBorde,
                  ),
                  onSelected: (seleccionada) {
                    if (seleccionada) {
                      onCategoriaChanged(categoria);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ]);
        if (avesVisibles.isEmpty) {
          contenidoFijo.add(
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No encontramos aves con esos filtros.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          itemCount: contenidoFijo.length + avesVisibles.length,
          itemBuilder: (context, index) {
            if (index < contenidoFijo.length) return contenidoFijo[index];

            final indiceAve = index - contenidoFijo.length;
            final ave = avesVisibles[indiceAve];
            return AparicionDiferida(
              key: ValueKey<String>(ave.uid),
              indice: indiceAve,
              activa: entradaCatalogoPendiente,
              child: _TarjetaAve(
                ave: ave,
                onAbrirFicha: () => onAbrirFicha(ave),
                onReportar: () => onReportar(ave),
                guardada: fotosGuardadas.any((foto) => foto.id == ave.uid),
                guardando: avesGuardandose.contains(ave.uid),
                onGuardar: () => onGuardar(ave),
                onQuitar: () => onQuitar(ave),
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirEncabezadoBusqueda(BuildContext context) {
    final marca = context.marca;
    final esApaisada =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esApaisada ? 14 : 20),
      decoration: BoxDecoration(
        gradient: marca.cabeceraGradiente,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: esApaisada
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explora y descubre',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encuentra tu próxima ave favorita.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PaletaAves.amarillo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 76,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explora y descubre',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Encuentra tu próxima ave favorita.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PaletaAves.amarillo,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _TarjetaAve extends StatelessWidget {
  const _TarjetaAve({
    required this.ave,
    required this.onAbrirFicha,
    required this.onReportar,
    required this.guardada,
    required this.guardando,
    required this.onGuardar,
    required this.onQuitar,
  });

  final AveCatalogo ave;
  final VoidCallback onAbrirFicha;
  final VoidCallback onReportar;
  final bool guardada;
  final bool guardando;
  final VoidCallback onGuardar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'ave:${ave.uid}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: formaTarjetaAve(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esApaisada =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 640;
          final alturaImagen = esApaisada ? 180.0 : 220.0;
          final anchoImagen = esApaisada
              ? (constraints.maxWidth * 0.36).clamp(200.0, 260.0).toDouble()
              : constraints.maxWidth;
          final imagen = SizedBox(
            width: anchoImagen,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => mostrarVisorFoto(
                    context,
                    etiquetaHero: etiquetaHero,
                    titulo: ave.nombre,
                    subtitulo: ave.nombreCientifico,
                    construirImagen: (_) => Image.network(
                      ave.urlImagen,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: marca.placeholder,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                            color: PaletaAves.violeta,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: etiquetaHero,
                    child: Image.network(
                      ave.urlImagen,
                      height: alturaImagen,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (anchoImagen * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: alturaImagen,
                          color: marca.placeholder,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: PaletaAves.morado,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: alturaImagen,
                        color: marca.placeholder,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                            color: PaletaAves.violeta,
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 82,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          PaletaAves.morado.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [PaletaAves.amarillo, Color(0xFFFFE88A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ave.categoria,
                      style: const TextStyle(
                        color: PaletaAves.morado,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Aves de Chile',
                      style: TextStyle(
                        color: PaletaAves.morado,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          final detalles = Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ave.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ave.nombreCientifico,
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: marca.textoCientifico,
                  ),
                ),
                const SizedBox(height: 10),
                TextoExpandible(
                  texto: ave.descripcion,
                  estilo: TextStyle(color: marca.textoCuerpo, height: 1.45),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: guardando
                            ? null
                            : guardada
                            ? onQuitar
                            : onGuardar,
                        icon: AnimatedSwitcher(
                          duration: duracion(context, 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (hijo, anim) => RotationTransition(
                            turns: Tween<double>(
                              begin: 0.035,
                              end: 0,
                            ).animate(anim),
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.65,
                                end: 1,
                              ).animate(anim),
                              child: FadeTransition(opacity: anim, child: hijo),
                            ),
                          ),
                          child: guardando
                              ? const SizedBox(
                                  key: ValueKey<String>('guardando'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  guardada
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  key: ValueKey<bool>(guardada),
                                ),
                        ),
                        label: AnimatedSwitcher(
                          duration: duracion(context, 180),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (hijo, anim) =>
                              FadeTransition(opacity: anim, child: hijo),
                          child: Text(
                            guardada ? 'Quitar' : 'Guardar',
                            key: ValueKey<bool>(guardada),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onAbrirFicha,
                        style: TextButton.styleFrom(
                          foregroundColor: PaletaAves.morado,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Aves de Chile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (esApaisada) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imagen,
                Expanded(child: detalles),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [imagen, detalles],
          );
        },
      ),
    );
  }
}
