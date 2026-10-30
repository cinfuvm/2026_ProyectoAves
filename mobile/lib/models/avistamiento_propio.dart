import 'categoria_ave.dart';

/// Formatea una fecha como `dd/MM/aaaa`.
String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Datos del formulario para registrar un avistamiento.
class DatosAvistamiento {
  const DatosAvistamiento({
    required this.nombreAve,
    required this.nombreCientifico,
    required this.categoria,
    required this.lugar,
    required this.fecha,
    required this.comentario,
  });

  final String nombreAve;
  final String nombreCientifico;
  final String categoria;
  final String lugar;
  final DateTime fecha;
  final String comentario;
}

/// Avistamiento guardado en el dispositivo.
class AvistamientoPropio {
  const AvistamientoPropio({
    required this.nombreAve,
    required this.nombreCientifico,
    required this.categoria,
    required this.lugar,
    required this.fecha,
    required this.comentario,
    required this.rutaImagen,
  });

  factory AvistamientoPropio.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en el avistamiento.');
      }
      return dato;
    }

    String valorOpcional(String clave) {
      final dato = json[clave];
      return dato is String ? dato : '';
    }

    return AvistamientoPropio(
      nombreAve: json['nombreAve'] as String? ?? 'Ave sin identificar',
      nombreCientifico: valorOpcional('nombreCientifico'),
      categoria: categoriaGeneralAves(valorOpcional('categoria')),
      lugar: valor('lugar'),
      fecha: DateTime.parse(valor('fecha')),
      comentario: valor('comentario'),
      rutaImagen: valor('rutaImagen'),
    );
  }

  final String nombreAve;
  final String nombreCientifico;
  final String categoria;
  final String lugar;
  final DateTime fecha;
  final String comentario;
  final String rutaImagen;

  Map<String, String> toJson() => {
    'nombreAve': nombreAve,
    'nombreCientifico': nombreCientifico,
    'categoria': categoria,
    'lugar': lugar,
    'fecha': fecha.toIso8601String(),
    'comentario': comentario,
    'rutaImagen': rutaImagen,
  };
}
