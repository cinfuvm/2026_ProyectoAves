import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// DELETE /api/user/logout — revoca el token en el backend.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.delete) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }
  return reenviarAlBackend(context, ruta: '/api/user/logout');
}
