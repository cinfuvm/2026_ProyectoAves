import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /', () {
    test('responde 200 con el estado del servicio.', () async {
      final context = _MockRequestContext();
      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.body();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], equals('ok'));
    });
  });
}
