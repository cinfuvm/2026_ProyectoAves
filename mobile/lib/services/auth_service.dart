import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/usuario.dart';
import 'api_client.dart';

class AuthService {
  static const _claveSesion = 'session_usuario_v1';

  Future<Usuario?> obtenerSesion() async {
    final local = await _sesionLocal();
    if (local == null) return null;
    if (ApiConfig.usarMock) return local;
    final token = local.token;
    if (token == null || token.isEmpty) return local;
    return _verificarSesion(local);
  }

  /// Consulta `GET /api/user/me` con el token guardado.
  /// - 401/403: la sesión ya no es válida, se limpia localmente.
  /// - Sin conexión u otro error: se conserva la sesión en caché.
  Future<Usuario?> _verificarSesion(Usuario local) async {
    final cliente = ApiClient(token: local.token);
    try {
      final respuesta = await cliente.get('/api/user/me');
      final usuario = _usuarioDesdeMe(respuesta.bodyBytes, local.token);
      await _guardarSesion(usuario);
      return usuario;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _borrarSesionLocal();
        return null;
      }
      return local;
    } catch (_) {
      return local;
    } finally {
      cliente.cerrar();
    }
  }

  Future<Usuario?> _sesionLocal() async {
    final preferencias = await SharedPreferences.getInstance();
    final json = preferencias.getString(_claveSesion);
    if (json == null) return null;
    try {
      final datos = jsonDecode(json);
      if (datos is Map<String, dynamic>) return Usuario.fromJson(datos);
    } on FormatException {
      await preferencias.remove(_claveSesion);
    }
    return null;
  }

  Future<void> _borrarSesionLocal() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveSesion);
  }

  Future<String?> obtenerToken() async {
    final sesion = await obtenerSesion();
    return sesion?.token;
  }

  Future<Usuario> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    if (ApiConfig.usarMock) {
      return _iniciarSesionMock(correo: correo, password: password);
    }
    return _iniciarSesionBff(email: correo.trim(), password: password);
  }

  Future<Usuario> _iniciarSesionMock({
    required String correo,
    required String password,
  }) async {
    // El mock no tiene registro de usuarios: al entrar con el correo, ese
    // correo es el identificador que se muestra en el perfil.
    final identificador = correo.trim().toLowerCase();
    if (!_esCorreo(identificador)) {
      throw const FormatException('Ingresa un correo válido.');
    }
    return _guardarSesionMock(identificador: identificador, password: password);
  }

  Future<Usuario> _registrarseMock({
    required String user,
    required String email,
    required String password,
  }) async {
    final nombreUsuario = user.trim();
    // El backend admite de 3 a 30 caracteres (ver `Aves.Accounts.User`).
    if (nombreUsuario.length < 3 || nombreUsuario.length > 30) {
      throw const FormatException(
        'El usuario debe tener entre 3 y 30 caracteres.',
      );
    }
    final identificador = email.trim().toLowerCase();
    if (!_esCorreo(identificador)) {
      throw const FormatException('Ingresa un correo válido.');
    }
    // Al registrarse se conserva el usuario elegido, que es el identificador
    // público; el correo queda como forma de volver a entrar.
    return _guardarSesionMock(identificador: nombreUsuario, password: password);
  }

  Future<Usuario> _guardarSesionMock({
    required String identificador,
    required String password,
  }) async {
    if (password.trim().length < 4) {
      throw const FormatException(
        'La contraseña debe tener al menos 4 caracteres.',
      );
    }

    final sesion = Usuario(
      nombre: identificador,
      user: identificador,
      // El mock no tiene roles. Se devuelve `admin` para que se pueda abrir la
      // pantalla de moderación sin backend, que en mock se llena con datos de
      // ejemplo de `FotosServiceMock`.
      rol: 'admin',
      token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    await _guardarSesion(sesion);
    return sesion;
  }

  static final RegExp _patronCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _esCorreo(String valor) => _patronCorreo.hasMatch(valor);

  Future<Usuario> _iniciarSesionBff({
    required String email,
    required String password,
  }) async {
    final cliente = ApiClient();
    try {
      final respuesta = await cliente.postJson('/api/user/login', {
        'email': email,
        'password': password,
      });
      final sesion = _parsearSesion(respuesta.bodyBytes, email);
      await _guardarSesion(sesion);
      return sesion;
    } on ApiException catch (error) {
      throw FormatException(error.toString());
    } finally {
      cliente.cerrar();
    }
  }

  Future<Usuario> registrarse({
    required String user,
    required String email,
    required String password,
    required String confirmacion,
  }) async {
    if (ApiConfig.usarMock) {
      return _registrarseMock(
        user: user,
        email: email,
        password: password,
      );
    }
    final cliente = ApiClient();
    try {
      final respuesta = await cliente.postJson('/api/user/signin', {
        'user': user.trim(),
        'email': email.trim(),
        'password': password,
        'confirm_password': confirmacion,
      });
      final sesion = _parsearSesion(respuesta.bodyBytes, user.trim());
      await _guardarSesion(sesion);
      return sesion;
    } on ApiException catch (error) {
      throw FormatException(error.toString());
    } finally {
      cliente.cerrar();
    }
  }

  Usuario _parsearSesion(List<int> cuerpo, String user) {
    final json = jsonDecode(utf8.decode(cuerpo));
    Map<String, dynamic> sesion;
    if (json is Map<String, dynamic>) {
      final data = json['data'];
      sesion = data is Map<String, dynamic> ? data : json;
    } else {
      throw const FormatException('Respuesta de sesión no válida.');
    }
    final token = sesion['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('El servidor no devolvió un token.');
    }
    final usuarioCrudo = sesion['user'];
    // `user` puede venir como string (identificador) o como objeto con los
    // datos del usuario dentro.
    String identificador = user.trim();
    String nombre = identificador;
    String rol = '';
    if (usuarioCrudo is Map<String, dynamic>) {
      final delServidor = (usuarioCrudo['user'] as String?) ?? '';
      if (delServidor.isNotEmpty) identificador = delServidor;
      nombre = identificador;
      rol = (usuarioCrudo['rol'] as String?) ?? '';
    } else if (usuarioCrudo is String && usuarioCrudo.isNotEmpty) {
      nombre = usuarioCrudo;
      identificador = usuarioCrudo;
    }
    return Usuario(
      nombre: nombre,
      user: identificador,
      rol: rol,
      token: token,
    );
  }

  Usuario _usuarioDesdeMe(List<int> cuerpo, String? token) {
    final json = jsonDecode(utf8.decode(cuerpo));
    final datos = json is Map<String, dynamic> ? json['user'] : null;
    if (datos is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de usuario no válida.');
    }
    final user = (datos['user'] as String?) ?? '';
    return Usuario(
      nombre: user.isEmpty ? 'Usuario' : user,
      user: user,
      rol: (datos['rol'] as String?) ?? '',
      token: token,
    );
  }

  Future<void> _guardarSesion(Usuario usuario) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_claveSesion, jsonEncode(usuario.toJson()));
  }

  Future<void> cerrarSesion() async {
    final sesion = await _sesionLocal();
    final token = sesion?.token;
    if (!ApiConfig.usarMock && token != null && token.isNotEmpty) {
      try {
        final cliente = ApiClient(token: token);
        try {
          await cliente.delete('/api/user/logout');
        } finally {
          cliente.cerrar();
        }
      } catch (_) {
        // Sin conexión o token ya inválido: la sesión local se cierra igual.
      }
    }
    await _borrarSesionLocal();
  }
}
