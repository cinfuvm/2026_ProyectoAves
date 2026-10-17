// Backend Phoenix simulado, para probar el BFF y la app móvil sin tener el
// backend real (que corre en otra máquina) ni PostgreSQL.
//
// Reproduce las 4 rutas de autenticación que consume la app:
//   POST   /api/user/signin  -> 201 {data:{token, user:{id,user,rol}}}
//   POST   /api/user/login   -> 200 {data:{token, user:{id,user,rol}}}
//   GET    /api/user/me      -> 200 {user:{id,user,rol}}       (requiere Bearer)
//   DELETE /api/user/logout  -> 200 {message}
//
// El identificador llega como `user` en el registro y como `email` en el
// login, y se devuelve siempre como `user` en el JSON, el nombre que fija el
// contrato `birds_apis.yaml` (en la base de datos es `username`).
// No valida credenciales: devuelve el identificador que se le pidió, para que
// la app muestre en el perfil lo mismo que se escribió en el formulario.
//
// Uso:
//   dart scripts\mock_backend.dart              # 0.0.0.0:4001
//   dart scripts\mock_backend.dart --port 5000
//
// Arrancá el BFF apuntando a este puerto:
//   $env:BACKEND_URL = 'http://127.0.0.1:4001'
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final idx = args.indexOf('--port');
  final puerto = idx >= 0 && idx + 1 < args.length
      ? int.parse(args[idx + 1])
      : 4001;

  final server = HttpServer.bind(InternetAddress.anyIPv4, puerto).then((
    srv,
  ) async {
    stdout.writeln(
      'Mock backend escuchando en http://0.0.0.0:$puerto  (Ctrl+C para parar)',
    );
    await for (final req in srv) {
      _manejar(req);
    }
  });
  server.catchError((Object e) {
    stderr.writeln('No se pudo escuchar en el puerto $puerto: $e');
    exitCode = 1;
  });
}

Future<void> _manejar(HttpRequest req) async {
  final metodo = req.method;
  final ruta = req.uri.path;
  final auth = req.headers.value('authorization');
  final contentType = req.headers.contentType?.mimeType ?? '';

  // Multipart es binario: se leen bytes, nunca texto, para no corromperlo.
  final bytes = await req.fold<List<int>>(<int>[], (acumulado, trozo) {
    acumulado.addAll(trozo);
    return acumulado;
  });
  final esBinario =
      contentType.startsWith('multipart/') || bytes.contains(0);
  final cuerpo = esBinario ? null : utf8.decode(bytes, allowMalformed: true);

  final descripcion = esBinario
      ? '${bytes.length} bytes ($contentType)'
      : (cuerpo == null || cuerpo.isEmpty ? '' : 'body=$cuerpo');
  final consulta = req.uri.query.isEmpty ? '' : ' query=${req.uri.query}';

  stdout.writeln(
    '[$metodo $ruta] auth=${auth != null ? 'si' : 'no'}'
    '$consulta${descripcion.isEmpty ? '' : ' $descripcion'}',
  );

  // El identificador que pidió el cliente, para devolverlo igual que el
  // backend real; si no hay cuerpo JSON, se responde con el usuario demo.
  final identificador = _identificador(cuerpo);

  final clave = '$metodo $ruta';
  switch (clave) {
    case 'POST /api/user/signin':
      _responder(req, 201, {
        'data': {
          'token': 'mock-token-123',
          'user': _datosUsuario(identificador),
        },
      });
    case 'POST /api/user/login':
      _responder(req, 200, {
        'data': {
          'token': 'mock-token-123',
          'user': _datosUsuario(identificador),
        },
      });
    case 'GET /api/user/me':
      if (auth == null) {
        _responder(req, 401, {'error': 'unauthorized', 'message': 'Falta el token.'});
      } else {
        _responder(req, 200, {'user': _datosUsuario(identificador)});
      }
    case 'DELETE /api/user/logout':
      _responder(req, 200, {'message': 'Sesión cerrada.'});
    case 'GET /images':
      _responder(req, 200, _paginaFotos(req.uri.queryParameters));
    case 'POST /images':
      _responder(req, 201, {
        'id': 'foto-${DateTime.now().millisecondsSinceEpoch}',
        'url': 'https://picsum.photos/seed/aves/640/480',
        'categoria': 'ave',
        'autor': 'demo',
        'subida_en': DateTime.now().toUtc().toIso8601String(),
      });
    case 'PUT /images':
      _responder(req, 200, {
        'id': req.uri.queryParameters['id'] ?? '',
        'motivo': 'reportado',
        'estado': 'recibido',
      });
    default:
      _responder(req, 404, {
        'error': 'not_found',
        'message': 'Ruta no encontrada: $clave',
      });
  }
}

/// Último identificador entregado. `/me` y `/logout` llegan sin cuerpo, y así
/// devuelven el mismo usuario que acaba de entrar, como hace el backend real
/// leyendo el token. No hay sesiones: si reinicias el mock vuelve a `demo`.
String _ultimo = 'demo';

/// Lee el identificador del cuerpo JSON: `user` (registro) o `email` (login).
/// Si no trae ninguno, devuelve el último identificador entregado.
String _identificador(String? cuerpo) {
  if (cuerpo == null || cuerpo.isEmpty) return _ultimo;
  try {
    final json = jsonDecode(cuerpo);
    if (json is Map<String, dynamic>) {
      for (final campo in const ['user', 'email']) {
        final valor = json[campo];
        if (valor is String && valor.trim().isNotEmpty) {
          _ultimo = valor.trim();
          return _ultimo;
        }
      }
    }
  } on FormatException {
    // Sin cuerpo JSON se contesta con el último usuario entregado.
  }
  return _ultimo;
}

/// Cuerpo del usuario en la forma que espera `_usuarioDesdeMe` de la app.
Map<String, dynamic> _datosUsuario(String identificador) => {
  'id': 'mock-0000-0000-0000-000000000000',
  'user': identificador,
  'rol': 'usuario',
};

/// Respuesta en el formato que parsea `PaginaFotos.fromJson` de la app:
/// `{urls: [...], paginado: {pagina, total}}`.
Map<String, dynamic> _paginaFotos(Map<String, String> query) {
  final pagina = int.tryParse(query['pagina'] ?? '') ?? 0;
  final porPagina = int.tryParse(query['por_pagina'] ?? '') ?? 20;
  final categoria = query['categoria'] ?? 'ave';

  final urls = List.generate(porPagina.clamp(1, 50), (i) {
    final n = pagina * porPagina + i;
    return {
      'id': 'foto-$n',
      'url': 'https://picsum.photos/seed/aves$n/640/480',
      'categoria': categoria,
      'autor': 'autor$n',
      'lugar': 'Santiago',
      'fecha': '2026-01-${(n % 28 + 1).toString().padLeft(2, '0')}',
      'comentario': 'Ave #$n',
      'subida_en': DateTime.now().toUtc().toIso8601String(),
    };
  });

  return {
    'urls': urls,
    'paginado': {'pagina': pagina, 'total': urls.length},
  };
}

void _responder(HttpRequest req, int codigo, Map<String, dynamic> cuerpo) {
  final respuesta = req.response;
  final bytes = utf8.encode(jsonEncode(cuerpo));
  respuesta.statusCode = codigo;
  respuesta.headers.contentType = ContentType(
    'application',
    'json',
    charset: 'utf-8',
  );
  respuesta.headers.contentLength = bytes.length;
  respuesta.add(bytes);
  respuesta.close();
}
