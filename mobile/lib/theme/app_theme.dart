import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta base de la marca. Valores fijos compartidos por modo claro y oscuro.
abstract final class PaletaAves {
  static const morado = Color(0xFF5B2D91);
  static const violeta = Color(0xFF8B5CC7);
  static const lavanda = Color(0xFFF2EAFB);
  static const amarillo = Color(0xFFFFD447);
  static const amarilloClaro = Color(0xFFFFE88A);
  static const fondo = Color(0xFFFBF8FF);
}

/// Guía de Marca de CORON. Manda en el tema claro; el modo oscuro conserva
/// [PaletaAves] tal como estaba.
abstract final class PaletaCoron {
  // --- Colores oficiales de la guía ---

  /// Primario: rosa suave.
  static const primario = Color(0xFFF4D7D7);

  /// Contraste sobre primario: negro.
  static const sobrePrimario = Color(0xFF000000);

  /// Secundario (acentos / botones): amarillo / dorado.
  static const secundario = Color(0xFFFFC707);

  /// Terciario (acentos secundarios): púrpura / lavanda.
  static const terciario = Color(0xFFCAA1E6);

  /// Bordes / líneas: gris claro.
  static const contorno = Color(0xFFE6E6E6);

  /// Superficie / fondo general: blanco.
  static const superficie = Color(0xFFFFFFFF);

  // --- Derivados accesibles (misma familia, ajustados a contraste AA) ---
  // Solo se usan donde la guía no da un color con contraste suficiente:
  // texto secundario, iconos, focos y las barras que llevan texto blanco
  // encima (el blanco sobre rosa/lavanda claros baja a 1.3:1).

  /// Tinta de texto por defecto en modo claro.
  static const tinta = sobrePrimario;

  /// Texto secundario: negro al 60 % (5.7:1 sobre blanco).
  static const tintaSuave = Color(0x99000000);

  /// Terciario oscurecido: 5.3:1 con texto blanco y 3.9:1 sobre el rosa.
  static const lavandaProfundo = Color(0xFF7A5FA0);

  /// Base oscura de las barras: 7.7:1 con texto blanco.
  static const lavandaSombra = Color(0xFF5B3E80);

  /// Primario oscurecido: 5.7:1 con texto blanco (final de la cabecera).
  static const rosaSombra = Color(0xFF96525F);
}

/// Roles de color que dependen del brillo del tema. Se leen con `context.marca`.
@immutable
class MarcaAves extends ThemeExtension<MarcaAves> {
  const MarcaAves({
    required this.tituloCard,
    required this.textoCientifico,
    required this.textoCuerpo,
    required this.textoSecundario,
    required this.chipFondo,
    required this.chipBorde,
    required this.chipTexto,
    required this.placeholder,
    required this.iconoMarca,
    required this.fondoGradiente,
    required this.barraGradiente,
    required this.cabeceraGradiente,
  });

  /// Color de los nombres de ave y títulos dentro de tarjetas.
  final Color tituloCard;

  /// Nombre científico en itálica.
  final Color textoCientifico;

  /// Cuerpo de las descripciones.
  final Color textoCuerpo;

  /// Texto secundario pequeño (metadatos, notas al pie), siempre tinteado.
  final Color textoSecundario;

  /// Fondo y borde de los chips de categoría/filtro.
  final Color chipFondo;
  final Color chipBorde;
  final Color chipTexto;

  /// Fondo de imágenes en carga o con error.
  final Color placeholder;

  /// Iconos de marca sobre el fondo de la app (vacíos, filtros, estados).
  final Color iconoMarca;

  /// Gradiente del cuerpo de la app.
  final Gradient fondoGradiente;

  /// Gradiente de AppBar y barra de navegación.
  final Gradient barraGradiente;

  /// Gradiente de la cabecera destacada del catálogo.
  final Gradient cabeceraGradiente;

