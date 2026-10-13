import 'dart:convert';

import 'package:bff/backend.dart';
import 'package:test/test.dart';

/// Ayuda a leer el resultado sin encadenar índices sobre `dynamic`.
Map<String, dynamic> _data(Map<String, dynamic>? resultado) {
  expect(resultado, isNotNull);
  return resultado!['data'] as Map<String, dynamic>;
}

/// `user` dentro de una sesión normalizada (`{data:{user}}`).
Map<String, dynamic> _userDeSesion(Map<String, dynamic>? resultado) {
  return _data(resultado)['user'] as Map<String, dynamic>;
}

/// `user` de `GET /api/user/me` (`{user}`).
Map<String, dynamic> _user(Map<String, dynamic>? resultado) {
  expect(resultado, isNotNull);
  return resultado!['user'] as Map<String, dynamic>;
}

void main() {
  group('normalizarSesion', () {
    test('plana: {token,user:{...}} pasa a {data:{token,user}}.', () {
      final cuerpo = jsonEncode({
        'token': 'abc',
        'user': {'id': '1', 'user': 'ana.rios', 'rol': 'usuario'},
      });
      final data = _data(normalizarSesion(cuerpo));
      expect(data['token'], equals('abc'));
      expect(
        data['user'] as Map<String, dynamic>,
        equals({'user': 'ana.rios'}),
      );
    });

    test('anidada: {data:{token,user}} se conserva.', () {
      final cuerpo = jsonEncode({
        'data': {
          'token': 'abc',
          'user': {'user': 'ana.rios'},
        },
      });
      expect(_data(normalizarSesion(cuerpo))['token'], equals('abc'));
    });

    test('user como string se queda en user.', () {
      final cuerpo = jsonEncode({'token': 'abc', 'user': 'pepe'});
      expect(
        _userDeSesion(normalizarSesion(cuerpo)),
        equals({'user': 'pepe'}),
      );
    });

    test('tolera un backend viejo que aún manda email o nickname.', () {
      final conEmail = jsonEncode({
        'token': 'abc',
        'user': {'email': 'a@b.cl'},
      });
      expect(_userDeSesion(normalizarSesion(conEmail))['user'], 'a@b.cl');

      final conNickname = jsonEncode({
        'token': 'abc',
        'user': {'nickname': 'ana'},
      });
      expect(_userDeSesion(normalizarSesion(conNickname))['user'], 'ana');
    });

    test('devuelve null si no hay token (la respuesta pasa tal cual).', () {
      final cuerpo = jsonEncode({'user': <String, dynamic>{}});
      expect(normalizarSesion(cuerpo), isNull);
    });

    test('devuelve null si el cuerpo no es JSON.', () {
      expect(normalizarSesion('<html>'), isNull);
    });

    test('devuelve null si el cuerpo es una lista.', () {
      expect(normalizarSesion('[1,2]'), isNull);
    });
  });

  group('normalizarUsuario', () {
    test('devuelve solo {user:{user}}, sin campos extra.', () {
      final cuerpo = jsonEncode({
        'user': {'id': '1', 'user': 'ana.rios', 'rol': 'usuario'},
        'extra': 'x',
      });
      expect(
        normalizarUsuario(cuerpo),
        equals({
          'user': {'user': 'ana.rios'},
        }),
      );
    });

    test('tolera un backend viejo que aún manda email o nickname.', () {
      final conEmail = normalizarUsuario(
        jsonEncode({
          'user': {'email': 'a@b.cl'},
        }),
      );
      expect(_user(conEmail)['user'], equals('a@b.cl'));

      final conNickname = normalizarUsuario(
        jsonEncode({
          'user': {'nickname': 'ana'},
        }),
      );
      expect(_user(conNickname)['user'], equals('ana'));
    });

    test('devuelve user vacío si el objeto no trae identificador.', () {
      final sinIdentificador = normalizarUsuario(
        jsonEncode({
          'user': {'rol': 'usuario'},
        }),
      );
      expect(_user(sinIdentificador)['user'], equals(''));
    });

    test('devuelve null si no hay objeto user.', () {
      expect(normalizarUsuario(jsonEncode({'id': 'x'})), isNull);
    });

    test('devuelve null si el cuerpo no es JSON.', () {
      expect(normalizarUsuario('no-json'), isNull);
    });
  });
}
