import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/categoria_ave.dart';
import '../models/foto_publica.dart';
import '../services/fotos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aparicion_diferida.dart';
import '../widgets/visor_foto.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({
    super.key,
    required this.onGuardar,
    required this.onReportar,
    required this.idsGuardados,
  });

  final Future<void> Function(FotoPublica foto) onGuardar;
  final void Function(FotoPublica foto) onReportar;
  final Set<String> idsGuardados;

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  static const _porPagina = 20;

  final _servicio = FotosService();
  final _controladorDesplazamiento = ScrollController();

  String _categoria = 'Todas';
  final List<FotoPublica> _fotos = [];
  int _pagina = 0;
  int _totalPaginas = 1;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  final Set<String> _guardandose = {};

  @override
  void initState() {
    super.initState();
    _controladorDesplazamiento.addListener(_alDesplazar);
    _cargar(pagina: 0);
  }

  @override
  void dispose() {
    _controladorDesplazamiento.dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (!_controladorDesplazamiento.hasClients || _cargandoMas) return;
    final posicion = _controladorDesplazamiento.position;
    if (posicion.pixels >= posicion.maxScrollExtent - 300) {
      _cargarMas();
    }
  }

  String _categoriaApi(String categoria) {
    return switch (categoria) {
      'Terrestres' => 'terrestres',
      'Acuáticas' => 'acuaticas',
      'Rapaces' => 'rapaces',
      'Marinas' => 'marinas',
      'Otras' => 'otras',
      _ => 'Todas',
    };
  }

  Future<void> _cargar({required int pagina}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultado = await _servicio.getFotos(
        categoria: _categoriaApi(_categoria),
        pagina: pagina,
        porPagina: _porPagina,
      );
      if (!mounted) return;
      setState(() {
        if (pagina == 0) _fotos.clear();
        _fotos.addAll(resultado.fotos);
        _pagina = resultado.pagina;
        _totalPaginas = resultado.total;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las fotos: $error';
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_pagina + 1 >= _totalPaginas) return;
    setState(() => _cargandoMas = true);
    try {
      final resultado = await _servicio.getFotos(
        categoria: _categoriaApi(_categoria),
        pagina: _pagina + 1,
        porPagina: _porPagina,
      );
      if (!mounted) return;
      setState(() {
        _fotos.addAll(resultado.fotos);
        _pagina = resultado.pagina;
        _totalPaginas = resultado.total;
      });
    } catch (error) {
      if (!mounted) return;
      _mostrarMensaje('No se pudieron cargar más fotos: $error');
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardar(FotoPublica foto) async {
    if (widget.idsGuardados.contains(foto.id) ||
        _guardandose.contains(foto.id)) {
      return;
    }
    setState(() => _guardandose.add(foto.id));
    try {
      await widget.onGuardar(foto);
    } finally {
      if (mounted) setState(() => _guardandose.remove(foto.id));
    }
  }

  Future<void> _abrirVisor(FotoPublica foto) async {
    await mostrarVisorFoto(
      context,
      etiquetaHero: 'explorar:${foto.id}',
      titulo: foto.autor ?? 'Observador',
      subtitulo: [
        if (foto.lugar != null && foto.lugar!.isNotEmpty) foto.lugar,
        if (foto.fecha != null && foto.fecha!.isNotEmpty) foto.fecha,
      ].join(' · '),
      construirImagen: (_) => Image.network(
        foto.url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progreso.expectedTotalBytes != null
                  ? progreso.cumulativeBytesLoaded / progreso.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 56),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Explorar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: GoogleFonts.fraunces().fontFamily,
              fontWeight: FontWeight.w700,
              color: marca.tituloCard,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              'Todas',
              ...categoriasGeneralesAves,
            ].map((categoria) {
              final seleccionada = categoria == _categoria;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(categoria),
                  selected: seleccionada,
                  onSelected: (valor) {
                    if (valor != true || seleccionada) return;
                    setState(() => _categoria = categoria);
                    _cargar(pagina: 0);
                  },
                  selectedColor: PaletaAves.amarillo,
                  checkmarkColor: PaletaAves.morado,
                  labelStyle: TextStyle(
                    color: seleccionada
                        ? PaletaAves.morado
                        : marca.chipTexto,
                    fontWeight: seleccionada
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  backgroundColor: marca.chipFondo,
                  side: BorderSide(color: marca.chipBorde),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _construirContenido(marca)),
      ],
    );
  }

  Widget _construirContenido(MarcaAves marca) {
    if (_cargando && _fotos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _fotos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: marca.textoSecundario,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _cargar(pagina: 0),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_fotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_outlined, size: 48, color: marca.textoSecundario),
            const SizedBox(height: 12),
            Text(
              'Aún no hay fotos en esta categoría.',
              style: TextStyle(color: marca.textoSecundario),
            ),
          ],
        ),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho >= 900 ? 4 : ancho >= 600 ? 3 : 2;

    return RefreshIndicator(
      onRefresh: () => _cargar(pagina: 0),
      child: GridView.builder(
        controller: _controladorDesplazamiento,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnas,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: _fotos.length + (_cargandoMas ? 1 : 0),
        itemBuilder: (context, indice) {
          if (indice >= _fotos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final foto = _fotos[indice];
          return AparicionDiferida(
            indice: indice,
            activa: true,
            child: _TarjetaFotoComunidad(
              foto: foto,
              marcada: widget.idsGuardados.contains(foto.id),
              guardando: _guardandose.contains(foto.id),
              onTap: () => _abrirVisor(foto),
              onGuardar: () => _guardar(foto),
              onReportar: () => widget.onReportar(foto),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaFotoComunidad extends StatelessWidget {
  const _TarjetaFotoComunidad({
    required this.foto,
    required this.marcada,
    required this.guardando,
    required this.onTap,
    required this.onGuardar,
    required this.onReportar,
  });

  final FotoPublica foto;
  final bool marcada;
  final bool guardando;
  final VoidCallback onTap;
  final VoidCallback onGuardar;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'explorar:${foto.id}';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: etiquetaHero,
                    child: Image.network(
                      foto.url,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      loadingBuilder: (context, child, progreso) {
                        if (progreso == null) return child;
                        return ColoredBox(
                          color: marca.placeholder,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: marca.placeholder,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: PaletaAves.violeta,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onReportar,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.flag_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          foto.autor ?? 'Observador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: marca.tituloCard,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (foto.lugar != null && foto.lugar!.isNotEmpty)
                          Text(
                            foto.lugar!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: marca.textoSecundario),
                          ),
                      ],
                    ),
                  ),
                  guardando
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: onGuardar,
                          tooltip: marcada
                              ? 'Ya está en tu colección'
                              : 'Guardar en colección',
                          iconSize: 28,
                          color: marcada
                              ? PaletaAves.amarillo
                              : marca.iconoMarca,
                          icon: Icon(
                            marcada
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
