import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_aves/screens/reportes_screen.dart';
import 'package:bitacora_aves/services/fotos_service_mock.dart';
import 'package:bitacora_aves/theme/app_theme.dart';

import '../ayuda/google_fonts_test_helper.dart';

/// El mock tarda 350 ms en «red» y 300 ms en «escribir». `pumpAndSettle` no
/// sirve aquí porque la pantalla usa un `CircularProgressIndicator` que nunca
/// acaba, así que se avanza el reloj a mano.
Future<void> _pumpHasta(WidgetTester tester, Duration espera) async {
  await tester.pump();
  await tester.pump(espera);
  await tester.pump();
}

void main() {
  setUpAll(prepararGoogleFontsParaTests);

  Future<WidgetTester> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // El tema por defecto no trae `MarcaAves` y `context.marca` haría
        // un `!` sobre null.
        theme: AppTheme.claro(),
        home: ReportesScreen(servicio: FotosServiceMock()),
      ),
    );
    await _pumpHasta(tester, const Duration(milliseconds: 500));
    return tester;
  }

  testWidgets('lista los reportes con su motivo y su estado', (tester) async {
    await abrir(tester);

    expect(find.text('Reportes de moderación'), findsOneWidget);
    // El más reciente del mock es «Contenido inapropiado».
    expect(find.text('Contenido inapropiado'), findsOneWidget);
    expect(find.text('Abierto'), findsWidgets);
    // La ficha de la foto acompaña al motivo.
    expect(find.textContaining('·'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('el filtro «Descartados» deja solo los descartados',
      (tester) async {
    await abrir(tester);

    final descartado = find.text('La foto no muestra un ave');
    expect(descartado, findsNothing);

    await tester.tap(find.text('Descartados'));
    await _pumpHasta(tester, const Duration(milliseconds: 500));

    expect(find.text('La foto no muestra un ave'), findsOneWidget);
    expect(find.text('Contenido inapropiado'), findsNothing);
    expect(find.text('Descartado'), findsOneWidget);
  });

  testWidgets('al revisar un reporte desaparece del filtro de abiertos',
      (tester) async {
    await abrir(tester);

    final abiertos = find.text('Contenido inapropiado');
    expect(abiertos, findsOneWidget);

    await tester.tap(find.text('Revisado').first);
    // 300 ms de escritura + 350 ms de recarga.
    await _pumpHasta(tester, const Duration(milliseconds: 900));

    // El movimiento se refleja: ahora está en el filtro de revisados...
    await tester.tap(find.text('Revisados'));
    await _pumpHasta(tester, const Duration(milliseconds: 500));
    expect(find.text('Contenido inapropiado'), findsOneWidget);

    // ...y ya no aparece entre los abiertos, donde sigue habiendo otro.
    await tester.tap(find.text('Abiertos'));
    await _pumpHasta(tester, const Duration(milliseconds: 500));
    expect(find.text('Contenido inapropiado'), findsNothing);
    expect(find.text('Imagen duplicada o de baja calidad'), findsOneWidget);
  });
}
