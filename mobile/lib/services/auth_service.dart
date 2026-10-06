import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

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

  Future<Usuario> iniciarSesion({
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
    );
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_claveSesion, jsonEncode(usuario.toJson()));
    return usuario;
  }

  Future<void> cerrarSesion() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveSesion);
  }
}
