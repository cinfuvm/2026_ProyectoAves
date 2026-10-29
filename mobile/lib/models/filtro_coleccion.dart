import 'avistamiento_propio.dart';
import 'categoria_ave.dart';
import 'foto_guardada.dart';

/// Tipos de tarjeta que puede mostrar la sección de colección.
const tiposColeccion = <String>['Todo', 'Aves guardadas', 'Mis avistamientos'];

/// Estado de los filtros de la colección: qué mostrar, de qué categoría es y
/// qué texto debe coincidir con el nombre, el lugar o el comentario.
class FiltroColeccion {
  const FiltroColeccion({
    this.tipo = 'Todo',
    this.categoria = 'Todas',
    this.busqueda = '',
  });

  static const tipoPorDefecto = 'Todo';
  static const categoriaPorDefecto = 'Todas';

  final String tipo;
  final String categoria;
  final String busqueda;

  /// Cantidad de ejes que están acotando la lista.
  int get ejesActivos =>
      (tipo == tipoPorDefecto ? 0 : 1) +
      (categoria == categoriaPorDefecto ? 0 : 1) +
      (busqueda.trim().isEmpty ? 0 : 1);

  /// Nada está filtrando: se ve toda la colección.
  bool get esPorDefecto => ejesActivos == 0;

  FiltroColeccion copiarCon({
    String? tipo,
    String? categoria,
    String? busqueda,
  }) => FiltroColeccion(
    tipo: tipo ?? this.tipo,
    categoria: categoria ?? this.categoria,
    busqueda: busqueda ?? this.busqueda,
  );

  @override
  bool operator ==(Object other) =>
      other is FiltroColeccion &&
      other.tipo == tipo &&
      other.categoria == categoria &&
      other.busqueda == busqueda;

  @override
  int get hashCode => Object.hash(tipo, categoria, busqueda);
}

/// Aplica un [FiltroColeccion] sobre las listas locales de la colección.
///
/// Es una clase aparte para que la pantalla y la hoja de filtros compartan el
/// mismo criterio de filtrado y de conteo, sin duplicar lógica.
class AplicadorFiltrosColeccion {
  AplicadorFiltrosColeccion({
    required this.fotos,
    required this.avistamientos,
    required this.categoriaDeAvistamiento,
  });

  final List<FotoGuardada> fotos;
  final List<AvistamientoPropio> avistamientos;

  /// Categoría general de un avistamiento (por campo o por el catálogo).
  final String Function(AvistamientoPropio avistamiento) categoriaDeAvistamiento;

  /// Aves guardadas que pasan el filtro completo.
  List<FotoGuardada> fotosVisibles(FiltroColeccion filtro) {
    if (filtro.tipo == 'Mis avistamientos') return const [];
    return fotos
        .where(
          (foto) => _coincide(
            filtro: filtro,
            tipo: 'Aves guardadas',
            categoria: categoriaGeneralAves(foto.categoria),
            campos: [foto.nombre, foto.nombreCientifico, foto.descripcion],
          ),
        )
        .toList();
  }

  /// Avistamientos propios que pasan el filtro completo.
  List<AvistamientoPropio> avistamientosVisibles(FiltroColeccion filtro) {
    if (filtro.tipo == 'Aves guardadas') return const [];
    return avistamientos
        .where(
          (avistamiento) => _coincide(
            filtro: filtro,
            tipo: 'Mis avistamientos',
            categoria: categoriaDeAvistamiento(avistamiento),
            campos: [
              avistamiento.nombreAve,
              avistamiento.nombreCientifico,
              avistamiento.lugar,
              avistamiento.comentario,
            ],
          ),
        )
        .toList();
  }

  /// Elementos visibles con el filtro completo (avistamientos + guardadas).
  int totalVisibles(FiltroColeccion filtro) =>
      fotosVisibles(filtro).length + avistamientosVisibles(filtro).length;

