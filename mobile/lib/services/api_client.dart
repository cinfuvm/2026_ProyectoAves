import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.error = 'error',
    this.message,
  });

  final int statusCode;
  final String error;
  final String? message;

  @override
  String toString() => message ?? 'Error del servidor ($statusCode).';
}

class ApiClient {
  ApiClient({http.Client? cliente, String? urlBase, this.token})
    : _cliente = cliente ?? http.Client(),
      _urlBase = urlBase ?? ApiConfig.urlBase;

  final http.Client _cliente;
  final String _urlBase;
  String? token;

  Uri _uri(String ruta, [Map<String, String>? consulta]) {
    final uri = Uri.parse('$_urlBase$ruta');
    if (consulta == null || consulta.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...consulta});
  }

  Map<String, String> _cabeceras({Map<String, String>? extra}) {
    return {
      if (token != null && token!.isNotEmpty)
        'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Future<http.Response> get(
    String ruta, {
    Map<String, String>? consulta,
  }) async {
    final respuesta = await _cliente
        .get(_uri(ruta, consulta), headers: _cabeceras())
        .timeout(ApiConfig.tiempoLimite);
    return _verificar(respuesta);
  }

  Future<http.Response> postJson(
    String ruta,
    Map<String, dynamic> cuerpo,
  ) async {
    final respuesta = await _cliente
        .post(
          _uri(ruta),
          headers: _cabeceras(extra: {'Content-Type': 'application/json'}),
          body: jsonEncode(cuerpo),
        )
        .timeout(ApiConfig.tiempoLimite);
    return _verificar(respuesta);
  }

  Future<http.Response> putJson(
    String ruta,
    Map<String, dynamic> cuerpo, {
    Map<String, String>? consulta,
  }) async {
    final respuesta = await _cliente
        .put(
          _uri(ruta, consulta),
          headers: _cabeceras(extra: {'Content-Type': 'application/json'}),
          body: jsonEncode(cuerpo),
        )
        .timeout(ApiConfig.tiempoLimite);
    return _verificar(respuesta);
  }

  Future<http.Response> postMultipart(
    String ruta, {
    required List<int> bytes,
    required String nombreArchivo,
    required String contentType,
    Map<String, String> campos = const {},
  }) async {
    final solicitud = http.MultipartRequest('POST', _uri(ruta))
      ..headers.addAll(_cabeceras())
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: nombreArchivo,
          contentType: MediaType.parse(contentType),
        ),
      )
      ..fields.addAll(campos);

    final http.StreamedResponse respuestaStreamed;
    try {
      final enviada = _cliente.send(solicitud);
      respuestaStreamed = await enviada.timeout(ApiConfig.tiempoLimite);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        error: 'tiempo_excedido',
        message: 'El servidor tardó demasiado en responder.',
      );
    }
    final respuesta = await http.Response.fromStream(respuestaStreamed);
    return _verificar(respuesta);
  }

  http.Response _verificar(http.Response respuesta) {
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return respuesta;
    }
    String? error;
    String? mensaje;
    try {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (json is Map<String, dynamic>) {
        error = json['error'] as String?;
        mensaje = json['message'] as String?;
      }
    } on FormatException {
      // cuerpo no JSON; se ignora
    }
    throw ApiException(
      statusCode: respuesta.statusCode,
      error: error ?? 'error',
      message: mensaje,
    );
  }

  void cerrar() => _cliente.close();
}
