import 'package:bitacora_aves/models/avistamiento_propio.dart';
import 'package:bitacora_aves/models/categoria_ave.dart';
import 'package:bitacora_aves/models/filtro_coleccion.dart';
import 'package:bitacora_aves/models/foto_guardada.dart';
import 'package:flutter_test/flutter_test.dart';

FotoGuardada _foto({
  required String nombre,
  String categoria = 'Rapaces',
  String nombreCientifico = '',
  String descripcion = '',
}) => FotoGuardada(
  id: nombre,
  nombre: nombre,
  categoria: categoria,
  nombreCientifico: nombreCientifico,
  descripcion: descripcion,
  rutaImagen: '/tmp/$nombre.png',
  urlImagen: 'https://ejemplo/$nombre.jpg',
  urlFicha: null,
);

AvistamientoPropio _avistamiento({
  required String nombreAve,
  String categoria = '',
  String lugar = 'Santiago',
  String comentario = '',
}) => AvistamientoPropio(
  nombreAve: nombreAve,
  nombreCientifico: '',
  categoria: categoria,
  lugar: lugar,
  fecha: DateTime(2026, 5, 1),
  comentario: comentario,
  rutaImagen: '/tmp/$nombreAve.png',
);

AplicadorFiltrosColeccion _aplicador() => AplicadorFiltrosColeccion(
  fotos: [
    _foto(nombre: 'Águila Morada', categoria: 'Accipitriformes'),
    _foto(nombre: 'Garza Real', categoria: 'Humedal'),
  ],
  avistamientos: [
    _avistamiento(nombreAve: 'Pato Corto', categoria: 'Anseriformes'),
    _avistamiento(
      nombreAve: 'Gaviota',
      lugar: 'Valparaíso',
      comentario: 'Vista en el humedal',
    ),
  ],
  categoriaDeAvistamiento: (avistamiento) {
    final categoria = avistamiento.categoria.trim();
    return categoria.isEmpty
        ? 'Sin clasificar'
        : categoriaGeneralAves(categoria);
  },
);

void main() {
  group('FiltroColeccion', () {
    test('por defecto no filtra nada y reporta cero ejes activos', () {
      const filtro = FiltroColeccion();
      expect(filtro.ejesActivos, 0);
      expect(filtro.esPorDefecto, isTrue);
    });

    test('cuenta cada eje activo por separado', () {
      expect(
        const FiltroColeccion(tipo: 'Mis avistamientos').ejesActivos,
        1,
      );
      expect(const FiltroColeccion(categoria: 'Acuáticas').ejesActivos, 1);
      expect(const FiltroColeccion(busqueda: '  ').ejesActivos, 0);
      expect(const FiltroColeccion(busqueda: 'pato').ejesActivos, 1);
      expect(
        const FiltroColeccion(
          tipo: 'Aves guardadas',
          categoria: 'Rapaces',
          busqueda: 'águila',
        ).ejesActivos,
        3,
      );
    });

    test('copiarCon solo cambia los ejes indicados', () {
      const filtro = FiltroColeccion(
        tipo: 'Aves guardadas',
        categoria: 'Rapaces',
        busqueda: 'águila',
      );
      final copia = filtro.copiarCon(categoria: 'Marinas');
      expect(copia.tipo, 'Aves guardadas');
      expect(copia.categoria, 'Marinas');
      expect(copia.busqueda, 'águila');
      expect(filtro.categoria, 'Rapaces');
    });
  });

  group('AplicadorFiltrosColeccion', () {
    test('sin filtro muestra la colección completa', () {
      final aplicador = _aplicador();
      expect(aplicador.fotosVisibles(const FiltroColeccion()).length, 2);
      expect(
        aplicador.avistamientosVisibles(const FiltroColeccion()).length,
        2,
      );
      expect(aplicador.totalVisibles(const FiltroColeccion()), 4);
    });

    test('el tipo decide qué colección se ve', () {
      final aplicador = _aplicador();
      final soloGuardadas = aplicador
          .fotosVisibles(const FiltroColeccion(tipo: 'Aves guardadas'));
      final sinAvistamientos = aplicador.avistamientosVisibles(
        const FiltroColeccion(tipo: 'Aves guardadas'),
      );
      expect(soloGuardadas, hasLength(2));
      expect(sinAvistamientos, isEmpty);

      final soloAvistamientos = aplicador.avistamientosVisibles(
        const FiltroColeccion(tipo: 'Mis avistamientos'),
      );
      expect(soloAvistamientos, hasLength(2));
      expect(
        aplicador.fotosVisibles(const FiltroColeccion(tipo: 'Mis avistamientos')),
        isEmpty,
      );
    });

    test('la categoría se aplica sobre categorías normalizadas', () {
      final aplicador = _aplicador();
      final filtro = const FiltroColeccion(categoria: 'Rapaces');
      expect(aplicador.fotosVisibles(filtro).map((f) => f.nombre), [
        'Águila Morada',
      ]);
      expect(aplicador.avistamientosVisibles(filtro), isEmpty);
    });

    test('la búsqueda encuentra por nombre sin importar acentos', () {
      final aplicador = _aplicador();
      final resultado = aplicador.fotosVisibles(
        const FiltroColeccion(busqueda: 'aguila'),
      );
      expect(resultado.map((f) => f.nombre), ['Águila Morada']);
    });

    test('la búsqueda también mira lugar y comentario', () {
      final aplicador = _aplicador();
      expect(
        aplicador
            .avistamientosVisibles(const FiltroColeccion(busqueda: 'valparaiso'))
            .map((a) => a.nombreAve),
        ['Gaviota'],
      );
      expect(
        aplicador
            .avistamientosVisibles(const FiltroColeccion(busqueda: 'humedal'))
            .map((a) => a.nombreAve),
        ['Gaviota'],
      );
    });

    test('el conteo por categoría ignora el filtro de categoría', () {
      final aplicador = _aplicador();
      final conteo = aplicador.conteoPorCategoria(const FiltroColeccion());
      expect(conteo['Rapaces'], 1);
      expect(conteo['Acuáticas'], 2);
      expect(conteo['Sin clasificar'], 1);
      // «Todas» suma el total de las categorías reales.
      expect(conteo['Todas'], 4);
    });

    test('el conteo por tipo suma «Todo» de los otros dos', () {
      final aplicador = _aplicador();
      final conteo = aplicador.conteoPorTipo(const FiltroColeccion());
      expect(conteo['Aves guardadas'], 2);
      expect(conteo['Mis avistamientos'], 2);
      expect(conteo['Todo'], 4);
    });

    test('las categorías disponibles arrancan con Todas y salen ordenadas', () {
      expect(_aplicador().categoriasDisponibles(), [
        'Todas',
        'Acuáticas',
        'Rapaces',
        'Sin clasificar',
      ]);
    });
  });
}