  /// Categorías presentes en la colección, con `Todas` como primera opción.
  List<String> categoriasDisponibles() {
    final categorias = <String>{
      for (final foto in fotos) categoriaGeneralAves(foto.categoria),
      for (final avistamiento in avistamientos)
        categoriaDeAvistamiento(avistamiento),
    }..removeWhere((categoria) => categoria.trim().isEmpty);
    categorias.remove(FiltroColeccion.categoriaPorDefecto);
    return [
      FiltroColeccion.categoriaPorDefecto,
      ...categorias.toList()..sort(),
    ];
  }

  /// Cuántos elementos tendría cada categoría si se eligiera esa. Ignora el
  /// filtro de categoría, así cada chip muestra su propio potencial.
  Map<String, int> conteoPorCategoria(FiltroColeccion filtro) {
    final sinCategoria = filtro.copiarCon(
      categoria: FiltroColeccion.categoriaPorDefecto,
    );
    final conteo = <String, int>{};
    void contar(String categoria, bool pasa) {
      if (!pasa) return;
      conteo[categoria] = (conteo[categoria] ?? 0) + 1;
    }

    for (final foto in fotos) {
      final categoria = categoriaGeneralAves(foto.categoria);
      contar(
        categoria,
        _coincide(
          filtro: sinCategoria,
          tipo: 'Aves guardadas',
          categoria: categoria,
          campos: [foto.nombre, foto.nombreCientifico, foto.descripcion],
        ),
      );
    }
    for (final avistamiento in avistamientos) {
      final categoria = categoriaDeAvistamiento(avistamiento);
      contar(
        categoria,
        _coincide(
          filtro: sinCategoria,
          tipo: 'Mis avistamientos',
          categoria: categoria,
          campos: [
            avistamiento.nombreAve,
            avistamiento.nombreCientifico,
            avistamiento.lugar,
            avistamiento.comentario,
          ],
        ),
      );
    }
    // «Todas» suma lo mismo que el resto de categorías juntas.
    conteo[FiltroColeccion.categoriaPorDefecto] = conteo.values.fold(
      0,
      (total, cantidad) => total + cantidad,
    );
    return conteo;
  }

  /// Cuántos elementos mostraría cada tipo si se eligiera ese. Ignora el
  /// filtro de tipo, por eso `Todo` es la suma de los otros dos.
  Map<String, int> conteoPorTipo(FiltroColeccion filtro) {
    final sinTipo = filtro.copiarCon(tipo: FiltroColeccion.tipoPorDefecto);
    final conteo = <String, int>{for (final tipo in tiposColeccion) tipo: 0};

    for (final foto in fotos) {
      if (_coincide(
        filtro: sinTipo,
        tipo: 'Aves guardadas',
        categoria: categoriaGeneralAves(foto.categoria),
        campos: [foto.nombre, foto.nombreCientifico, foto.descripcion],
      )) {
        conteo['Aves guardadas'] = conteo['Aves guardadas']! + 1;
      }
    }
    for (final avistamiento in avistamientos) {
      if (_coincide(
        filtro: sinTipo,
        tipo: 'Mis avistamientos',
        categoria: categoriaDeAvistamiento(avistamiento),
        campos: [
          avistamiento.nombreAve,
          avistamiento.nombreCientifico,
          avistamiento.lugar,
          avistamiento.comentario,
        ],
      )) {
        conteo['Mis avistamientos'] = conteo['Mis avistamientos']! + 1;
      }
    }
    conteo[FiltroColeccion.tipoPorDefecto] =
        conteo['Aves guardadas']! + conteo['Mis avistamientos']!;
    return conteo;
  }

  bool _coincide({
    required FiltroColeccion filtro,
    required String tipo,
    required String categoria,
    required List<String> campos,
  }) {
    if (filtro.tipo != FiltroColeccion.tipoPorDefecto &&
        filtro.tipo != tipo) {
      return false;
    }
    if (filtro.categoria != FiltroColeccion.categoriaPorDefecto &&
        filtro.categoria != categoria) {
      return false;
    }
    final texto = _normalizarTexto(filtro.busqueda);
    if (texto.isEmpty) return true;
    return campos.any((campo) => _normalizarTexto(campo).contains(texto));
  }
}

/// Minúsculas y sin acentos, para que "aguila" encuentre a "Águila".
String _normalizarTexto(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll(RegExp('[ñ]'), 'n')
    .trim();
