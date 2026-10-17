import 'dart:io';

import 'package:bitacora_aves/widgets/formulario_avistamiento_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imagenes;

Future<File> _crearFotoTemporal() async {
  final directorio = await Directory.systemTemp.createTemp(
    'bitacora-aves-test-',
  );
  addTearDown(() async {
    if (await directorio.exists()) {
      await directorio.delete(recursive: true);
    }
  });

  final archivo = File('${directorio.path}${Platform.pathSeparator}ave.png');
  await archivo.writeAsBytes(
    imagenes.encodePng(imagenes.Image(width: 8, height: 5)),
  );
  return archivo;
}

Future<void> _abrirFormulario(WidgetTester tester, String rutaImagen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => FormularioAvistamientoDialog(
                  rutaImagen: rutaImagen,
                  formatearFecha: (fecha) =>
                      '${fecha.day}/${fecha.month}/${fecha.year}',
                ),
              );
            },
            child: const Text('Abrir formulario'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Abrir formulario'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la foto seleccionada y pide el nombre del ave', (
    tester,
  ) async {
    final foto = await _crearFotoTemporal();
    await _abrirFormulario(tester, foto.path);

    final vistaPrevia = tester.widget<Image>(
      find.byKey(const ValueKey<String>('vista-previa-foto-avistamiento')),
    );
    expect((vistaPrevia.image as FileImage).file.path, foto.path);
    expect(find.text('Vista previa de la foto'), findsOneWidget);
    expect(find.text('Nombre del ave *'), findsOneWidget);
  });

  testWidgets('no permite guardar sin indicar el nombre del ave', (
    tester,
  ) async {
    final foto = await _crearFotoTemporal();
    await _abrirFormulario(tester, foto.path);

    await tester.tap(find.text('Guardar foto'));
    await tester.pumpAndSettle();

    expect(
      find.text('Indica el nombre del ave o escribe "Ave sin identificar".'),
      findsOneWidget,
    );
  });
}
