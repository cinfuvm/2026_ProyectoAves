import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

/// URL del backend Phoenix.
///
/// Configurable con la variable de entorno `BACKEND_URL`.
///
/// El puerto por defecto es el **4001** porque el propio BFF ocupa el 4000:
/// apuntar a `127.0.0.1:4000` haría que el BFF hiciera proxy de sí mismo.
final String backendUrl =
    Platform.environment['BACKEND_URL'] ?? 'http://127.0.0.1:4001';

/// Tope de espera al backend antes de responder 502, para que una llamada
/// muerta no deje la petición colgada indefinidamente.
const Duration _tiempoLimite = Duration(seconds: 15);

/// Reenvía la petición al backend y normaliza las respuestas de error
/// a un formato legible: `{"message": "..."}`.
///
/// La query string de la petición original se conserva (necesario para
/// `/images?categoria=...` e `/images?id=...`), y el cuerpo se reenvía como
/// bytes crudos para no romper las subidas `multipart/form-data`.
///
/// [normalizar], si se pasa, recibe el cuerpo del backend y devuelve la forma
/// que debe recibir la app móvil. Si devuelve `null`, o si el cuerpo no se
/// puede leer, la respuesta pasa tal cual.
Future<Response> reenviarAlBackend(
  RequestContext context, {
  required String ruta,
  Map<String, dynamic>? Function(String cuerpo)? normalizar,
}) async {
  final request = context.request;
  final headers = <String, String>{
    'content-type': request.headers['content-type'] ?? 'application/json',
    if (request.headers['authorization'] != null)
      'authorization': request.headers['authorization']!,
  };

  final uri = Uri.parse('$backendUrl$ruta').replace(
    queryParameters: request.uri.queryParametersAll,
  );
  final client = http.Client();

  try {
    // `http.Client.post/put/delete` no aceptan streams: solo `String`,
    // `List<int>` o `Map<String, String>`. Se leen los bytes una sola vez
    // (el stream admite un solo listener) y se pasan sin re-serializar, para
    // que el multipart conserve su boundary.
    final cuerpo = await _cuerpoBytes(request);

    final http.Response respuesta;
    switch (request.method) {
      case HttpMethod.get:
        respuesta = await client
            .get(uri, headers: headers)
            .timeout(_tiempoLimite);
      case HttpMethod.post:
        respuesta = await client
            .post(uri, headers: headers, body: cuerpo)
            .timeout(_tiempoLimite);
      case HttpMethod.put:
        respuesta = await client
            .put(uri, headers: headers, body: cuerpo)
            .timeout(_tiempoLimite);
      case HttpMethod.delete:
        respuesta = await client
            .delete(uri, headers: headers, body: cuerpo)
            .timeout(_tiempoLimite);
      case HttpMethod.head:
      case HttpMethod.options:
      case HttpMethod.patch:
        return _noPermitido();
    }
    return _respuestaNormalizada(respuesta, normalizar: normalizar);
  } on SocketException {
    return _backendNoDisponible();
  } on http.ClientException {
    return _backendNoDisponible();
  } on TimeoutException {
    return _backendNoDisponible();
  } finally {
    client.close();
  }
}

/// Cuerpo de la petición como bytes, sin pasar por texto.
///
/// `Request.bytes()` devuelve el `HttpRequest` crudo como `Stream<List<int>>`:
/// convertirlo a String rompería el multipart de las subidas de foto. En GET
/// no hay cuerpo, así que se ahorra la lectura.
Future<List<int>> _cuerpoBytes(Request request) async {
  if (request.method == HttpMethod.get) return const <int>[];

  final bytes = <int>[];
  await for (final trozo in request.bytes()) {
    bytes.addAll(trozo);
  }
  return bytes;
}

Response _noPermitido() => Response.json(
  statusCode: 405,
  body: {'message': 'Método no permitido'},
);

Response _backendNoDisponible() => Response.json(
  statusCode: 502,
  body: {'message': 'El servidor no está disponible'},
);

/// Las respuestas exitosas pasan tal cual; los errores 4xx/5xx se traducen
/// a mensajes amigables (elimina los "Bread Crumbs" de Ash).
Response _respuestaNormalizada(
  http.Response respuesta, {
  Map<String, dynamic>? Function(String cuerpo)? normalizar,
}) {
  final contentType = respuesta.headers['content-type'] ?? '';
  final esJson = contentType.contains('application/json');

  if (respuesta.statusCode < 400 || !esJson) {
    return Response(
      statusCode: respuesta.statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: _aplicarNormalizacion(respuesta, normalizar) ?? respuesta.body,
    );
  }

  final mensaje = mensajeAmigable(respuesta.body);
  if (mensaje == null) {
    return Response(
      statusCode: respuesta.statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: respuesta.body,
    );
  }
  return Response.json(
    statusCode: respuesta.statusCode,
    body: {'message': mensaje},
  );
}

/// Si el cuerpo no se puede leer o el normalizador decide que no aplica,
/// se devuelve `null` y la respuesta sigue tal cual.
String? _aplicarNormalizacion(
  http.Response respuesta,
  Map<String, dynamic>? Function(String cuerpo)? normalizar,
) {
  if (normalizar == null || respuesta.body.isEmpty) return null;
  try {
    final normalizado = normalizar(respuesta.body);
    return normalizado == null ? null : jsonEncode(normalizado);
  } on FormatException {
    return null;
  }
}