  @override
  MarcaAves copyWith({
    Color? tituloCard,
    Color? textoCientifico,
    Color? textoCuerpo,
    Color? textoSecundario,
    Color? chipFondo,
    Color? chipBorde,
    Color? chipTexto,
    Color? placeholder,
    Color? iconoMarca,
    Gradient? fondoGradiente,
    Gradient? barraGradiente,
    Gradient? cabeceraGradiente,
  }) {
    return MarcaAves(
      tituloCard: tituloCard ?? this.tituloCard,
      textoCientifico: textoCientifico ?? this.textoCientifico,
      textoCuerpo: textoCuerpo ?? this.textoCuerpo,
      textoSecundario: textoSecundario ?? this.textoSecundario,
      chipFondo: chipFondo ?? this.chipFondo,
      chipBorde: chipBorde ?? this.chipBorde,
      chipTexto: chipTexto ?? this.chipTexto,
      placeholder: placeholder ?? this.placeholder,
      iconoMarca: iconoMarca ?? this.iconoMarca,
      fondoGradiente: fondoGradiente ?? this.fondoGradiente,
      barraGradiente: barraGradiente ?? this.barraGradiente,
      cabeceraGradiente: cabeceraGradiente ?? this.cabeceraGradiente,
    );
  }

  @override
  MarcaAves lerp(covariant MarcaAves? other, double t) {
    if (other == null) return this;
    return MarcaAves(
      tituloCard: Color.lerp(tituloCard, other.tituloCard, t)!,
      textoCientifico: Color.lerp(textoCientifico, other.textoCientifico, t)!,
      textoCuerpo: Color.lerp(textoCuerpo, other.textoCuerpo, t)!,
      textoSecundario: Color.lerp(textoSecundario, other.textoSecundario, t)!,
      chipFondo: Color.lerp(chipFondo, other.chipFondo, t)!,
      chipBorde: Color.lerp(chipBorde, other.chipBorde, t)!,
      chipTexto: Color.lerp(chipTexto, other.chipTexto, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      iconoMarca: Color.lerp(iconoMarca, other.iconoMarca, t)!,
      fondoGradiente: Gradient.lerp(fondoGradiente, other.fondoGradiente, t)!,
      barraGradiente: Gradient.lerp(barraGradiente, other.barraGradiente, t)!,
      cabeceraGradiente: Gradient.lerp(
        cabeceraGradiente,
        other.cabeceraGradiente,
        t,
      )!,
    );
  }
}

extension MarcaSobreContext on BuildContext {
  MarcaAves get marca => Theme.of(this).extension<MarcaAves>()!;
}

/// Duración sensible a "Eliminar animaciones" del sistema.
Duration duracion(BuildContext contexto, int milisegundos) {
  if (MediaQuery.disableAnimationsOf(contexto)) return Duration.zero;
  return Duration(milliseconds: milisegundos);
}

/// Borde redondeado fino usado por las tarjetas de aves, con contraste
/// según el tema activo.
ShapeBorder formaTarjetaAve(BuildContext context) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return RoundedRectangleBorder(
    side: BorderSide(
      color: esOscuro
          ? const Color(0xFFC69BFF).withValues(alpha: 0.62)
          : PaletaAves.violeta.withValues(alpha: 0.5),
      width: 1.2,
    ),
    borderRadius: BorderRadius.circular(24),
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  /// Se aplica [aplicar] a cada rol del TextTheme sin alterar tamaño ni peso.
  static TextTheme _mapearTexto(
    TextTheme base,
    TextStyle? Function(TextStyle?) aplicar,
  ) {
    TextStyle? f(TextStyle? estilo) => aplicar(estilo);
    return TextTheme(
      displayLarge: f(base.displayLarge),
      displayMedium: f(base.displayMedium),
      displaySmall: f(base.displaySmall),
      headlineLarge: f(base.headlineLarge),
      headlineMedium: f(base.headlineMedium),
      headlineSmall: f(base.headlineSmall),
      titleLarge: f(base.titleLarge),
      titleMedium: f(base.titleMedium),
      titleSmall: f(base.titleSmall),
      bodyLarge: f(base.bodyLarge),
      bodyMedium: f(base.bodyMedium),
      bodySmall: f(base.bodySmall),
      labelLarge: f(base.labelLarge),
      labelMedium: f(base.labelMedium),
      labelSmall: f(base.labelSmall),
    );
  }

  static ThemeData _construir(Brightness brillo) {
    final esOscuro = brillo == Brightness.dark;

    // ColorScheme: en claro manda la Guía de Marca de CORON (rosa primario,
    // negro como contraste, amarillo de acento, lavanda terciaria, gris de
    // contorno y superficie blanca); el oscuro conserva su paleta morada.
    final colorScheme = esOscuro
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFFC69BFF),
            brightness: brillo,
            primary: const Color(0xFFD1B2FF),
            secondary: PaletaAves.amarillo,
            surface: const Color(0xFF1D1726),
          )
        : ColorScheme.fromSeed(
            seedColor: PaletaCoron.primario,
            brightness: brillo,
            primary: PaletaCoron.primario,
            onPrimary: PaletaCoron.sobrePrimario,
            secondary: PaletaCoron.secundario,
            onSecondary: PaletaCoron.sobrePrimario,
            tertiary: PaletaCoron.terciario,
            onTertiary: PaletaCoron.sobrePrimario,
            outline: PaletaCoron.contorno,
            surface: PaletaCoron.superficie,
            onSurface: PaletaCoron.sobrePrimario,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: esOscuro
          ? const Color(0xFF15111C)
          : PaletaCoron.superficie,
    );

