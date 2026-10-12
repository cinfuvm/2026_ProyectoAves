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
    required String email,
    required String password,
  }) async {
    if (ApiConfig.usarMock) {
      return _iniciarSesionMock(email: email, password: password);
    }
    return _iniciarSesionBff(user: email.trim(), password: password);
  }

  Future<Usuario> _iniciarSesionMock({
    required String email,
    required String password,
  }) async {
    final emailNormalizado = email.trim().toLowerCase();
    if (!emailNormalizado.contains('@') || !emailNormalizado.contains('.')) {
      throw const FormatException('Ingresa un correo válido.');
    }
    if (password.trim().length < 4) {
      throw const FormatException(
        'La contraseña debe tener al menos 4 caracteres.',
      );
    }

    final nombre = emailNormalizado.split('@').first;
    final usuario = Usuario(
      nombre: nombre.isEmpty ? 'Usuario' : nombre,
      email: emailNormalizado,
      token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    await _guardarSesion(usuario);
    return usuario;
  }

  Future<Usuario> _iniciarSesionBff({
    required String user,
    required String password,
  }) async {
    final cliente = ApiClient();
    try {
      final respuesta = await cliente.postJson('/api/user/login', {
        'email': user.trim(),
        'password': password,
      });
      final sesion = _parsearSesion(respuesta.bodyBytes, user);
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
    required String password,
    required String confirmacion,
  }) async {
    if (ApiConfig.usarMock) {
      return _iniciarSesionMock(email: user, password: password);
    }
    final cliente = ApiClient();
    try {
      final correo = user.trim();
      final nickname = correo.contains('@') ? correo.split('@').first : correo;
      final respuesta = await cliente.postJson('/api/user/signin', {
        'email': correo,
        'nickname': nickname,
        'password': password,
        'confirm_password': confirmacion,
      });
      final sesion = _parsearSesion(respuesta.bodyBytes, user);
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
    String email = user;
    String nombre = user;
    if (usuarioCrudo is Map<String, dynamic>) {
      email = (usuarioCrudo['email'] as String?) ?? user;
      final nickname = usuarioCrudo['nickname'] as String?;
      nombre = (nickname != null && nickname.isNotEmpty) ? nickname : email;
    } else if (usuarioCrudo is String && usuarioCrudo.isNotEmpty) {
      nombre = usuarioCrudo;
    }
    return Usuario(nombre: nombre, email: email, token: token);
  }

  Usuario _usuarioDesdeMe(List<int> cuerpo, String? token) {
    final json = jsonDecode(utf8.decode(cuerpo));
    final datos = json is Map<String, dynamic> ? json['user'] : null;
    if (datos is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de usuario no válida.');
    }
    final email = (datos['email'] as String?) ?? '';
    final nickname = datos['nickname'] as String?;
    return Usuario(
      nombre: (nickname != null && nickname.isNotEmpty) ? nickname : email,
      email: email,
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
