import 'dart:convert';

import '../models/foto_publica.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'fotos_service.dart';

class FotosServiceBff implements FotosService {
  FotosServiceBff({ApiClient? cliente, AuthService? auth})
    : _cliente = cliente ?? ApiClient(),
      _auth = auth ?? AuthService();

  final ApiClient _cliente;
  final AuthService _auth;

  Future<void> _asegurarToken() async {
    _cliente.token = await _auth.obtenerToken();
  }

  Map<String, dynamic> _jsonMap(List<int> cuerpo) {
    final json = jsonDecode(utf8.decode(cuerpo));
    if (json is Map<String, dynamic>) return json;
    throw const FormatException('Respuesta del servidor no válida.');
  }

  @override
  Future<PaginaFotos> getFotos({
    required String categoria,
    int pagina = 0,
    int porPagina = 20,
  }) async {
    await _asegurarToken();
    final respuesta = await _cliente.get(
      '/images',
      consulta: {
        'categoria': categoria,
        'pagina': '$pagina',
        'por_pagina': '$porPagina',
      },
    );
    return PaginaFotos.fromJson(_jsonMap(respuesta.bodyBytes));
  }

  @override
  Future<FotoPublica> subirFoto({
    required List<int> bytes,
    required String nombreArchivo,
    required String contentType,
    required String categoria,
    String? lugar,
    String? fecha,
    String? comentario,
  }) async {
    await _asegurarToken();
    final respuesta = await _cliente.postMultipart(
      '/images',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      contentType: contentType,
      campos: {
        'categoria': categoria,
        if (lugar != null && lugar.isNotEmpty) 'lugar': lugar,
        if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      },
    );
    return FotoPublica.fromJson(_jsonMap(respuesta.bodyBytes));
  }

  @override
  Future<void> reportarFoto({
    required String id,
    required String motivo,
    String? detalle,
  }) async {
    await _asegurarToken();
    await _cliente.putJson(
      '/images',
      {
        'motivo': motivo,
        if (detalle != null && detalle.isNotEmpty) 'detalle': detalle,
      },
      consulta: {'id': id},
    );
  }
}
