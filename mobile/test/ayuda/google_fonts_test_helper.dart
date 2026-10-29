import 'package:google_fonts/google_fonts.dart';

/// Evita que `GoogleFonts` salga a buscar fuentes en red durante los tests.
///
/// Sin esto, cada test que bombea `AppTheme` intenta descargar Fraunces,
/// Roboto o Jacques Francois desde fonts.gstatic.com. En el runner de tests
/// eso se convierte en una petición HTTP real que nunca termina y el test
/// muere como «did not complete» en vez de fallar con un mensaje útil.
///
/// Con el fetching desactivado, GoogleFonts usa las fuentes ya disponibles y
/// los tests se quedan en la paleta y la tipografía declaradas, que es lo que
/// estas pruebas quieren verificar.
///
/// Usarla así, en cada archivo que bombea el tema de la app:
///
/// ```dart
/// setUpAll(prepararGoogleFontsParaTests);
/// ```
void prepararGoogleFontsParaTests() {
  GoogleFonts.config.allowRuntimeFetching = false;
}
