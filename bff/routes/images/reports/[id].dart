import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// /images/reports/:id — cambia el estado de un reporte.
///
///   PUT /images/reports/:id  {"estado": "abierto" | "revisado" | "descartado"}
///
/// Se usa PUT y no PATCH porque el proxy del BFF no admite PATCH (ver
/// `reenviarAlBackend`), y es el mismo verbo con el que ya se abren reportes
/// en `PUT /images?id=`. El rol lo comprueba Phoenix.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.put) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }

  return reenviarAlBackend(context, ruta: '/images/reports/$id');
}