/// Intenta producir un mensaje humano a partir del cuerpo de error.
///
/// Es una función pura (no toca red) para poder testearla directamente.
String? mensajeAmigable(String cuerpo) {
  final dynamic json;
  try {
    json = jsonDecode(cuerpo);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, dynamic>) return null;

  final mensaje = json['message'] ?? json['error'];
  if (mensaje is String && mensaje.isNotEmpty) return mensaje;

  final errores = json['errors'];
  if (errores is List) {
    final textos = errores
        .map(_textoLegible)
        .whereType<String>()
        .toList(growable: false);
    if (textos.isNotEmpty) return textos.join('\n');
  }
  return null;
}

/// Convierte un elemento de la lista `errors` en un texto comprensible.
String? _textoLegible(dynamic elemento) {
  if (elemento is Map<String, dynamic>) {
    final texto =
        elemento['title'] ?? elemento['detail'] ?? elemento['message'];
    return texto is String && texto.isNotEmpty ? texto : null;
  }
  if (elemento is! String || elemento.isEmpty) return null;

  final texto = elemento;

  // Reglas conocidas del backend (Ash devuelve mensajes con breadcrumb).
  if (texto.contains('has already been taken')) {
    if (texto.contains('for username')) return 'El usuario ya está en uso.';
    return 'El valor ya está registrado.';
  }
  const requeridos = <String, String>{
    'argument username is required': 'El usuario es obligatorio.',
    'attribute username is required': 'El usuario es obligatorio.',
    'argument password is required': 'La contraseña es obligatoria.',
    'argument password_confirmation is required':
        'Debes confirmar la contraseña.',
    'argument confirm_password is required': 'Debes confirmar la contraseña.',
  };
  for (final entrada in requeridos.entries) {
    if (texto.contains(entrada.key)) return entrada.value;
  }

  // Genérico: quitar el breadcrumb de Ash y quedarse con la línea útil.
  final lineas = texto
      .split(RegExp(r'\r?\n'))
      .map((linea) => linea.trim())
      .where(
        (linea) =>
            linea.isNotEmpty &&
            !linea.startsWith('Bread Crumbs') &&
            !linea.startsWith('>') &&
            !linea.startsWith('Error returned from'),
      )
      .toList(growable: false);
  if (lineas.isEmpty) return null;

  var ultima = lineas.last;
  final invalid = RegExp(
    r'^Invalid value provided for \w+:\s*',
  ).firstMatch(ultima);
  if (invalid != null) ultima = ultima.substring(invalid.end);
  return ultima.isEmpty ? null : ultima;
}

// ---------------------------------------------------------------------------
// Normalización de la sesión para la app móvil
//
// El contrato (`birds_apis.yaml`, schema `RespuestaSesion`) admite dos formas:
// plana `{token, user}` o anidada `{data: {token, user}}`, y además `user`
// puede ser un string o un objeto. El backend además puede cambiar de forma
// por la coordinación con web. Estas funciones reducen todo eso a un único
// shape estable para la app, así un cambio de forma solo toca el BFF.
// ---------------------------------------------------------------------------

/// `login`/`signin` → `{"data": {"token": "...", "user": {"user": "..."}}}`,
/// con `rol` añadido si el backend lo mandó.
///
/// Devuelve `null` si no hay token, y en ese caso la respuesta pasa tal cual.
Map<String, dynamic>? normalizarSesion(String cuerpo) {
  final json = _comoMapa(_decodificar(cuerpo));
  if (json == null) return null;

  // Admite tanto `{token,...}` como `{data: {token,...}}`.
  final sesion = _comoMapa(json['data']) ?? json;
  final token = sesion['token'];
  if (token is! String || token.isEmpty) return null;

  return {
    'data': {
      'token': token,
      'user': _usuarioNormalizado(sesion['user']),
    },
  };
}

/// `GET /api/user/me` → `{"user": {"user": "...", "rol": "..."}}`.
Map<String, dynamic>? normalizarUsuario(String cuerpo) {
  final json = _comoMapa(_decodificar(cuerpo));
  if (json == null) return null;

  final datos = _comoMapa(json['user']);
  if (datos == null) return null;

  return {'user': _usuarioNormalizado(datos)};
}

/// `user` puede venir como string o como objeto con el identificador dentro.
///
/// El backend lo manda como `user`; se toleran `email` y `nickname` por si
/// alguna versión vieja aún los emite. `rol` solo viaja si el backend lo manda:
/// es lo que decide si la app enseña la pantalla de moderación.
Map<String, dynamic> _usuarioNormalizado(dynamic usuario) {
  if (usuario is String) return {'user': usuario};

  final mapa = _comoMapa(usuario) ?? const <String, dynamic>{};
  final identificador = mapa['user'] ?? mapa['email'] ?? mapa['nickname'];
  final rol = mapa['rol'];

  return {
    'user': identificador is String ? identificador : '',
    if (rol is String && rol.isNotEmpty) 'rol': rol,
  };
}

dynamic _decodificar(String cuerpo) {
  try {
    return jsonDecode(cuerpo);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic>? _comoMapa(dynamic valor) =>
    valor is Map<String, dynamic> ? valor : null;
