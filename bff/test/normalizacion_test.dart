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
        'user': {'email': 'a@b.cl', 'nickname': 'a'},
      });
      final data = _data(normalizarSesion(cuerpo));
      expect(data['token'], equals('abc'));
      expect(
        data['user'] as Map<String, dynamic>,
        equals({'email': 'a@b.cl', 'nickname': 'a'}),
      );
    });

    test('anidada: {data:{token,user}} se conserva.', () {
      final cuerpo = jsonEncode({
        'data': {
          'token': 'abc',
          'user': {'email': 'a@b.cl', 'nickname': 'a'},
        },
      });
      expect(_data(normalizarSesion(cuerpo))['token'], equals('abc'));
    });

    test('user como string usa el mismo valor de email y nickname.', () {
      final cuerpo = jsonEncode({'token': 'abc', 'user': 'pepe'});
      expect(
        _userDeSesion(normalizarSesion(cuerpo)),
        equals({'email': 'pepe', 'nickname': 'pepe'}),
      );
    });

    test('sin nickname se usa el email.', () {
      final cuerpo = jsonEncode({
        'token': 'abc',
        'user': {'email': 'a@b.cl'},
      });
      expect(
        _userDeSesion(normalizarSesion(cuerpo))['nickname'],
        equals('a@b.cl'),
      );
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
    test('devuelve solo {user:{email,nickname}}, sin campos extra.', () {
      final cuerpo = jsonEncode({
        'user': {'email': 'a@b.cl', 'nickname': 'a'},
        'id': 'x',
      });
      expect(
        normalizarUsuario(cuerpo),
        equals({
          'user': {'email': 'a@b.cl', 'nickname': 'a'},
        }),
      );
    });

    test('user sin nickname cae al email.', () {
      final cuerpo = jsonEncode({
        'user': {'email': 'a@b.cl'},
      });
      expect(_user(normalizarUsuario(cuerpo))['nickname'], equals('a@b.cl'));
    });

    test('devuelve null si no hay objeto user.', () {
      expect(normalizarUsuario(jsonEncode({'id': 'x'})), isNull);
    });

    test('devuelve null si el cuerpo no es JSON.', () {
      expect(normalizarUsuario('no-json'), isNull);
    });
  });
}
