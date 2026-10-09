import '../config/api_config.dart';
import '../models/foto_publica.dart';
import 'fotos_service_bff.dart';
import 'fotos_service_mock.dart';

const motivosReporteContrato = <String, String>{
  'La foto no muestra un ave': 'no_es_ave',
  'Contenido inapropiado': 'contenido_ofensivo',
  'La imagen o información es engañosa': 'imagen_enganosa',
  'Imagen duplicada o de baja calidad': 'derechos_autor',
  'Otro motivo': 'otro',
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
}
