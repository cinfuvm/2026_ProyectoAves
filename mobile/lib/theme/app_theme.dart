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
      fondoGradiente: Gradient.lerp(
        fondoGradiente,
        other.fondoGradiente,
        t,
      )!,
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

    final colorScheme = ColorScheme.fromSeed(
      seedColor: esOscuro ? const Color(0xFFC69BFF) : PaletaAves.morado,
      brightness: brillo,
      primary: esOscuro ? const Color(0xFFD1B2FF) : PaletaAves.morado,
      secondary: PaletaAves.amarillo,
      surface: esOscuro ? const Color(0xFF1D1726) : const Color(0xFFFFFCFF),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: esOscuro
          ? const Color(0xFF15111C)
          : PaletaAves.fondo,
    );

    // Voz de la marca: Fraunces (serif con carácter) para títulos,
    // Roboto para cuerpo y controles.
    final roboto = _mapearTexto(base.textTheme, (estilo) {
      return GoogleFonts.roboto(textStyle: estilo);
    });
    final fraunces = _mapearTexto(roboto, (estilo) {
      return GoogleFonts.fraunces(textStyle: estilo);
    });
    final textTheme = fraunces.copyWith(
      bodyLarge: roboto.bodyLarge,
      bodyMedium: roboto.bodyMedium,
      bodySmall: roboto.bodySmall,
      labelLarge: roboto.labelLarge,
      labelMedium: roboto.labelMedium,
      labelSmall: roboto.labelSmall,
    );

    final borde = esOscuro
        ? const Color(0xFF51415F)
        : const Color(0xFFE5D8F5);
    final relleno = esOscuro ? const Color(0xFF241D2E) : Colors.white;

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        MarcaAves(
          tituloCard: esOscuro
              ? const Color(0xFFE3D1FF)
              : PaletaAves.morado,
          textoCientifico: esOscuro
              ? const Color(0xFFB8AFC1)
              : const Color(0xFF766A83),
          textoCuerpo: esOscuro
              ? const Color(0xFFE5DFEB)
              : const Color(0xFF403A48),
          textoSecundario: esOscuro
              ? const Color(0xFFB8AFC1)
              : const Color(0xFF6E6379),
          chipFondo: esOscuro ? const Color(0xFF2B2335) : Colors.white,
          chipBorde: borde,
          chipTexto: esOscuro ? const Color(0xFFE3D1FF) : PaletaAves.morado,
          placeholder: esOscuro ? const Color(0xFF30263A) : PaletaAves.lavanda,
          iconoMarca: esOscuro ? const Color(0xFFC69BFF) : PaletaAves.violeta,
          fondoGradiente: LinearGradient(
            colors: esOscuro
                ? const [
                    Color(0xFF1E1728),
                    Color(0xFF15111C),
                    Color(0xFF211A2B),
                  ]
                : const [
                    Color(0xFFFFFCFF),
                    PaletaAves.fondo,
                    Color(0xFFFFF9E7),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          barraGradiente: LinearGradient(
            colors: esOscuro
                ? const [Color(0xFF342245), Color(0xFF21182D)]
                : const [PaletaAves.morado, Color(0xFF43206F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          cabeceraGradiente: const LinearGradient(
            colors: [PaletaAves.morado, PaletaAves.violeta],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
      appBarTheme: AppBarTheme(
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: relleno,
        elevation: 5,
        shadowColor: esOscuro
            ? Colors.black.withValues(alpha: 0.25)
            : PaletaAves.morado.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
            color: esOscuro ? const Color(0xFFD1B2FF) : PaletaAves.morado,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: PaletaAves.amarillo,
        labelTextStyle: WidgetStateProperty.resolveWith((estados) {
          final seleccionado = estados.contains(WidgetState.selected);
          return GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            color: seleccionado
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((estados) {
          final seleccionado = estados.contains(WidgetState.selected);
          return IconThemeData(
            size: seleccionado ? 26 : 24,
            color: seleccionado
                ? PaletaAves.morado
                : Colors.white.withValues(alpha: 0.72),
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
