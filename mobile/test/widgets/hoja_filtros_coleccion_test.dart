import 'package:bitacora_aves/models/avistamiento_propio.dart';
import 'package:bitacora_aves/models/categoria_ave.dart';
import 'package:bitacora_aves/models/filtro_coleccion.dart';
import 'package:bitacora_aves/models/foto_guardada.dart';
import 'package:bitacora_aves/theme/app_theme.dart';
import 'package:bitacora_aves/widgets/hoja_filtros_coleccion.dart';

import '../ayuda/google_fonts_test_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FotoGuardada _foto(String nombre, String categoria) => FotoGuardada(
  id: nombre,
  nombre: nombre,
  categoria: categoria,
  nombreCientifico: '',
  descripcion: '',
  rutaImagen: '/tmp/$nombre.png',
  urlImagen: 'https://ejemplo/$nombre.jpg',
  urlFicha: null,
);

AplicadorFiltrosColeccion _aplicador() => AplicadorFiltrosColeccion(
  fotos: [
    _foto('Águila Morada', 'Accipitriformes'),
    _foto('Garza Real', 'Humedal'),
  ],
  avistamientos: [
    AvistamientoPropio(
      nombreAve: 'Pato Corto',
      nombreCientifico: '',
      categoria: 'Anseriformes',
      lugar: 'Valparaíso',
      fecha: DateTime(2026, 5, 1),
      comentario: '',
      rutaImagen: '/tmp/pato.png',
    ),
  ],
  categoriaDeAvistamiento: (avistamiento) {
    final categoria = avistamiento.categoria.trim();
    return categoria.isEmpty
        ? 'Sin clasificar'
        : categoriaGeneralAves(categoria);
  },
);

/// Bomba la app de prueba y abre la hoja de filtros con la colección de
/// arriba. Los filtros emitidos por `onFiltroChanged` quedan en [emitidos].
Future<void> _abrirHoja(WidgetTester tester, List<FiltroColeccion> emitidos) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // El tema por defecto no trae `MarcaAves` y `context.marca` haría un `!`
      // sobre null.
      theme: AppTheme.claro(),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => mostrarHojaFiltrosColeccion(
              context,
              filtro: const FiltroColeccion(),
              aplicador: _aplicador(),
              onFiltroChanged: emitidos.add,
            ),
            child: const Text('Abrir filtros'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir filtros'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(prepararGoogleFontsParaTests);

  testWidgets('muestra el conteo de cada opción y el total de resultados', (
    tester,
  ) async {
    await _abrirHoja(tester, <FiltroColeccion>[]);

    expect(find.text('Filtrar colección'), findsOneWidget);
    // Tipo: 2 guardadas + 1 avistamiento = 3 en «Todo».
    expect(find.text('Todo (3)'), findsOneWidget);
    expect(find.text('Aves guardadas (2)'), findsOneWidget);
    expect(find.text('Mis avistamientos (1)'), findsOneWidget);
    // Categorías: Águila → Rapaces; Garza y Pato → Acuáticas.
    expect(find.text('Rapaces (1)'), findsOneWidget);
    expect(find.text('Acuáticas (2)'), findsOneWidget);
    expect(find.text('Ver 3 resultados'), findsOneWidget);
    expect(find.text('Limpiar'), findsOneWidget);
  });

  testWidgets('«Limpiar» está deshabilitado mientras no haya filtros', (
    tester,
  ) async {
    await _abrirHoja(tester, <FiltroColeccion>[]);

    final limpiar = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Limpiar'),
    );
    expect(limpiar.onPressed, isNull);
  });

  testWidgets('elegir una categoría actualiza el total mostrado en vivo', (
    tester,
  ) async {
    final emitidos = <FiltroColeccion>[];
    await _abrirHoja(tester, emitidos);

    await tester.tap(find.text('Rapaces (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Ver 1 resultado'), findsOneWidget);
    expect(emitidos.last.categoria, 'Rapaces');
  });

  testWidgets('la búsqueda se aplica al escribir y «Limpiar» la borra', (
    tester,
  ) async {
    final emitidos = <FiltroColeccion>[];
    await _abrirHoja(tester, emitidos);

    await tester.enterText(find.byType(TextField), 'aguila');
    await tester.pumpAndSettle();

    // Solo la Águila coincide, y es una guardada.
    expect(find.text('Ver 1 resultado'), findsOneWidget);
    expect(emitidos.last.busqueda, 'aguila');
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();

    expect(find.text('Ver 3 resultados'), findsOneWidget);
    expect(emitidos.last.esPorDefecto, isTrue);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('el botón del pie cierra la hoja', (tester) async {
    await _abrirHoja(tester, <FiltroColeccion>[]);

    await tester.tap(find.text('Ver 3 resultados'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrar colección'), findsNothing);
  });
}
