import '../config/api_config.dart';
import '../models/foto_publica.dart';
import '../models/reporte_moderacion.dart';
import 'fotos_service_bff.dart';
import 'fotos_service_mock.dart';

const motivosReporteContrato = <String, String>{
  'La foto no muestra un ave': 'no_es_ave',
  'Contenido inapropiado': 'contenido_ofensivo',
  'La imagen o información es engañosa': 'imagen_enganosa',
  'Imagen duplicada o de baja calidad': 'derechos_autor',
  'Otro motivo': 'otro',
};

/// Texto legible para un código de motivo del contrato (`no_es_ave`, ...).
/// Si llega un código que no está en la tabla, se devuelve tal cual en vez de
/// romper la pantalla.
String motivoLegible(String codigo) {
  for (final entrada in motivosReporteContrato.entries) {
    if (entrada.value == codigo) return entrada.key;
  }
  return codigo;
}

/// Estados en los que puede estar un reporte, en el orden en que los pinta la
/// pantalla de moderación. El primero es el filtro por defecto.
const estadosReporte = <String, String>{
  'Abiertos': 'abierto',
  'Revisados': 'revisado',
  'Descartados': 'descartado',
};

abstract class FotosService {
  factory FotosService() =>
      ApiConfig.usarMock ? FotosServiceMock() : FotosServiceBff();

  Future<PaginaFotos> getFotos({
    required String categoria,
    int pagina = 0,
    int porPagina = 20,
  });

  Future<FotoPublica> subirFoto({
    required List<int> bytes,
    required String nombreArchivo,
    required String contentType,
    required String categoria,
    String? lugar,
    String? fecha,
    String? comentario,
  });

  Future<void> reportarFoto({
    required String id,
    required String motivo,
    String? detalle,
  });

  /// Reportes de moderación con su foto, del más reciente al más antiguo.
  ///
  /// [estado] vacío o `null` devuelve todos; si no, uno de los valores de
  /// `estadosReporte`. Reservado a `admin` en el backend.
  Future<List<ReporteModeracion>> getReportes({String? estado});

  /// Mueve un reporte a `revisado`, `descartado` o `abierto`. Solo `admin`.
  Future<ReporteModeracion> cambiarEstadoReporte({
    required String id,
    required String estado,
  });
}
