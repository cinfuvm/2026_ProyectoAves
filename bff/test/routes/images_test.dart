import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/images.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

/// GET, POST y PUT se proxyan (eso se prueba con el servidor real, no aquí);
/// lo que se comprueba sin red es que el resto de métodos se rechaza con 405.
Future<void> _espera405(HttpMethod metodo) async {
  final request = _MockRequest();
  when(() => request.method).thenReturn(metodo);
  final context = _MockRequestContext();
  when(() => context.request).thenReturn(request);

  final response = await route.onRequest(context);
  expect(response.statusCode, equals(HttpStatus.methodNotAllowed));

  final json = jsonDecode(await response.body()) as Map<String, dynamic>;
  expect(json['message'], equals('Método no permitido'));
}

void main() {
  group('GET|POST|PUT /images', () {
    test('rechaza DELETE.', () => _espera405(HttpMethod.delete));
    test('rechaza PATCH.', () => _espera405(HttpMethod.patch));
    test('rechaza HEAD.', () => _espera405(HttpMethod.head));
    test('rechaza OPTIONS.', () => _espera405(HttpMethod.options));
  });
}
