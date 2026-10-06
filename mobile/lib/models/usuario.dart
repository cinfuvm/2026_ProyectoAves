class Usuario {
  const Usuario({required this.nombre, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      nombre: json['nombre'] as String? ?? 'Usuario',
      email: json['email'] as String? ?? '',
    );
  }

  final String nombre;
  final String email;

  Map<String, String> toJson() => {'nombre': nombre, 'email': email};
}
