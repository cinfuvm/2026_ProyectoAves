import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avistamiento_propio.dart';
import '../models/foto_guardada.dart';
import '../models/reporte_foto.dart';

/// Contenido leído de la colección local del dispositivo.
class DatosColeccionLocal {
  const DatosColeccionLocal({
    required this.fotos,
    required this.avistamientos,
    required this.reportes,
  });

  final List<FotoGuardada> fotos;
  final List<AvistamientoPropio> avistamientos;
  final List<ReporteFoto> reportes;
}

/// Persistencia local de la colección: preferencias y archivos de imágenes.
class ColeccionLocalService {
  static const claveColeccion = 'aves_guardadas_catalogo_v1';
  static const claveColeccionAnterior = 'fotos_guardadas_wikipedia_v1';
  static const claveAvistamientos = 'avistamientos_propios_v1';
  static const claveReportes = 'reportes_fotos_pendientes_v1';

  /// Lee fotos guardadas, avistamientos y reportes del almacenamiento local.
  Future<DatosColeccionLocal> cargar() async {
    final preferencias = await SharedPreferences.getInstance();
    final guardadasJson =
        preferencias.getString(claveColeccion) ??
        preferencias.getString(claveColeccionAnterior);
    final avistamientosJson = preferencias.getString(claveAvistamientos);
    final reportesJson = preferencias.getString(claveReportes);
    final fotos = <FotoGuardada>[];
    final avistamientos = <AvistamientoPropio>[];
    final reportes = <ReporteFoto>[];

    if (guardadasJson != null) {
      final datos = jsonDecode(guardadasJson);
      if (datos is! List<dynamic>) {
        throw const FormatException('Formato de colección no válido.');
      }

      for (final dato in datos) {
        if (dato is! Map<String, dynamic>) {
          throw const FormatException('Elemento de colección no válido.');
        }
        fotos.add(FotoGuardada.fromJson(dato));
      }
    }

    if (avistamientosJson != null) {
      final datos = jsonDecode(avistamientosJson);
      if (datos is! List<dynamic>) {
        throw const FormatException('Formato de avistamientos no válido.');
      }

      for (final dato in datos) {
        if (dato is! Map<String, dynamic>) {
          throw const FormatException('Elemento de avistamiento no válido.');
        }
        avistamientos.add(AvistamientoPropio.fromJson(dato));
      }
    }

    if (reportesJson != null) {
      final datos = jsonDecode(reportesJson);
      if (datos is! List<dynamic>) {
        throw const FormatException('Formato de reportes no válido.');
      }

      for (final dato in datos) {
        if (dato is! Map<String, dynamic>) {
          throw const FormatException('Elemento de reporte no válido.');
        }
        reportes.add(ReporteFoto.fromJson(dato));
      }
    }

    return DatosColeccionLocal(
      fotos: fotos,
      avistamientos: avistamientos,
      reportes: reportes,
    );
  }

  /// Persiste las fotos guardadas. Devuelve `false` si el guardado falló.
  Future<bool> guardarFotos(List<FotoGuardada> fotos) async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.setString(
      claveColeccion,
      jsonEncode(fotos.map((foto) => foto.toJson()).toList()),
    );
  }

  /// Persiste los avistamientos propios. Devuelve `false` si el guardado
  /// falló.
  Future<bool> guardarAvistamientos(
    List<AvistamientoPropio> avistamientos,
  ) async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.setString(
      claveAvistamientos,
      jsonEncode(avistamientos.map((item) => item.toJson()).toList()),
    );
  }

  /// Persiste los reportes de fotos. Devuelve `false` si el guardado falló.
  Future<bool> guardarReportes(List<ReporteFoto> reportes) async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.setString(
      claveReportes,
      jsonEncode(reportes.map((reporte) => reporte.toJson()).toList()),
    );
  }

  /// Descarga [uri] y la escribe de forma atómica en la carpeta de la
  /// colección. Devuelve la ruta final del archivo.
  ///
  /// Lanza [FormatException] con [mensajeNoImagenValida] si la respuesta no
  /// contiene una imagen válida.
  Future<String> descargarImagenAColeccion({
    required Uri uri,
    required String idOrigen,
    required String nombreArchivoFuente,
    required String mensajeNoImagenValida,
  }) async {
    final respuesta = await http.get(uri).timeout(const Duration(seconds: 30));
    if (respuesta.statusCode != HttpStatus.ok) {
      throw HttpException(
        'La descarga de la imagen falló (${respuesta.statusCode}).',
        uri: uri,
      );
    }
    if (respuesta.bodyBytes.isEmpty ||
        !(respuesta.headers['content-type']?.startsWith('image/') ?? false)) {
      throw FormatException(mensajeNoImagenValida);
    }

    final directorioApp = await getApplicationDocumentsDirectory();
    final directorioColeccion = Directory(
      '${directorioApp.path}${Platform.pathSeparator}coleccion_aves',
    );
    await directorioColeccion.create(recursive: true);

    final extension =
        RegExp(
          r'\.(jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).firstMatch(nombreArchivoFuente)?.group(0)?.toLowerCase() ??
        '.jpg';
    final nombreSeguro = idOrigen.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final nombreArchivo =
        '${nombreSeguro}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final rutaImagen =
        '${directorioColeccion.path}${Platform.pathSeparator}$nombreArchivo';
    final archivoTemporal = File('$rutaImagen.tmp');
    await archivoTemporal.writeAsBytes(respuesta.bodyBytes, flush: true);
    await archivoTemporal.rename(rutaImagen);
    return rutaImagen;
  }

  /// Copia la imagen seleccionada en [rutaOrigen] a la carpeta de
  /// avistamientos. Devuelve la ruta del archivo copiado.
  Future<String> copiarImagenAvistamiento({
    required String rutaOrigen,
    required String nombreOrigen,
  }) async {
    final directorioApp = await getApplicationDocumentsDirectory();
    final directorioAvistamientos = Directory(
      '${directorioApp.path}${Platform.pathSeparator}avistamientos',
    );
    await directorioAvistamientos.create(recursive: true);

    final extension =
        RegExp(
          r'\.(jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).firstMatch(nombreOrigen)?.group(0)?.toLowerCase() ??
        '.jpg';
    final nombreArchivo =
        'avistamiento_${DateTime.now().microsecondsSinceEpoch}$extension';
    final rutaImagen =
        '${directorioAvistamientos.path}${Platform.pathSeparator}$nombreArchivo';
    final archivoTemporal = File('$rutaImagen.tmp');
    await File(rutaOrigen).copy(archivoTemporal.path);
    await archivoTemporal.rename(rutaImagen);
    return rutaImagen;
  }

  /// Borra el archivo en [ruta] si existe.
  Future<void> borrarArchivo(String ruta) async {
    final archivo = File(ruta);
    if (await archivo.exists()) {
      await archivo.delete();
    }
  }
}
