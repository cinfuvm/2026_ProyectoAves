class Usuario {
  const Usuario({required this.nombre, this.email = '', this.token});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      nombre: json['nombre'] as String? ?? 'Usuario',
      email: json['email'] as String? ?? '',
      token: json['token'] as String?,
    );
  }

  final String nombre;
  final String email;
  final String? token;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    if (email.isNotEmpty) 'email': email,
    if (token != null) 'token': token,
  };
}
