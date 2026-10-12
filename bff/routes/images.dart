import 'package:bff/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// /images — catálogo de fotos (contrato en `birds_apis.yaml`).
///
///   GET    /images?categoria=&pagina=&por_pagina=  lista pública
///   POST   /images                                  subida multipart (Bearer)
///   PUT    /images?id=                              reporte de moderación (Bearer)
///
/// El BFF no interpreta el contenido: reenvía método, query string, cabeceras
/// y cuerpo (bytes crudos, para no romper el multipart).
Future<Response> onRequest(RequestContext context) async {
  final metodo = context.request.method;
  final permitido = metodo == HttpMethod.get ||
      metodo == HttpMethod.post ||
      metodo == HttpMethod.put;

  if (!permitido) {
    return Response.json(
      statusCode: 405,
      body: {'message': 'Método no permitido'},
    );
  }

  return reenviarAlBackend(context, ruta: '/images');
}
