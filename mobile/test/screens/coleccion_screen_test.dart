import 'package:bitacora_aves/models/avistamiento_propio.dart';
import 'package:bitacora_aves/models/filtro_coleccion.dart';
import 'package:bitacora_aves/models/foto_guardada.dart';
import 'package:bitacora_aves/screens/coleccion_screen.dart';
import 'package:bitacora_aves/theme/app_theme.dart';

import '../ayuda/google_fonts_test_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FotoGuardada _foto(String nombre) => FotoGuardada(
  id: nombre,
  nombre: nombre,
  categoria: 'Accipitriformes',
  nombreCientifico: '',
  descripcion: '',
  rutaImagen: '/tmp/$nombre.png',
  urlImagen: 'https://ejemplo/$nombre.jpg',
  urlFicha: null,
);

AvistamientoPropio _avistamiento(String nombreAve) => AvistamientoPropio(
  nombreAve: nombreAve,
  nombreCientifico: '',
  categoria: '',
  lugar: 'Santiago',
  fecha: DateTime(2026, 5, 1),
  comentario: '',
  rutaImagen: '/tmp/$nombreAve.png',
);

Future<void> _pantalla(
  WidgetTester tester, {
  FiltroColeccion filtro = const FiltroColeccion(),
  List<FotoGuardada> fotos = const [],
  List<AvistamientoPropio> avistamientos = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(),
      home: Scaffold(
        body: ColeccionScreen(
          cargando: false,
          error: null,
          fotosGuardadas: fotos,
          avistamientosPropios: avistamientos,
          avesCargadas: const [],
          filtro: filtro,
          onReintentarCarga: () {},
          onFiltroChanged: (_) {},
          onQuitarAvistamiento: (_) async => true,
          onAvistamientoQuitado: (_) {},
          onQuitarFoto: (_) async => true,
          onFotoQuitada: (_) {},
          onReportarAvistamiento: (_) {},
          onReportarFoto: (_) {},
          onAbrirFicha: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Colección de ejemplo: dos aves guardadas (Rapaces) y un avistamiento sin
/// categoría explícita.
({
  List<FotoGuardada> fotos,
  List<AvistamientoPropio> avistamientos,
})
_coleccionEjemplo() => (
  fotos: [_foto('Águila Morada'), _foto('Garza Real')],
  avistamientos: [_avistamiento('Pato Corto')],
);

void main() {
  setUpAll(prepararGoogleFontsParaTests);

  testWidgets('sin filtros activos solo muestra el botón Filtrar', (
    tester,
  ) async {
    final ejemplo = _coleccionEjemplo();
    await _pantalla(
      tester,
      fotos: ejemplo.fotos,
      avistamientos: ejemplo.avistamientos,
    );

    expect(find.text('Filtrar'), findsOneWidget);
    expect(find.textContaining('Filtrar ('), findsNothing);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('el botón cuenta los ejes activos y muestra chips-resumen', (
    tester,
  ) async {
    final ejemplo = _coleccionEjemplo();
    await _pantalla(
      tester,
      filtro: const FiltroColeccion(categoria: 'Rapaces', busqueda: 'aguila'),
      fotos: ejemplo.fotos,
      avistamientos: ejemplo.avistamientos,
    );

    expect(find.text('Filtrar (2)'), findsOneWidget);
    expect(find.text('Rapaces'), findsOneWidget);
    expect(find.text('“aguila”'), findsOneWidget);
    // El tipo está en su valor por defecto, así que no aparece.
    expect(find.text('Todo'), findsNothing);
  });

  testWidgets('la ✕ de un chip-resumen limpia solo ese eje', (tester) async {
    var filtroAplicado = const FiltroColeccion(categoria: 'Rapaces');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ColeccionScreen(
              cargando: false,
              error: null,
              fotosGuardadas: [_foto('Águila Morada')],
              avistamientosPropios: const [],
              avesCargadas: const [],
              filtro: filtroAplicado,
              onReintentarCarga: () {},
              onFiltroChanged: (filtro) =>
                  setState(() => filtroAplicado = filtro),
              onQuitarAvistamiento: (_) async => true,
              onAvistamientoQuitado: (_) {},
              onQuitarFoto: (_) async => true,
              onFotoQuitada: (_) {},
              onReportarAvistamiento: (_) {},
              onReportarFoto: (_) {},
              onAbrirFicha: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filtrar (1)'), findsOneWidget);
    expect(find.text('Rapaces'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(filtroAplicado.esPorDefecto, isTrue);
    expect(find.text('Filtrar (1)'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('abre la hoja de filtros al tocar Filtrar', (tester) async {
    final ejemplo = _coleccionEjemplo();
    await _pantalla(
      tester,
      fotos: ejemplo.fotos,
      avistamientos: ejemplo.avistamientos,
    );

    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrar colección'), findsOneWidget);
    // La hoja cuenta también los avistamientos sin categoría explícita.
    expect(find.text('Sin clasificar (1)'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío cuando no hay nada guardado', (
    tester,
  ) async {
    await _pantalla(tester);

    expect(find.text('Tu colección está vacía'), findsOneWidget);
  });
}
