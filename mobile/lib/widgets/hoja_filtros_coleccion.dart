import 'package:flutter/material.dart';

import '../models/filtro_coleccion.dart';
import '../theme/app_theme.dart';

/// Abre la hoja de filtros de la colección.
///
/// Los cambios se aplican en vivo sobre la lista de fondo vía
/// [onFiltroChanged]; el botón del pie solo la cierra.
Future<void> mostrarHojaFiltrosColeccion(
  BuildContext context, {
  required FiltroColeccion filtro,
  required AplicadorFiltrosColeccion aplicador,
  required ValueChanged<FiltroColeccion> onFiltroChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => HojaFiltrosColeccion(
      filtro: filtro,
      aplicador: aplicador,
      onFiltroChanged: onFiltroChanged,
    ),
  );
}

class HojaFiltrosColeccion extends StatefulWidget {
  const HojaFiltrosColeccion({
    super.key,
    required this.filtro,
    required this.aplicador,
    required this.onFiltroChanged,
  });

  final FiltroColeccion filtro;
  final AplicadorFiltrosColeccion aplicador;
  final ValueChanged<FiltroColeccion> onFiltroChanged;

  @override
  State<HojaFiltrosColeccion> createState() => _HojaFiltrosColeccionState();
}

class _HojaFiltrosColeccionState extends State<HojaFiltrosColeccion> {
  /// Copia local que se actualiza al tocar cada control; el resto de la app
  /// se entera por [onFiltroChanged].
  late FiltroColeccion _filtro = widget.filtro;
  late final TextEditingController _busqueda =
      TextEditingController(text: widget.filtro.busqueda);

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _aplicar(FiltroColeccion nuevo) {
    setState(() {
      _filtro = nuevo;
    });
    widget.onFiltroChanged(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final conteoTipo = widget.aplicador.conteoPorTipo(_filtro);
    final conteoCategoria = widget.aplicador.conteoPorCategoria(_filtro);
    final visibles = widget.aplicador.totalVisibles(_filtro);

    return Padding(
      // Deja espacio para el teclado cuando se escribe en la búsqueda.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filtrar colección',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _busqueda,
              onChanged: (valor) => _aplicar(_filtro.copiarCon(busqueda: valor)),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nombre, lugar o comentario',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filtro.busqueda.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busqueda.clear();
                          _aplicar(_filtro.copiarCon(busqueda: ''));
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SeccionFiltro(
              icono: Icons.photo_library_outlined,
              titulo: 'Mostrar',
              children: [
                for (final tipo in tiposColeccion)
                  _chipOpcion(
                    etiqueta: tipo,
                    conteo: conteoTipo[tipo] ?? 0,
                    seleccionado: _filtro.tipo == tipo,
                    onTap: () => _aplicar(_filtro.copiarCon(tipo: tipo)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _SeccionFiltro(
              icono: Icons.category_outlined,
              titulo: 'Categoría',
              children: [
                for (final categoria in widget.aplicador.categoriasDisponibles())
                  _chipOpcion(
                    etiqueta: categoria,
                    conteo: conteoCategoria[categoria] ?? 0,
                    seleccionado: _filtro.categoria == categoria,
                    onTap: () => _aplicar(
                      _filtro.copiarCon(categoria: categoria),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _filtro.esPorDefecto
                        ? null
                        : () {
                            _busqueda.clear();
                            _aplicar(const FiltroColeccion());
                          },
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PaletaAves.morado,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      visibles == 1
                          ? 'Ver 1 resultado'
                          : 'Ver $visibles resultados',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipOpcion({
    required String etiqueta,
    required int conteo,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    final marca = context.marca;
    return ChoiceChip(
      label: Text('$etiqueta ($conteo)'),
      selected: seleccionado,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: seleccionado ? PaletaAves.morado : marca.chipBorde,
      ),
      backgroundColor: marca.chipFondo,
      selectedColor: PaletaAves.morado,
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : marca.chipTexto,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _SeccionFiltro extends StatelessWidget {
  const _SeccionFiltro({
    required this.icono,
    required this.titulo,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 17, color: PaletaAves.violeta),
            const SizedBox(width: 7),
            Text(
              titulo,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
