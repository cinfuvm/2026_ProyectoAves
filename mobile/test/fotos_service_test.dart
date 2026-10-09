import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_aves/models/foto_publica.dart';
import 'package:bitacora_aves/services/fotos_service.dart';
import 'package:bitacora_aves/services/fotos_service_mock.dart';

void main() {
  group('FotoPublica', () {
    test('fromJson con campos extendidos', () {
      final foto = FotoPublica.fromJson({
        'id': 'f1',
        'url': 'https://ejemplo.cl/foto.jpg',
        'categoria': 'rapaces',
        'autor': 'ana.aves',
        'lugar': 'Valparaíso',
        'fecha': '2026-09-01',
        'comentario': 'Sobrevolando el cerro',
        'subida_en': '2026-09-01T12:00:00Z',
      });
      expect(foto.id, 'f1');
      expect(foto.autor, 'ana.aves');
      expect(foto.lugar, 'Valparaíso');
      expect(foto.fecha, '2026-09-01');
      expect(foto.subidaEn, isNotNull);
    });

    test('fromJson tolera el contrato actual sin campos extendidos', () {
      final foto = FotoPublica.fromJson({
        'id': 'f2',
        'url': 'https://ejemplo.cl/f2.jpg',
        'categoria': 'marinas',
        'subida_en': '2026-09-02T08:30:00Z',
      });
      expect(foto.autor, isNull);
      expect(foto.lugar, isNull);
      expect(foto.comentario, isNull);
    });
  });

  group('PaginaFotos', () {
    test('acepta paginado como objeto', () {
      final pagina = PaginaFotos.fromJson({
        'urls': [
          {'id': 'a', 'url': 'https://ejemplo.cl/a.jpg'},
          'https://ejemplo.cl/b.jpg',
        ],
        'paginado': {'pagina': 0, 'total': 3},
      });
      expect(pagina.fotos, hasLength(2));
      expect(pagina.fotos[0].id, 'a');
      expect(pagina.fotos[1].url, 'https://ejemplo.cl/b.jpg');
      expect(pagina.pagina, 0);
      expect(pagina.total, 3);
      expect(pagina.hayMas, isTrue);
    });

    test('acepta paginado como cadena pagina/total', () {
      final pagina = PaginaFotos.fromJson({
        'urls': <dynamic>[],
        'paginado': '2/2',
      });
      expect(pagina.pagina, 2);
      expect(pagina.total, 2);
      expect(pagina.hayMas, isFalse);
    });
  });

  group('motivosReporteContrato', () {
    test('mapea todos los motivos de la UI al enum del contrato', () {
      expect(motivosReporteContrato, containsValue('no_es_ave'));
      expect(motivosReporteContrato, containsValue('contenido_ofensivo'));
      expect(motivosReporteContrato, containsValue('imagen_enganosa'));
      expect(motivosReporteContrato, containsValue('derechos_autor'));
      expect(motivosReporteContrato, containsValue('otro'));
    });
  });

  group('FotosServiceMock', () {
    late FotosServiceMock servicio;

    setUp(() {
      servicio = FotosServiceMock();
    });

    test('devuelve fotos de la categoría solicitada', () async {
      final pagina = await servicio.getFotos(categoria: 'Rapaces');
      expect(pagina.fotos, isNotEmpty);
      expect(pagina.fotos.every((f) => f.categoria == 'Rapaces'), isTrue);
    });

    test('devuelve todas las fotos con Todas', () async {
      final pagina = await servicio.getFotos(categoria: 'Todas');
      expect(pagina.fotos.length, greaterThanOrEqualTo(5));
    });

    test('subirFoto agrega la foto al inicio del feed', () async {
      final antes = await servicio.getFotos(categoria: 'Todas');
      final foto = await servicio.subirFoto(
        bytes: [0xFF, 0xD8, 0xFF],
        nombreArchivo: 'prueba.jpg',
        contentType: 'image/jpeg',
        categoria: 'Rapaces',
        lugar: 'Santiago',
        fecha: '2026-10-01',
        comentario: 'Aguilucho en el parque',
      );
      expect(foto.lugar, 'Santiago');
      final despues = await servicio.getFotos(categoria: 'Todas');
      expect(despues.fotos.length, antes.fotos.length + 1);
      expect(despues.fotos.first.id, foto.id);
    });

    test('reportarFoto lanza 404 si la foto no existe', () async {
      expect(
        () => servicio.reportarFoto(id: 'no-existe', motivo: 'no_es_ave'),
        throwsA(isA<ApiExceptionMock>()),
      );
    });

    test('reportarFoto acepta una foto existente', () async {
      final pagina = await servicio.getFotos(categoria: 'Todas');
      await expectLater(
        servicio.reportarFoto(
          id: pagina.fotos.first.id,
          motivo: 'no_es_ave',
          detalle: 'Es un perro',
        ),
        completes,
      );
    });
  });
}
