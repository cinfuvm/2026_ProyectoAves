import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_aves/models/usuario.dart';

void main() {
  group('Usuario.rol', () {
    test('solo el rol admin puede entrar a la moderación', () {
      expect(
        const Usuario(nombre: 'Emu', user: 'emulador', rol: 'admin').esAdmin,
        isTrue,
      );
      expect(
        const Usuario(nombre: 'Demo', user: 'demo', rol: 'usuario').esAdmin,
        isFalse,
      );
      expect(
        const Usuario(nombre: 'Mod', user: 'mod', rol: 'moderador').esAdmin,
        isFalse,
      );
      // Sesión antigua en caché, sin rol: no debe abrir nada por accidente.
      expect(const Usuario(nombre: 'Anon').esAdmin, isFalse);
      expect(const Usuario(nombre: 'Anon').rol, isEmpty);
    });

    test('fromJson lee el rol y lo guarda en el JSON de caché', () {
      final usuario = Usuario.fromJson({
        'nombre': 'emulador',
        'user': 'emulador',
        'rol': 'admin',
        'token': 't1',
      });

      expect(usuario.user, 'emulador');
      expect(usuario.rol, 'admin');
      expect(usuario.esAdmin, isTrue);

      final json = usuario.toJson();
      expect(json['rol'], 'admin');
      expect(json['user'], 'emulador');
      // Sin rol no se escribe la clave: no hay que ensuciar la caché.
      expect(
        const Usuario(nombre: 'Emu').toJson().containsKey('rol'),
        isFalse,
      );
    });
  });
}
