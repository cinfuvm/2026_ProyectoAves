import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ave_catalogo.dart';
import '../models/categoria_ave.dart';

/// Acceso al catálogo de aves de Chile publicado en uvm.neocities.org.
class CatalogoAvesService {
  /// Cantidad de fichas que se solicitan en paralelo por lote.
  static const solicitudesCatalogoPorLote = 12;

  static const _urlBaseAves = 'https://uvm.neocities.org/aves/';
  static const _urlBaseDatosAves = '${_urlBaseAves}fixtures/';

  /// Descarga el índice del catálogo y devuelve sus entradas.
  Future<List<EntradaCatalogo>> cargarIndice() async {
    final uriIndice = Uri.parse('${_urlBaseDatosAves}index.json');
    final respuestaIndice = await http
        .get(uriIndice)
        .timeout(const Duration(seconds: 15));
    if (respuestaIndice.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Aves de Chile respondió con estado ${respuestaIndice.statusCode}.',
        uri: uriIndice,
      );
    }

    final jsonIndice = jsonDecode(utf8.decode(respuestaIndice.bodyBytes));
    if (jsonIndice is! List<dynamic>) {
      throw const FormatException(
        'El índice de Aves de Chile no tiene un formato válido.',
      );
    }

    return jsonIndice.map((entrada) {
      if (entrada is! Map<String, dynamic>) {
        throw const FormatException(
          'El índice contiene una ficha de ave no válida.',
        );
      }
      return EntradaCatalogo.fromJson(entrada);
    }).toList();
  }

  /// Descarga la ficha completa asociada a una entrada del índice.
  Future<AveCatalogo> cargarFicha(EntradaCatalogo entrada) async {
    final uriFicha = Uri.parse(_urlBaseDatosAves).resolve(entrada.uriDatos);
    final respuesta = await http
        .get(uriFicha)
        .timeout(const Duration(seconds: 15));
    if (respuesta.statusCode != HttpStatus.ok) {
      throw HttpException(
        'La ficha de ${entrada.nombre} respondió con estado '
        '${respuesta.statusCode}.',
        uri: uriFicha,
      );
    }

    final jsonFicha = jsonDecode(utf8.decode(respuesta.bodyBytes));
    if (jsonFicha is! Map<String, dynamic>) {
      throw FormatException('La ficha de ${entrada.nombre} no es válida.');
    }
    final nombres = jsonFicha['names'];
    final acercaDe = jsonFicha['about'];
    final informacion = jsonFicha['info'];
    final multimedia = jsonFicha['media'];
    if (nombres is! Map<String, dynamic> ||
        acercaDe is! Map<String, dynamic> ||
        informacion is! Map<String, dynamic> ||
        multimedia is! Map<String, dynamic>) {
      throw FormatException(
        'La ficha de ${entrada.nombre} no contiene sus datos requeridos.',
      );
    }

    final nombre = nombres['es'];
    final nombreCientifico = nombres['la'];
    final categoria = informacion['order'];
    final imagenCompleta = multimedia['image'];
    if (nombre is! String ||
        nombre.trim().isEmpty ||
        nombreCientifico is! String ||
        nombreCientifico.trim().isEmpty ||
        categoria is! String ||
        categoria.trim().isEmpty ||
        imagenCompleta is! String ||
        !_esNombreArchivoAves(imagenCompleta)) {
      throw FormatException(
        'La ficha de ${entrada.nombre} contiene datos incompletos.',
      );
    }

    final descripcion = acercaDe['description'];
    final imagenMiniatura = multimedia['thumb'];
    final miniatura =
        imagenMiniatura is String && _esNombreArchivoAves(imagenMiniatura)
        ? imagenMiniatura
        : entrada.miniatura;

    return AveCatalogo(
      uid: entrada.uid,
      nombre: nombre.trim(),
      categoria: categoriaGeneralAves(categoria),
      nombreCientifico: nombreCientifico.trim(),
      descripcion: descripcion is String ? descripcion.trim() : '',
      palabrasClave: entrada.palabrasClave,
      urlImagen: urlImagenAve(entrada.uid, miniatura),
      urlImagenCompleta: urlImagenAve(entrada.uid, imagenCompleta),
      urlFicha: urlFichaAve(entrada.uid),
    );
  }

  /// URL de la ficha pública de una ave en Aves de Chile.
  String urlFichaAve(String uid) {
    final base = Uri.parse(_urlBaseAves);
    return base
        .replace(path: '${base.path}bird.html', queryParameters: {'id': uid})
        .toString();
  }

  /// URL de una imagen del catálogo para el [uid] indicado.
  String urlImagenAve(String uid, String nombreArchivo) {
    return Uri.parse(_urlBaseDatosAves)
        .resolve('$uid/$nombreArchivo')
        .toString();
  }

  bool _esNombreArchivoAves(String nombreArchivo) {
    return RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(nombreArchivo);
  }
}
