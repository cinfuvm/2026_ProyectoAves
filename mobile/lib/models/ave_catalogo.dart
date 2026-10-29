/// Entrada mínima del índice del catálogo de aves de Chile.
class EntradaCatalogo {
  const EntradaCatalogo({
    required this.uid,
    required this.uriDatos,
    required this.nombre,
    required this.nombreCientifico,
    required this.palabrasClave,
    required this.miniatura,
    required this.imagen,
  });

  factory EntradaCatalogo.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    final uriDatos = json['uri'];
    final palabrasClave = json['keywords'];
    final miniatura = json['thumb'];
    final imagen = json['image'];
    final nombres = json['names'];
    if (uid is! String ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(uid) ||
        uriDatos is! String ||
        palabrasClave is! String ||
        miniatura is! String ||
        imagen is! String ||
        nombres is! Map<String, dynamic>) {
      throw const FormatException(
        'Una entrada del catálogo contiene campos inválidos.',
      );
    }

    final referenciaDatos = Uri.parse(uriDatos);
    final segmentosUri = referenciaDatos.pathSegments;
    final nombre = nombres['es'];
    final nombreCientifico = nombres['la'];
    if (nombre is! String ||
        nombre.trim().isEmpty ||
        nombreCientifico is! String ||
        nombreCientifico.trim().isEmpty ||
        segmentosUri.length != 2 ||
        segmentosUri.first != uid ||
        segmentosUri.last != 'data.json' ||
        referenciaDatos.hasScheme ||
        referenciaDatos.hasAuthority ||
        referenciaDatos.hasQuery ||
        referenciaDatos.hasFragment ||
        referenciaDatos.path.startsWith('/') ||
        !_esNombreArchivoCatalogo(miniatura) ||
        !_esNombreArchivoCatalogo(imagen)) {
      throw FormatException('La entrada de catálogo "$uid" está incompleta.');
    }

    return EntradaCatalogo(
      uid: uid,
      uriDatos: uriDatos,
      nombre: nombre.trim(),
      nombreCientifico: nombreCientifico.trim(),
      palabrasClave: palabrasClave,
      miniatura: miniatura,
      imagen: imagen,
    );
  }

  final String uid;
  final String uriDatos;
  final String nombre;
  final String nombreCientifico;
  final String palabrasClave;
  final String miniatura;
  final String imagen;

  static bool _esNombreArchivoCatalogo(String valor) =>
      RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(valor);
}

/// Ficha de un ave del catálogo de Aves de Chile.
class AveCatalogo {
  const AveCatalogo({
    required this.uid,
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.palabrasClave,
    required this.urlImagen,
    required this.urlImagenCompleta,
    required this.urlFicha,
  });

  final String uid;
  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String palabrasClave;
  final String urlImagen;
  final String urlImagenCompleta;
  final String urlFicha;
}
