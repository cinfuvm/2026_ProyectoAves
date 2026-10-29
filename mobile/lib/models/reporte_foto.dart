/// Resultado del diálogo de reporte de una imagen.
class DatosReporte {
  const DatosReporte({required this.motivos, required this.detalle});

  final List<String> motivos;
  final String detalle;
}

/// Reporte de una foto registrado en el dispositivo.
class ReporteFoto {
  const ReporteFoto({
    required this.nombre,
    required this.referenciaImagen,
    required this.origen,
    required this.motivos,
    required this.detalle,
    required this.fechaCreacion,
  });

  factory ReporteFoto.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en el reporte.');
      }
      return dato;
    }

    final motivosJson = json['motivos'];
    if (motivosJson is! List<dynamic> ||
        motivosJson.any((motivo) => motivo is! String)) {
      throw const FormatException('Los motivos del reporte no son válidos.');
    }

    return ReporteFoto(
      nombre: valor('nombre'),
      referenciaImagen: valor('referenciaImagen'),
      origen: valor('origen'),
      motivos: motivosJson.cast<String>(),
      detalle: json['detalle'] as String? ?? '',
      fechaCreacion: valor('fechaCreacion'),
    );
  }

  final String nombre;
  final String referenciaImagen;
  final String origen;
  final List<String> motivos;
  final String detalle;
  final String fechaCreacion;

  Map<String, Object> toJson() => {
    'nombre': nombre,
    'referenciaImagen': referenciaImagen,
    'origen': origen,
    'motivos': motivos,
    'detalle': detalle,
    'fechaCreacion': fechaCreacion,
  };
}
