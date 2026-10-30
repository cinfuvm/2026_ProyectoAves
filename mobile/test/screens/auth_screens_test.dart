import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitacora_aves/screens/login_screen.dart';
import 'package:bitacora_aves/screens/registro_screen.dart';
import 'package:bitacora_aves/theme/app_theme.dart';

import '../ayuda/google_fonts_test_helper.dart';

/// Abre la pantalla como ruta encima de una base, para que `Navigator.pop`
/// del flujo de éxito tenga dónde volver y no reviente el árbol del test.
Future<void> _abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro(),
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  final context = tester.element(find.byType(Scaffold));
  Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => pantalla));
  await tester.pumpAndSettle();
}

Future<void> _escribir(
  WidgetTester tester,
  int campo,
  String valor,
) async {
  await tester.enterText(find.byType(TextFormField).at(campo), valor);
  await tester.pump();
}

void main() {
  setUpAll(prepararGoogleFontsParaTests);

  setUp(() {
    // La sesión mock se guarda en `SharedPreferences`.
    SharedPreferences.setMockInitialValues({});
  });

  group('RegistroScreen', () {
    testWidgets('pide usuario, correo, contraseña y confirmación', (
      tester,
    ) async {
      await _abrir(tester, const RegistroScreen());

      expect(find.text('Crear cuenta'), findsWidgets);
      expect(find.text('Usuario'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);

      // Enviar vacío no avanza: cada campo explica lo que falta.
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu usuario'), findsOneWidget);
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa una contraseña'), findsOneWidget);
      expect(find.text('Repite la contraseña'), findsOneWidget);
      expect(find.byType(RegistroScreen), findsOneWidget);
    });

    testWidgets('valida el formato del correo y la coincidencia de contraseñas',
      (tester) async {
        await _abrir(tester, const RegistroScreen());

        await _escribir(tester, 0, 'avesdemo');
        await _escribir(tester, 1, 'sin-arroba');
        await _escribir(tester, 2, 'secret123');
        await _escribir(tester, 3, 'secret123');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(find.text('Ingresa un correo válido'), findsOneWidget);
        expect(find.byType(RegistroScreen), findsOneWidget);

        await _escribir(tester, 1, 'avesdemo@ejemplo.cl');
        await _escribir(tester, 3, 'distinta123');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
        expect(find.byType(RegistroScreen), findsOneWidget);
      },
    );

    testWidgets('un registro válido crea la sesión y cierra la pantalla', (
      tester,
    ) async {
      await _abrir(tester, const RegistroScreen());

      await _escribir(tester, 0, 'avesdemo');
      await _escribir(tester, 1, 'avesdemo@ejemplo.cl');
      await _escribir(tester, 2, 'secret123');
      await _escribir(tester, 3, 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistroScreen), findsNothing);
    });
  });

  group('LoginScreen', () {
    testWidgets('el login es con correo y contraseña, no con usuario', (
      tester,
    ) async {
      await _abrir(tester, const LoginScreen());

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Usuario'), findsNothing);
    });

    testWidgets('rechaza un correo inválido antes de enviar', (tester) async {
      await _abrir(tester, const LoginScreen());

      await _escribir(tester, 0, 'avesdemo');
      await _escribir(tester, 1, 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('con correo válido entra en modo mock y cierra la pantalla', (
      tester,
    ) async {
      await _abrir(tester, const LoginScreen());

      await _escribir(tester, 0, 'avesdemo@ejemplo.cl');
      await _escribir(tester, 1, 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
