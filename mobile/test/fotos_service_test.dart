import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_aves/models/foto_publica.dart';
import 'package:bitacora_aves/models/reporte_moderacion.dart';
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

  group('ReporteModeracion', () {
    test('fromJson lee el contrato de GET /images/reports', () {
      final reporte = ReporteModeracion.fromJson({
        'id': 'r1',
        'motivo': 'no_es_ave',
        'detalle': 'Es un perro',
        'estado': 'abierto',
        'creado_en': '2026-10-08T09:15:00Z',
        'reportado_por': 'ana.aves',
        'avistamiento': {
          'id': 'f1',
          'url': 'https://ejemplo.cl/f1.jpg',
          'categoria': 'Rapaces',
          'autor': 'juan.observador',
          'lugar': 'Valle de Elqui',
          'comentario': 'Cóndor al atardecer',
        },
      });

      expect(reporte.id, 'r1');
      expect(reporte.motivo, 'no_es_ave');
      expect(reporte.estado, 'abierto');
      expect(reporte.abierto, isTrue);
      expect(reporte.reportadoPor, 'ana.aves');
      expect(reporte.creadoEn, isNotNull);
      expect(reporte.avistamiento?.categoria, 'Rapaces');
      expect(reporte.avistamiento?.autor, 'juan.observador');
      expect(reporte.detalle, 'Es un perro');
    });

    test('tolera la foto borrada y un motivo desconocido', () {
      final reporte = ReporteModeracion.fromJson({
        'id': 'r2',
        'motivo': 'codigo_inventado',
        'estado': 'revisado',
        'avistamiento': null,
        'reportado_por': null,
      });

      expect(reporte.avistamiento, isNull);
      expect(reporte.reportadoPor, isNull);
      expect(reporte.abierto, isFalse);
      // Sin motivo en la tabla se muestra el código, no se rompe la pantalla.
      expect(motivoLegible('codigo_inventado'), 'codigo_inventado');
    });

    test('motivoLegible traduce los códigos del contrato', () {
      expect(motivoLegible('no_es_ave'), 'La foto no muestra un ave');
      expect(
        motivoLegible('imagen_enganosa'),
        'La imagen o información es engañosa',
      );
      expect(estadosReporte.values, containsAll(<String>[
        'abierto',
        'revisado',
        'descartado',
      ]));
    });
  });

  group('Reportes en FotosServiceMock', () {
    late FotosServiceMock servicio;

    setUp(() {
      servicio = FotosServiceMock();
    });

    test('sin filtro devuelve todos, del más reciente al más antiguo',
        () async {
      final reportes = await servicio.getReportes();
      expect(reportes.length, greaterThanOrEqualTo(3));
      for (var i = 1; i < reportes.length; i++) {
        expect(
          reportes[i - 1].creadoEn!.isAfter(reportes[i].creadoEn!),
          isTrue,
        );
      }
    });

    test('filtra por estado', () async {
      final abiertos = await servicio.getReportes(estado: 'abierto');
      final descartados = await servicio.getReportes(estado: 'descartado');

      expect(abiertos, isNotEmpty);
      expect(abiertos.every((r) => r.abierto), isTrue);
      expect(descartados, isNotEmpty);
      expect(descartados.every((r) => r.estado == 'descartado'), isTrue);
      expect(
        abiertos.length + descartados.length,
        lessThan((await servicio.getReportes()).length),
      );
    });

    test('cambiarEstadoReporte mueve el reporte entre filtros', () async {
      final abiertos = await servicio.getReportes(estado: 'abierto');
      final objetivo = abiertos.first;

      final cambiado = await servicio.cambiarEstadoReporte(
        id: objetivo.id,
        estado: 'revisado',
      );
      expect(cambiado.estado, 'revisado');
      expect(cambiado.id, objetivo.id);

      final abiertosDespues = await servicio.getReportes(estado: 'abierto');
      final revisados = await servicio.getReportes(estado: 'revisado');
      expect(abiertosDespues.map((r) => r.id), isNot(contains(objetivo.id)));
      expect(revisados.map((r) => r.id), contains(objetivo.id));
    });

    test('rechaza un estado que el backend no admite', () async {
      final reportes = await servicio.getReportes();
      await expectLater(
        servicio.cambiarEstadoReporte(
          id: reportes.first.id,
          estado: 'inventado',
        ),
        throwsA(
          isA<ApiExceptionMock>().having((e) => e.statusCode, 'codigo', 400),
        ),
      );
    });

    test('rechaza un reporte que no existe', () async {
      await expectLater(
        servicio.cambiarEstadoReporte(id: 'no-existe', estado: 'revisado'),
        throwsA(
          isA<ApiExceptionMock>().having((e) => e.statusCode, 'codigo', 404),
        ),
      );
    });
  });
}
