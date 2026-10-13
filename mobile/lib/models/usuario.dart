class Usuario {
  const Usuario({required this.nombre, this.user = '', this.token});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      nombre: json['nombre'] as String? ?? 'Usuario',
      user: json['user'] as String? ?? '',
      token: json['token'] as String?,
    );
  }

  /// Identificador público, tal y como lo manda el backend en el campo `user`.
  final String user;

  /// Nombre visible. Se rellena con `user` porque ya no hay un apodo aparte.
  final String nombre;
  final String? token;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    if (user.isNotEmpty) 'user': user,
    if (token != null) 'token': token,
  };
}