    // Voz de la marca: en claro, Jacques Francois en todo el TextTheme con
    // tinta negra (#000000); en oscuro se conserva Fraunces (títulos) y
    // Roboto (cuerpo y controles).
    final TextTheme textTheme;
    if (esOscuro) {
      final roboto = _mapearTexto(base.textTheme, (estilo) {
        return GoogleFonts.roboto(textStyle: estilo);
      });
      final fraunces = _mapearTexto(roboto, (estilo) {
        return GoogleFonts.fraunces(textStyle: estilo);
      });
      textTheme = fraunces.copyWith(
        bodyLarge: roboto.bodyLarge,
        bodyMedium: roboto.bodyMedium,
        bodySmall: roboto.bodySmall,
        labelLarge: roboto.labelLarge,
        labelMedium: roboto.labelMedium,
        labelSmall: roboto.labelSmall,
      );
    } else {
      // Nota: `GoogleFonts.jacquesFrancoisTextTheme()` devuelve el `TextTheme`
      // del paquete `material_ui` (dependencia de google_fonts 9), que no es
      // el de Flutter; por eso se recorren los estilos uno a uno con el
      // helper [_mapearTexto], igual que en el modo oscuro.
      textTheme =
          _mapearTexto(base.textTheme, (estilo) {
            return GoogleFonts.jacquesFrancois(textStyle: estilo);
          }).apply(
            displayColor: PaletaCoron.sobrePrimario,
            bodyColor: PaletaCoron.sobrePrimario,
          );
    }

    final borde = esOscuro ? const Color(0xFF51415F) : PaletaCoron.contorno;
    final relleno = esOscuro ? const Color(0xFF241D2E) : PaletaCoron.superficie;

