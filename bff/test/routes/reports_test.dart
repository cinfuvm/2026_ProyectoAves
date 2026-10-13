import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/images/reports.dart' as lista;
import '../../routes/images/reports/[id].dart' as detalle;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

Future<_MockRequestContext> _contexto(HttpMethod metodo) async {
  final request = _MockRequest();
  when(() => request.method).thenReturn(metodo);
  final context = _MockRequestContext();
  when(() => context.request).thenReturn(request);
  return context;
}

Future<void> _rechaza(
  Future<Response> Function(RequestContext) ruta,
  HttpMethod metodo,
) async {
  final response = await ruta(await _contexto(metodo));
  expect(response.statusCode, equals(HttpStatus.methodNotAllowed));

  final json = jsonDecode(await response.body()) as Map<String, dynamic>;
  expect(json['message'], equals('Método no permitido'));
}

void main() {
  // GET y PUT se proxyan (eso se comprueba con el servidor real, no aquí);
  // sin red solo se verifica que el resto de métodos se rechaza con 405.
  group('GET /images/reports', () {
    test('rechaza POST.', () => _rechaza(lista.onRequest, HttpMethod.post));
    test('rechaza PUT.', () => _rechaza(lista.onRequest, HttpMethod.put));
    test('rechaza DELETE.', () => _rechaza(lista.onRequest, HttpMethod.delete));
    test('rechaza PATCH.', () => _rechaza(lista.onRequest, HttpMethod.patch));
  });

  group('PUT /images/reports/:id', () {
    Future<void> rechaza(HttpMethod metodo) async {
      final response = await detalle.onRequest(await _contexto(metodo), 'abc');
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));

      final json = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(json['message'], equals('Método no permitido'));
    }

    test('rechaza GET.', () => rechaza(HttpMethod.get));
    test('rechaza POST.', () => rechaza(HttpMethod.post));
    test('rechaza DELETE.', () => rechaza(HttpMethod.delete));
    test('rechaza PATCH.', () => rechaza(HttpMethod.patch));
  });
}
