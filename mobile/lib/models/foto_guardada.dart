import 'categoria_ave.dart';

/// Ave o foto de la comunidad guardada en la colección del dispositivo.
class FotoGuardada {
  const FotoGuardada({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.rutaImagen,
    required this.urlImagen,
    required this.urlFicha,
    this.esDeComunidad = false,
  });

  factory FotoGuardada.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en la colección.');
      }
      return dato;
    }

    String valorOpcional(String clave) {
      final dato = json[clave];
      return dato is String ? dato : '';
    }

    final id = json['id'];
    final urlFicha = json['urlFicha'];
    return FotoGuardada(
      id: id is String && id.isNotEmpty ? id : valor('urlArticulo'),
      nombre: valor('nombre'),
      categoria: categoriaGeneralAves(valorOpcional('categoria')),
      nombreCientifico: valorOpcional('nombreCientifico'),
      descripcion: valorOpcional('descripcion'),
      rutaImagen: valor('rutaImagen'),
      urlImagen: valor('urlImagen'),
      urlFicha: urlFicha is String && urlFicha.isNotEmpty ? urlFicha : null,
      esDeComunidad: json['esDeComunidad'] == true,
    );
  }

  final String id;
  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String rutaImagen;
  final String urlImagen;
  final String? urlFicha;
  final bool esDeComunidad;

  Map<String, Object?> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'nombreCientifico': nombreCientifico,
    'descripcion': descripcion,
    'rutaImagen': rutaImagen,
    'urlImagen': urlImagen,
    'urlFicha': urlFicha,
    if (esDeComunidad) 'esDeComunidad': true,
  };
}