    // Tarjetas destacadas: en claro, el rosa primario de la guía.
    final tarjeta = esOscuro ? const Color(0xFF241D2E) : PaletaCoron.primario;

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        MarcaAves(
          tituloCard: esOscuro ? const Color(0xFFE3D1FF) : PaletaCoron.tinta,
          textoCientifico: esOscuro
              ? const Color(0xFFB8AFC1)
              : PaletaCoron.lavandaProfundo,
          textoCuerpo: esOscuro ? const Color(0xFFE5DFEB) : PaletaCoron.tinta,
          textoSecundario: esOscuro
              ? const Color(0xFFB8AFC1)
              : PaletaCoron.tintaSuave,
          chipFondo: esOscuro ? const Color(0xFF2B2335) : PaletaCoron.primario,
          chipBorde: borde,
          chipTexto: esOscuro ? const Color(0xFFE3D1FF) : PaletaCoron.tinta,
          placeholder: esOscuro
              ? const Color(0xFF30263A)
              : PaletaCoron.contorno,
          iconoMarca: esOscuro
              ? const Color(0xFFC69BFF)
              : PaletaCoron.lavandaProfundo,
          fondoGradiente: LinearGradient(
            colors: esOscuro
                ? const [
                    Color(0xFF1E1728),
                    Color(0xFF15111C),
                    Color(0xFF211A2B),
                  ]
                : const [PaletaCoron.superficie, PaletaCoron.primario],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          barraGradiente: LinearGradient(
            colors: esOscuro
                ? const [Color(0xFF342245), Color(0xFF21182D)]
                : const [
                    PaletaCoron.lavandaProfundo,
                    PaletaCoron.lavandaSombra,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          cabeceraGradiente: LinearGradient(
            colors: esOscuro
                ? const [PaletaAves.morado, PaletaAves.violeta]
                : const [PaletaCoron.lavandaProfundo, PaletaCoron.rosaSombra],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
      appBarTheme: AppBarTheme(
        // En claro, fondo lavanda profundo: las pantallas pintan texto blanco
        // sobre el AppBar y este tono (5.3:1) es el único de la familia CORON
        // que lo mantiene legible; el rosa claro quedaría a 1.3:1.
        backgroundColor: esOscuro ? null : PaletaCoron.lavandaProfundo,
        foregroundColor: PaletaCoron.superficie,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: esOscuro
            ? GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              )
            : GoogleFonts.jacquesFrancois(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: PaletaCoron.superficie,
                letterSpacing: -0.2,
              ),
      ),
      cardTheme: CardThemeData(
        color: tarjeta,
        elevation: 5,
        shadowColor: esOscuro
            ? Colors.black.withValues(alpha: 0.25)
            : PaletaCoron.lavandaProfundo.withValues(alpha: 0.20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: relleno,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            // Lavanda profundo (5.3:1): el terciario claro no llega al 3:1
            // mínimo que pide un indicador de foco sobre blanco.
            color: esOscuro
                ? const Color(0xFFD1B2FF)
                : PaletaCoron.lavandaProfundo,
            width: 1.5,
          ),
        ),
      ),
      // Solo en claro: el amarillo/dorado de la guía como botón de acento,
      // con tinta negra (13.5:1). En oscuro mantiene el estilo por defecto.
      elevatedButtonTheme: esOscuro
          ? null
          : ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: PaletaCoron.secundario,
                foregroundColor: PaletaCoron.sobrePrimario,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
      // Acciones secundarias (TextButton): el primario rosa es demasiado
      // claro sobre la superficie blanca, así que se usa el lavanda profundo.
      textButtonTheme: esOscuro
          ? null
          : TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: PaletaCoron.lavandaProfundo,
              ),
            ),
      outlinedButtonTheme: esOscuro
          ? null
          : OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: PaletaCoron.lavandaProfundo,
                side: const BorderSide(color: PaletaCoron.lavandaProfundo),
              ),
            ),
      progressIndicatorTheme: esOscuro
          ? null
          : ProgressIndicatorThemeData(color: PaletaCoron.lavandaProfundo),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: esOscuro ? PaletaAves.amarillo : PaletaCoron.secundario,
        labelTextStyle: WidgetStateProperty.resolveWith((estados) {
          final seleccionado = estados.contains(WidgetState.selected);
          final color = seleccionado
              ? Colors.white
              : Colors.white.withValues(alpha: 0.72);
          final peso = seleccionado ? FontWeight.w700 : FontWeight.w500;
          return esOscuro
              ? GoogleFonts.roboto(fontSize: 12, fontWeight: peso, color: color)
              : GoogleFonts.jacquesFrancois(
                  fontSize: 12,
                  fontWeight: peso,
                  color: color,
                );
        }),
        iconTheme: WidgetStateProperty.resolveWith((estados) {
          final seleccionado = estados.contains(WidgetState.selected);
          return IconThemeData(
            size: seleccionado ? 26 : 24,
            color: seleccionado
                ? (esOscuro ? PaletaAves.morado : PaletaCoron.sobrePrimario)
                : Colors.white.withValues(alpha: 0.72),
          );
        }),
      ),
      // En claro, el carril lateral se apoya en `barraGradiente` (lavanda
      // profundo): etiquetas e iconos en blanco para que se lean igual que
      // en la barra de navegación inferior.
      navigationRailTheme: esOscuro
          ? null
          : NavigationRailThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: PaletaCoron.secundario,
              selectedIconTheme: const IconThemeData(
                color: PaletaCoron.sobrePrimario,
              ),
              unselectedIconTheme: IconThemeData(
                color: Colors.white.withValues(alpha: 0.72),
              ),
              selectedLabelTextStyle: GoogleFonts.jacquesFrancois(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              unselectedLabelTextStyle: GoogleFonts.jacquesFrancois(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
