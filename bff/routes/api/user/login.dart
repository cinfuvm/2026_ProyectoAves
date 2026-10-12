import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/user/login — inicio de sesión.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }
  return reenviarAlBackend(
    context,
    ruta: '/api/user/login',
    normalizar: normalizarSesion,
  );
}
