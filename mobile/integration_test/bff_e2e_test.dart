import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:bitacora_aves/config/api_config.dart';
import 'package:bitacora_aves/main.dart' as app;
import 'package:bitacora_aves/screens/reportes_screen.dart';
import 'package:bitacora_aves/services/auth_service.dart';
import 'package:bitacora_aves/services/fotos_service_bff.dart';

/// Prueba end-to-end de la app contra el BFF, corriendo en el dispositivo
/// real (emulador o celular), usando el cliente HTTP y los parsers reales.
///
/// No se usa `pumpAndSettle` porque se queda corto mientras la app tenga un
/// `CircularProgressIndicator` girando; se avanza a pulsos acotados.
Future<void> _cargar(WidgetTester tester, {int pulsos = 25}) async {
  for (var i = 0; i < pulsos; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Si el BFF no está levantado, la prueba se salta en lugar de fallar: el
/// objetivo es comprobar el flujo, no exigir un entorno.
Future<bool> _saltarSiNoHayBff() async {
  try {
    await http
        .get(Uri.parse(ApiConfig.urlBase))
        .timeout(const Duration(seconds: 4));
    return false;
  } on Exception {
    markTestSkipped(
      'BFF no alcanzable en ${ApiConfig.urlBase}. '
      'Arráncalo con scripts\\bff.ps1 (y el mock con '
      'dart scripts\\mock_backend.dart).',
    );
    return true;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BFF end-to-end', () {
    testWidgets('login por la UI real deja la sesión del BFF', (tester) async {
      if (await _saltarSiNoHayBff()) return;

      app.main();
      await _cargar(tester);

      await tester.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Perfil'),
            )
            .first,
      );
      await _cargar(tester, pulsos: 15);

      await tester.tap(find.text('Iniciar sesión'));
      await _cargar(tester, pulsos: 15);

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'emulador');
      await tester.enterText(campos.at(1), 'secret123');
      await tester.tap(find.text('Entrar'));
      await _cargar(tester, pulsos: 30);

      // El backend real devuelve el usuario con el que se entró.
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('emulador'), findsOneWidget);
    });

    test('colección, subida multipart y reporte', () async {
      if (await _saltarSiNoHayBff()) return;

      // Categoría propia de la prueba: así el catálogo no depende de lo que
      // haya subido otra persona, y la foto recién subida se puede buscar.
      const categoria = 'AveE2E';

      final usuario = await AuthService().iniciarSesion(
        usuario: 'emulador',
        password: 'secret123',
      );
      expect(usuario.user, equals('emulador'));
      expect(usuario.token, isNotEmpty);

      final servicio = FotosServiceBff();

      // Subida: POST /images en multipart. Si el BFF re-serializara el
      // cuerpo, el boundary se rompería y el backend no leería el archivo.
      final foto = await servicio.subirFoto(
        bytes: [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(2048, 0x00)],
        nombreArchivo: 'ave.jpg',
        contentType: 'image/jpeg',
        categoria: categoria,
        lugar: 'Santiago',
        fecha: '2026-10-12',
        comentario: 'Prueba end-to-end contra el BFF',
      );
      expect(foto.id, isNotEmpty);
      expect(foto.url, isNotEmpty);
      expect(foto.categoria, categoria);

      // La URL pública tiene que ser descargable desde el propio dispositivo:
      // por eso el backend la construye con la IP de la red local y no con
      // `127.0.0.1`, que en el Android emulator apuntaría al propio emulador.
      final descarga = await http
          .get(Uri.parse(foto.url))
          .timeout(const Duration(seconds: 10));
      expect(descarga.statusCode, 200);
      expect(descarga.bodyBytes, isNotEmpty);

      // Colección: GET /images con query. El backend ordena por subida
      // descendente, así que la foto recién subida va en la primera página.
      final pagina = await servicio.getFotos(
        categoria: categoria,
        pagina: 0,
        porPagina: 3,
      );
      expect(pagina.fotos, isNotEmpty);
      expect(pagina.pagina, 0);
      expect(pagina.fotos.map((f) => f.id), contains(foto.id));

      // Reporte: PUT /images?id=...
      await expectLater(
        servicio.reportarFoto(
          id: foto.id,
          motivo: 'no_es_ave',
          detalle: 'Es un perro',
        ),
        completes,
      );
    });

    test('moderación: lista los reportes y mueve su estado', () async {
      if (await _saltarSiNoHayBff()) return;

      final servicio = FotosServiceBff();

      // Solo el rol `admin` puede verlos, y `emulador` lo es por los seeds.
      // Si el rol no llegara (se comió en el BFF), esto daría 403.
      final abiertos = await servicio.getReportes(estado: 'abierto');
      expect(abiertos, isNotEmpty);

      final objetivo = abiertos.first;
      expect(objetivo.avistamiento, isNotNull);
      expect(objetivo.avistamiento!.id, isNotEmpty);
      expect(objetivo.reportadoPor, isNotEmpty);
      expect(objetivo.detalle, 'Es un perro');

      final movido = await servicio.cambiarEstadoReporte(
        id: objetivo.id,
        estado: 'revisado',
      );
      expect(movido.estado, 'revisado');

      // El filtro tiene que reflejar el cambio en las dos direcciones.
      final revisados = await servicio.getReportes(estado: 'revisado');
      expect(revisados.map((r) => r.id), contains(objetivo.id));
      final abiertosDespues = await servicio.getReportes(estado: 'abierto');
      expect(abiertosDespues.map((r) => r.id), isNot(contains(objetivo.id)));
    });

    testWidgets('un admin abre la moderación desde el perfil', (tester) async {
      if (await _saltarSiNoHayBff()) return;

      // Cada `testWidgets` empieza con el árbol vacío: hay que lanzar la app.
      // La sesión de `emulador` quedó abierta en el primer test, así que aquí
      // solo hace falta navegar al perfil.
      app.main();
      await _cargar(tester, pulsos: 40);

      await tester.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Perfil'),
            )
            .first,
      );

      // El perfil revalida la sesión contra el BFF al montarse, así que se
      // espera a que termine de decidir si está dentro o fuera.
      var resuelto = false;
      for (var i = 0; i < 50; i++) {
        if (find.text('Cerrar sesión').evaluate().isNotEmpty ||
            find.text('Iniciar sesión').evaluate().isNotEmpty) {
          resuelto = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 120));
      }
      if (!resuelto) {
        final vistas = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .whereType<String>()
            .take(30)
            .join(' | ');
        fail('El perfil no mostró ningún estado. En pantalla: $vistas');
      }

      if (find.text('Cerrar sesión').evaluate().isEmpty) {
        markTestSkipped('No hay sesión abierta: faltó el test de login.');
        return;
      }

      final entrada = find.text('Reportes de moderación');
      expect(entrada, findsOneWidget);

      await tester.tap(entrada);
      await _cargar(tester, pulsos: 40);

      expect(find.byType(ReportesScreen), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Abiertos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
