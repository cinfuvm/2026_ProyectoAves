import 'dart:async';
import 'dart:io';

import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

/// GET / — salud del BFF.
///
/// Reporta además si el backend es alcanzable y a qué URL apunta: con el
/// backend en otra máquina, eso es lo primero que hay que mirar cuando algo
/// falla.
Future<Response> onRequest(RequestContext context) async {
  return Response.json(
    body: {
      'service': 'aves-bff',
      'status': 'ok',
      'backend': await _estadoBackend(),
      'routes': [
        'POST /api/user/signin',
        'POST /api/user/login',
        'GET /api/user/me',
        'DELETE /api/user/logout',
        'GET /images',
        'POST /images',
        'PUT /images',
      ],
    },
  );
}

/// Cualquier respuesta del backend cuenta como alcanzable; solo un error de
/// conexión, de cliente o de tiempo agota significa que no se puede contactar.
Future<Map<String, dynamic>> _estadoBackend() async {
  const tope = Duration(seconds: 3);
  final raiz = Uri.parse(backendUrl).replace(path: '/');

  try {
    await http.get(raiz).timeout(tope);
    return {'url': backendUrl, 'reachable': true};
  } on SocketException {
    return {'url': backendUrl, 'reachable': false};
  } on http.ClientException {
    return {'url': backendUrl, 'reachable': false};
  } on TimeoutException {
    return {'url': backendUrl, 'reachable': false};
  }
}
