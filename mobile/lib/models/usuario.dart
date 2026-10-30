class Usuario {
  const Usuario({
    required this.nombre,
    this.user = '',
    this.rol = '',
    this.token,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      nombre: json['nombre'] as String? ?? 'Usuario',
      user: json['user'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      token: json['token'] as String?,
    );
  }

  /// Identificador público, tal y como lo manda el backend en el campo `user`.
  final String user;

  /// Nombre visible. Se rellena con `user` porque ya no hay un apodo aparte.
  final String nombre;

  /// `usuario`, `moderador` o `admin`. Vacío cuando el servidor no lo manda
  /// o cuando la sesión viene de caché con un formato antiguo.
  final String rol;
  final String? token;

  /// Solo `admin` puede revisar los reportes de moderación; el resto de la
  /// app no mira este campo en ningún otro sitio.
  bool get esAdmin => rol == 'admin';

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    if (user.isNotEmpty) 'user': user,
    if (rol.isNotEmpty) 'rol': rol,
    if (token != null) 'token': token,
  };
}
