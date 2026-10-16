import 'dart:io';

class ApiConfig {
  static const String _urlBffDefecto = 'http://10.0.2.2:4000';

  static String get urlBase {
    const desdeEntorno = String.fromEnvironment('BFF_URL');
    if (desdeEntorno.isNotEmpty) return desdeEntorno;
    if (Platform.isAndroid) return _urlBffDefecto;
    return 'http://127.0.0.1:4000';
  }

  static const bool _mockForzado = bool.fromEnvironment('MOCK_BFF');
  // Por defecto la app corre en mock (sesión local y fotos de ejemplo), así un
  // `flutter run` a secas funciona sin ningún servidor. Cuando exista el BFF,
  // se enciende con `--dart-define=BFF_ACTIVO=true`.
  static const bool _bffActivo = bool.fromEnvironment(
    'BFF_ACTIVO',
    defaultValue: false,
  );

  /// `MOCK_BFF=true` fuerza el mock aunque `BFF_ACTIVO=true`.
  static bool get usarMock => _mockForzado || !_bffActivo;

  static const Duration tiempoLimite = Duration(seconds: 15);
}
