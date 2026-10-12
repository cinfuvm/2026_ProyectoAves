import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/api/user/login.dart' as login;
import '../../routes/api/user/logout.dart' as logout;
import '../../routes/api/user/me.dart' as me;
import '../../routes/api/user/signin.dart' as signin;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

/// Ejecuta el handler con `metodo` y comprueba que responde 405 con mensaje,
/// sin llegar a tocar la red.
Future<void> _espera405(
  Future<Response> Function(RequestContext) handler,
  HttpMethod metodo,
) async {
  final request = _MockRequest();
  when(() => request.method).thenReturn(metodo);
  final context = _MockRequestContext();
  when(() => context.request).thenReturn(request);

  final response = await handler(context);
  expect(response.statusCode, equals(HttpStatus.methodNotAllowed));

  final json = jsonDecode(await response.body()) as Map<String, dynamic>;
  expect(json['message'], equals('Método no permitido'));
}

void main() {
  group('POST /api/user/signin', () {
    test('rechaza GET.', () => _espera405(signin.onRequest, HttpMethod.get));
    test('rechaza DELETE.', () {
      return _espera405(signin.onRequest, HttpMethod.delete);
    });
    test('rechaza PUT.', () => _espera405(signin.onRequest, HttpMethod.put));
  });

  group('POST /api/user/login', () {
    test('rechaza GET.', () => _espera405(login.onRequest, HttpMethod.get));
    test('rechaza DELETE.', () {
      return _espera405(login.onRequest, HttpMethod.delete);
    });
    test('rechaza PUT.', () => _espera405(login.onRequest, HttpMethod.put));
  });

  group('GET /api/user/me', () {
    test('rechaza POST.', () => _espera405(me.onRequest, HttpMethod.post));
    test('rechaza DELETE.', () {
      return _espera405(me.onRequest, HttpMethod.delete);
    });
    test('rechaza PUT.', () => _espera405(me.onRequest, HttpMethod.put));
  });

  group('DELETE /api/user/logout', () {
    test('rechaza GET.', () => _espera405(logout.onRequest, HttpMethod.get));
    test('rechaza POST.', () {
      return _espera405(logout.onRequest, HttpMethod.post);
    });
    test('rechaza PUT.', () => _espera405(logout.onRequest, HttpMethod.put));
  });
}
