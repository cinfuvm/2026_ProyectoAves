import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/user/me — perfil del usuario autenticado (Bearer).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }
  return reenviarAlBackend(
    context,
    ruta: '/api/user/me',
    normalizar: normalizarUsuario,
  );
}
