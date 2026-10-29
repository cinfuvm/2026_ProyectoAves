import 'package:flutter/material.dart';

import '../models/reporte_moderacion.dart';
import '../services/fotos_service.dart';
import '../theme/app_theme.dart';

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Revisa los reportes que los usuarios abren sobre las fotos del catálogo.
///
/// Solo la puede abrir el rol `admin`: el `detalle` de cada reporte y quién lo
/// abrió no son datos públicos. Si el backend contesta 403, la pantalla lo
/// enseña en lugar de dejar la lista en blanco.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key, this.servicio});

  /// Solo para las pruebas: sin él se usa el servicio real, que elige entre
  /// BFF y mock según `ApiConfig`.
  final FotosService? servicio;

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late final FotosService _servicio;

  /// Vacío = sin filtro, que es como `GET /images/reports` interpreta que
  /// se le piden todos.
  String _estado = '';
  List<ReporteModeracion> _reportes = const [];
  bool _cargando = true;
  String? _error;

  /// Identificador del reporte que se está moviendo, para bloquear solo sus
  /// botones y no la lista entera.
  String? _enCurso;

  @override
  void initState() {
    super.initState();
    _servicio = widget.servicio ?? FotosService();
    _cargar();
  }

  Future<void> _cargar({bool avisar = true}) async {
    if (avisar) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final reportes = await _servicio.getReportes(
        estado: _estado.isEmpty ? null : _estado,
      );
      if (!mounted) return;
      setState(() {
        _reportes = reportes;
        _cargando = false;
        _error = null;
        _enCurso = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = error.toString();
        _enCurso = null;
      });
    }
  }

  Future<void> _cambiarEstado(ReporteModeracion reporte, String estado) async {
    setState(() => _enCurso = reporte.id);
    try {
      await _servicio.cambiarEstadoReporte(id: reporte.id, estado: estado);
      // El reporte puede dejar de pertenecer al filtro activo, así que se
      // vuelve a leer la lista entera en vez de parchear la fila a mano.
      await _cargar(avisar: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _enCurso = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el reporte: $error')),
      );
    }
  }

  void _elegirEstado(String estado) {
    if (_estado == estado) return;
    setState(() => _estado = estado);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de moderación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _Filtros(
            estado: _estado,
            onElegir: _elegirEstado,
            deshabilitado: _cargando,
          ),
          Expanded(child: _contenido(context)),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final marca = context.marca;
    if (_error != null) {
      return _Aviso(
        icono: Icons.error_outline_rounded,
        titulo: 'No se pudieron cargar los reportes',
        detalle: _error!,
        accion: TextButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (_reportes.isEmpty) {
      return _Aviso(
        icono: Icons.inbox_outlined,
        titulo: 'Sin reportes',
        detalle: _estado.isEmpty
            ? 'Nadie ha reportado ninguna foto todavía.'
            : 'No hay reportes ${_textoEstado(_estado).toLowerCase()}.',
        estilo: marca.textoSecundario,
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reportes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, indice) {
          final reporte = _reportes[indice];
          return _TarjetaReporte(
            reporte: reporte,
            enCurso: _enCurso == reporte.id,
            onCambiar: (estado) => _cambiarEstado(reporte, estado),
          );
        },
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.estado,
    required this.onElegir,
    required this.deshabilitado,
  });

  final String estado;
  final ValueChanged<String> onElegir;
  final bool deshabilitado;

  @override
  Widget build(BuildContext context) {
    // «Todos» no es un estado del backend: se manda sin `estado` y el
    // servidor devuelve el listado completo.
    const opciones = <MapEntry<String, String>>[
      MapEntry('Todos', ''),
      MapEntry('Abiertos', 'abierto'),
      MapEntry('Revisados', 'revisado'),
      MapEntry('Descartados', 'descartado'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final opcion in opciones)
            ChoiceChip(
              label: Text(opcion.key),
              selected: estado == opcion.value,
              onSelected:
                  deshabilitado ? null : (_) => onElegir(opcion.value),
            ),
        ],
      ),
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({
    required this.reporte,
    required this.enCurso,
    required this.onCambiar,
  });

  final ReporteModeracion reporte;
  final bool enCurso;
  final ValueChanged<String> onCambiar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final foto = reporte.avistamiento;

    return Card(
      shape: formaTarjetaAve(context),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Miniatura(foto: foto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        motivoLegible(reporte.motivo),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: marca.tituloCard,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lineaFoto(foto),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: marca.textoSecundario),
                      ),
                      if (foto?.comentario?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          foto!.comentario!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: marca.textoCuerpo),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (reporte.detalle.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: marca.chipFondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: marca.chipBorde),
                ),
                child: Text(
                  reporte.detalle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: marca.chipTexto,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _EtiquetaEstado(estado: reporte.estado),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lineaReporte(reporte),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: marca.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (enCurso)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(),
              )
            else
              // `Wrap` y no `Row`: en pantallas estrechas los dos botones no
              // caben y la segunda fila se coloca debajo en vez de desbordar.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (!reporte.abierto)
                    TextButton.icon(
                      onPressed: () => onCambiar('abierto'),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Reabrir'),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: () => onCambiar('descartado'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Descartar'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => onCambiar('revisado'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Revisado'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({this.foto});

  final FotoReportada? foto;

  static const _medida = 72.0;

  Widget _hueco(BuildContext context, Widget? hijo) => ColoredBox(
    color: context.marca.placeholder,
    child: Center(child: hijo),
  );

  @override
  Widget build(BuildContext context) {
    final url = foto?.url ?? '';

    return SizedBox(
      width: _medida,
      height: _medida,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: url.isEmpty
            ? _hueco(context, const Icon(Icons.broken_image_outlined))
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, hijo, progreso) =>
                    progreso == null
                    ? hijo
                    : _hueco(
                        context,
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                // La foto puede haberse borrado: se enseña el hueco en vez de
                // reventar la lista entera.
                errorBuilder: (_, _, _) =>
                    _hueco(context, const Icon(Icons.broken_image_outlined)),
              ),
      ),
    );
  }
}

