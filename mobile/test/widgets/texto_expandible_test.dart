import 'package:bitacora_aves/widgets/texto_expandible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expande y contrae textos que superan tres líneas', (
    tester,
  ) async {
    const texto =
        'Primera línea con detalles de la observación. '
        'Segunda línea con más información sobre el ave. '
        'Tercera línea y una descripción adicional bastante extensa '
        'para requerir que se pueda expandir el contenido completo.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 220, child: TextoExpandible(texto: texto)),
        ),
      ),
    );

    expect(find.text('Ver más'), findsOneWidget);
    final textoContraido = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data == texto && widget.maxLines == 3,
      ),
    );
    expect(textoContraido.maxLines, 3);

    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();

    expect(find.text('Ver menos'), findsOneWidget);
    final textoExpandido = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data == texto && widget.maxLines == null,
      ),
    );
    expect(textoExpandido.maxLines, isNull);

    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();

    expect(find.text('Ver más'), findsOneWidget);
  });

  testWidgets('no muestra expansión cuando el texto cabe', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: TextoExpandible(texto: 'Descripción breve.'),
          ),
        ),
      ),
    );

    expect(find.text('Descripción breve.'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing);
  });
}
