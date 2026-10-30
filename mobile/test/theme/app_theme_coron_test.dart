import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitacora_aves/theme/app_theme.dart';

import '../ayuda/google_fonts_test_helper.dart';

/// Verifica que el tema claro se ajusta a la Guía de Marca de CORON y que el
/// modo oscuro conserva su paleta morada original.
void main() {
  setUpAll(prepararGoogleFontsParaTests);
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('el tema claro usa los colores de la guía CORON', () {
    final claro = AppTheme.claro();

    expect(claro.brightness, Brightness.light);

    final esquema = claro.colorScheme;
    expect(esquema.primary, const Color(0xFFF4D7D7), reason: 'primario rosa');
    expect(esquema.onPrimary, const Color(0xFF000000), reason: 'contraste');
    expect(esquema.secondary, const Color(0xFFFFC707), reason: 'amarillo');
    expect(esquema.tertiary, const Color(0xFFCAA1E6), reason: 'lavanda');
    expect(esquema.outline, const Color(0xFFE6E6E6), reason: 'contorno');
    expect(esquema.surface, const Color(0xFFFFFFFF), reason: 'superficie');
    expect(esquema.onSurface, const Color(0xFF000000));
    expect(claro.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
  });

  test('el texto del tema claro usa Jacques Francois en tinta negra', () {
    final texto = AppTheme.claro().textTheme;

    for (final estilo in <TextStyle?>[
      texto.displayLarge,
      texto.headlineMedium,
      texto.titleLarge,
      texto.bodyMedium,
      texto.labelSmall,
    ]) {
      expect(estilo, isNotNull);
      expect(estilo!.fontFamily, contains('JacquesFrancois'));
      expect(estilo.color, const Color(0xFF000000));
    }
  });

  test('los roles de marca del modo claro salen de PaletaCoron', () {
    final marca = AppTheme.claro().extension<MarcaAves>()!;

    expect(marca.tituloCard, PaletaCoron.tinta);
    expect(marca.textoCuerpo, PaletaCoron.tinta);
    expect(marca.textoSecundario, PaletaCoron.tintaSuave);
    expect(marca.textoCientifico, PaletaCoron.lavandaProfundo);
    expect(marca.chipFondo, PaletaCoron.primario);
    expect(marca.chipBorde, PaletaCoron.contorno);
    expect(marca.chipTexto, PaletaCoron.tinta);
    expect(marca.placeholder, PaletaCoron.contorno);
    expect(marca.iconoMarca, PaletaCoron.lavandaProfundo);

    final fondo = marca.fondoGradiente as LinearGradient;
    expect(fondo.colors, const [PaletaCoron.superficie, PaletaCoron.primario]);
  });

  test('los componentes del modo claro usan la paleta CORON', () {
    final claro = AppTheme.claro();

    expect(claro.appBarTheme.backgroundColor, PaletaCoron.lavandaProfundo);
    expect(claro.appBarTheme.foregroundColor, PaletaCoron.superficie);
    expect(
      claro.appBarTheme.titleTextStyle?.fontFamily,
      contains('JacquesFrancois'),
    );

    expect(claro.cardTheme.color, PaletaCoron.primario);
    expect(claro.inputDecorationTheme.fillColor, PaletaCoron.superficie);

    final botones = claro.elevatedButtonTheme.style;
    expect(botones?.backgroundColor?.resolve({}), PaletaCoron.secundario);
    expect(botones?.foregroundColor?.resolve({}), PaletaCoron.sobrePrimario);

    expect(claro.navigationBarTheme.indicatorColor, PaletaCoron.secundario);
    expect(claro.navigationRailTheme.indicatorColor, PaletaCoron.secundario);
  });

  test('el modo oscuro conserva su paleta y su tipografía', () {
    final oscuro = AppTheme.oscuro();

    expect(oscuro.brightness, Brightness.dark);
    expect(oscuro.colorScheme.primary, const Color(0xFFD1B2FF));
    expect(oscuro.colorScheme.surface, const Color(0xFF1D1726));
    expect(oscuro.scaffoldBackgroundColor, const Color(0xFF15111C));

    expect(oscuro.textTheme.titleLarge?.fontFamily, contains('Fraunces'));
    expect(oscuro.textTheme.bodyMedium?.fontFamily, contains('Roboto'));
    expect(oscuro.textTheme.labelLarge?.fontFamily, contains('Roboto'));

    final marca = oscuro.extension<MarcaAves>()!;
    expect(marca.tituloCard, const Color(0xFFE3D1FF));
    expect(marca.chipFondo, const Color(0xFF2B2335));

    // El modo oscuro no recibe los estilos CORON reservados al claro.
    expect(oscuro.appBarTheme.backgroundColor, isNull);
    expect(
      oscuro.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
      isNot(PaletaCoron.secundario),
    );
    expect(oscuro.navigationBarTheme.indicatorColor, PaletaAves.amarillo);
    expect(
      oscuro.navigationRailTheme.indicatorColor,
      isNot(PaletaCoron.secundario),
    );
  });
}