class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final (texto, color) = switch (estado) {
      'revisado' => (
        'Revisado',
        esOscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      ),
      'descartado' => (
        'Descartado',
        esOscuro ? const Color(0xFFB6B0BE) : const Color(0xFF544C5D),
      ),
      _ => (
        'Abierto',
        esOscuro ? const Color(0xFFFFCC80) : const Color(0xFF9A5B00),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
    this.estilo,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;
  final Color? estilo;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: estilo ?? marca.iconoMarca),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: estilo ?? marca.textoSecundario,
              ),
            ),
            if (accion != null) ...[const SizedBox(height: 8), accion!],
          ],
        ),
      ),
    );
  }
}

/// Texto legible de un estado (`abierto` → «Abiertos»), buscando en la misma
/// tabla que pinta los filtros.
String _textoEstado(String estado) {
  for (final entrada in const {
    'Abiertos': 'abierto',
    'Revisados': 'revisado',
    'Descartados': 'descartado',
  }.entries) {
    if (entrada.value == estado) return entrada.key;
  }
  return estado;
}

String _lineaFoto(FotoReportada? foto) {
  if (foto == null) return 'La foto ya no está en el catálogo';
  final partes = <String>[
    if (foto.categoria.isNotEmpty) foto.categoria,
    if (foto.autor?.isNotEmpty ?? false) foto.autor!,
    if (foto.lugar?.isNotEmpty ?? false) foto.lugar!,
  ];
  return partes.isEmpty ? 'Ficha de la foto' : partes.join(' · ');
}

String _lineaReporte(ReporteModeracion reporte) {
  final partes = <String>[
    if (reporte.reportadoPor?.isNotEmpty ?? false)
      'Reportado por ${reporte.reportadoPor}',
    if (reporte.creadoEn != null) _fecha(reporte.creadoEn!),
  ];
  return partes.join(' · ');
}

String _fecha(DateTime fecha) {
  final local = fecha.toLocal();
  final hora = '${local.hour.toString().padLeft(2, '0')}'
      ':${local.minute.toString().padLeft(2, '0')}';
  return '${local.day} ${_meses[local.month - 1]} ${local.year}, $hora';
}
