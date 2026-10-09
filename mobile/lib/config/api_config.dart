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
  static const bool _bffForzado = bool.fromEnvironment('BFF_ACTIVO');

  static bool get usarMock => !_bffForzado || _mockForzado;

  static const Duration tiempoLimite = Duration(seconds: 15);
}
