import 'dart:convert';

import 'package:bff/backend.dart';
import 'package:test/test.dart';

void main() {
  group('mensajeAmigable — identidades ya registradas', () {
    // Ash devuelve `errors` como lista; las reglas aplican a los strings.
    test('email duplicado.', () {
      const cuerpo =
          '{"errors": ["Email has already been taken (for email)"]}';
      expect(
        mensajeAmigable(cuerpo),
        equals('El email ya está registrado.'),
      );
    });

    test('nickname duplicado.', () {
      expect(
        mensajeAmigable(
          '{"errors": ["Nickname has already been taken (for nickname)"]}',
        ),
        equals('El nickname ya está en uso.'),
      );
    });

    test('duplicado sin atributo conocido.', () {
      expect(
        mensajeAmigable('{"errors": ["Algo has already been taken"]}'),
        equals('El valor ya está registrado.'),
      );
    });

    test('en errores-map usa el campo "title" si existe.', () {
      final cuerpo = jsonEncode({
        'errors': [
          {'title': 'must be unique', 'detail': 'Email has already been taken'},
        ],
      });
      expect(mensajeAmigable(cuerpo), equals('must be unique'));
    });
  });

  group('mensajeAmigable — argumentos requeridos', () {
    const casos = <String, String>{
      'argument email is required': 'El email es obligatorio.',
      'attribute email is required': 'El email es obligatorio.',
      'argument password is required': 'La contraseña es obligatoria.',
      'argument password_confirmation is required':
          'Debes confirmar la contraseña.',
      'argument confirm_password is required': 'Debes confirmar la contraseña.',
      'attribute nickname is required': 'El nickname es obligatorio.',
    };

    casos.forEach((entrada, salida) {
      test('"$entrada" -> "$salida".', () {
        expect(mensajeAmigable(jsonEncode({'errors': [entrada]})), salida);
      });
    });
  });

  group('mensajeAmigable — errores de validación del backend', () {
    test('une varios errores con salto de línea.', () {
      final cuerpo = jsonEncode({
        'errors': [
          {'title': 'Email no es válido'},
          {'title': 'La contraseña es demasiado corta'},
        ],
      });
      expect(
        mensajeAmigable(cuerpo),
        equals('Email no es válido\nLa contraseña es demasiado corta'),
      );
    });

    test('quita el breadcrumb "Invalid value provided for email:".', () {
      const cuerpo =
          '{"errors": ["Invalid value provided for email: no-es-un-email"]}';
      expect(mensajeAmigable(cuerpo), equals('no-es-un-email'));
    });
  });

  group('mensajeAmigable — mensajes que no son traducibles', () {
    test('devuelve null si el cuerpo no es JSON.', () {
      expect(mensajeAmigable('<html>502</html>'), isNull);
    });

    test('devuelve null si el JSON no tiene errores reconocibles.', () {
      expect(mensajeAmigable(jsonEncode({'otra': 'clave'})), isNull);
    });

    test('devuelve null si la lista de errores queda vacía tras filtrar.', () {
      expect(
        mensajeAmigable(jsonEncode({'errors': <dynamic>[<String, String>{}]})),
        isNull,
      );
    });

    test('usa el campo "message" del backend si existe.', () {
      expect(
        mensajeAmigable(jsonEncode({'message': 'Credenciales inválidas'})),
        equals('Credenciales inválidas'),
      );
    });

    test('usa el campo "error" del backend si existe.', () {
      expect(
        mensajeAmigable(jsonEncode({'error': 'unauthorized'})),
        equals('unauthorized'),
      );
    });
  });
}
