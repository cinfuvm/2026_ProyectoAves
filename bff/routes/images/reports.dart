import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// /images/reports — lista de reportes de moderación.
///
///   GET /images/reports?estado=  reportes con su foto (solo `admin`)
///
/// No forma parte de `birds_apis.yaml`: es una extensión propia para la
/// pantalla de moderación de la app. El BFF no decide nada, solo reenvía
/// método, query string y cabeceras; el 403 lo pone Phoenix.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }

  return reenviarAlBackend(context, ruta: '/images/reports');
}
