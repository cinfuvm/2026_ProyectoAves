import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/usuario.dart';
import 'api_client.dart';

class AuthService {
  static const _claveSesion = 'session_usuario_v1';

  Future<Usuario?> obtenerSesion() async {
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
      final respuesta = await cliente.postJson('/user/login', {
        'user': user,
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
      final respuesta = await cliente.postJson('/user/signin', {
        'user': user.trim(),
        'password': password,
        'confirm_pasword': confirmacion,
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
    final nombre = sesion['user'] as String? ?? user;
    if (token == null || token.isEmpty) {
      throw const FormatException('El servidor no devolvió un token.');
    }
    return Usuario(nombre: nombre, email: user, token: token);
  }

  Future<void> _guardarSesion(Usuario usuario) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_claveSesion, jsonEncode(usuario.toJson()));
  }

  Future<void> cerrarSesion() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveSesion);
  }
}
