import '../models/foto_publica.dart';
import 'fotos_service.dart';

class FotosServiceMock implements FotosService {
  FotosServiceMock() : _fotos = List.of(_semilla);

  static const _urlBase = 'https://uvm.neocities.org/aves/fixtures';

  static final List<FotoPublica> _semilla = [
    FotoPublica(
      id: 'mock-8',
      url: '$_urlBase/56-anas-cyanoptera/image.jpg',
      categoria: 'Acuáticas',
      autor: 'sofia.patios',
      lugar: 'Laguna del Maule',
      fecha: '2026-09-25',
      subidaEn: DateTime.utc(2026, 9, 25),
      comentario: 'Pato colorado descansando entre juncos.',
    ),
    FotoPublica(
      id: 'mock-5',
      url: '$_urlBase/21-ardea-alba/image.jpg',
      categoria: 'Acuáticas',
      autor: 'camila.wings',
      lugar: 'Humedal de Pantanosa',
      fecha: '2026-09-21',
      subidaEn: DateTime.utc(2026, 9, 21),
      comentario: 'Garza grande pescando en aguas poco profundas.',
    ),
    FotoPublica(
      id: 'mock-4',
      url: '$_urlBase/79-milvago-chimango/image.jpg',
      categoria: 'Rapaces',
      autor: 'juan.observador',
      lugar: 'Parque Natural Los Arrayanes',
      fecha: '2026-09-18',
      subidaEn: DateTime.utc(2026, 9, 18),
      comentario: 'Tiuque posado esperando presas en el pastizal.',
    ),
    FotoPublica(
      id: 'mock-7',
      url: '$_urlBase/1-nothoprocta-perdicaria/image.jpg',
      categoria: 'Terrestres',
      autor: 'lucia.senderos',
      lugar: 'Chiloé, sector de Chonchi',
      fecha: '2026-09-14',
      subidaEn: DateTime.utc(2026, 9, 14),
      comentario: 'Perdiz chilena cruzando el camino de tierra.',
    ),
    FotoPublica(
      id: 'mock-1',
      url: '$_urlBase/68-vultur-gryphus/image.jpg',
      categoria: 'Rapaces',
      autor: 'ana.aves',
      lugar: 'Valle de Elqui',
      fecha: '2026-09-12',
      subidaEn: DateTime.utc(2026, 9, 12),
      comentario: 'Cóndor sobrevolando el cordón al atardecer.',
    ),
    FotoPublica(
      id: 'mock-6',
      url: '$_urlBase/116-larus-dominicanus/image.jpg',
      categoria: 'Marinas',
      autor: 'roberto.mar',
      lugar: 'Caleta Lo Rojas',
      fecha: '2026-09-05',
      subidaEn: DateTime.utc(2026, 9, 5),
      comentario: 'Gaviota dominicana sobrevolando las rocas.',
    ),
    FotoPublica(
      id: 'mock-3',
      url: '$_urlBase/29-phoenicopterus-chilensis/image.jpg',
      categoria: 'Acuáticas',
      autor: 'marcela.fotos',
      lugar: 'Laguna de Cachagua',
      fecha: '2026-09-02',
      subidaEn: DateTime.utc(2026, 9, 2),
      comentario: 'Flamencos chilenos en la laguna al amanecer.',
    ),
    FotoPublica(
      id: 'mock-2',
      url: '$_urlBase/10-spheniscus-magellanicus/image.jpg',
      categoria: 'Marinas',
      autor: 'pedro.pajaros',
      lugar: 'Isla Martillo',
      fecha: '2026-08-30',
      subidaEn: DateTime.utc(2026, 8, 30),
      comentario: 'Colonia de pingüinos de Magallanes en la playa.',
    ),
  ];

  final List<FotoPublica> _fotos;
  int _contador = _semilla.length;
  @override
  Future<PaginaFotos> getFotos({
    required String categoria,
    int pagina = 0,
    int porPagina = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final filtradas = categoria == 'Todas' || categoria.isEmpty
        ? _fotos
        : _fotos.where((foto) => foto.categoria == categoria).toList();
    final inicio = pagina * porPagina;
    final fin = (inicio + porPagina).clamp(0, filtradas.length);
    return PaginaFotos(
      fotos: inicio >= filtradas.length
          ? const []
          : filtradas.sublist(inicio, fin),
      pagina: pagina,
      total: filtradas.isEmpty ? 1 : ((filtradas.length - 1) ~/ porPagina) + 1,
    );
  }

  @override
  Future<FotoPublica> subirFoto({
    required List<int> bytes,
    required String nombreArchivo,
    required String contentType,
    required String categoria,
    String? lugar,
    String? fecha,
    String? comentario,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _contador += 1;
    final foto = FotoPublica(
      id: 'mock-subida-$_contador',
      url: '$_urlBase/74-buteo-polyosoma/image.jpg',
      categoria: categoria.isEmpty ? 'Otras' : categoria,
      autor: 'tu.usuario',
      lugar: lugar,
      fecha: fecha,
      subidaEn: DateTime.now(),
      comentario: comentario,
    );
    _fotos.insert(0, foto);
    return foto;
  }

  @override
  Future<void> reportarFoto({
    required String id,
    required String motivo,
    String? detalle,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final existe = _fotos.any((foto) => foto.id == id);
    if (!existe) {
      throw ApiExceptionMock(
        statusCode: 404,
        message: 'La fotografía reportada no existe.',
      );
    }
  }
}

class ApiExceptionMock implements Exception {
  ApiExceptionMock({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
