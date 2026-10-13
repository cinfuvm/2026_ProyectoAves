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
  // La app habla con el BFF de verdad salvo que se pida lo contrario, así que
  // un `flutter run` a secas ya usa la API real.
  static const bool _bffActivo = bool.fromEnvironment(
    'BFF_ACTIVO',
    defaultValue: true,
  );

  /// `MOCK_BFF=true` fuerza el mock; `BFF_ACTIVO=false` sigue funcionando
  /// por si hay algo escrito con el valor anterior del flag.
  static bool get usarMock => _mockForzado || !_bffActivo;

  static const Duration tiempoLimite = Duration(seconds: 15);
}
