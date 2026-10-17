# Bitácora de Aves · Documentación mobile

> [!info] Nota de lectura
> Esta carpeta `mobile/notas/` es la copia en **Markdown** de la documentación mobile, pensada para leerla en **Obsidian**. Las fuentes originales en AsciiDoc siguen en `mobile/docs/modules/ROOT/pages/` y son las que compila el sitio Antora (`npm run docs`). Cuando algo cambie, actualiza primero aquí y luego la fuente `.adoc`.

Bitácora de Aves es una aplicación Flutter para registrar observaciones de aves y conservar una colección personal en el dispositivo.

Esta documentación describe **la solución mobile y su estado en el prototipo del repositorio**. No afirma que exista una API propia, sincronización de usuarios ni moderación remota: esos servicios requieren integración con los equipos backend y dashboard.

## Notas

| Nota | Contenido |
|---|---|
| [[prd]] | Alcance, actores, requisitos funcionales, restricciones y criterios de aceptación |
| [[arquitectura]] | Diagramas C4, límites de integración, datos y privacidad |
| [[uat]] | Plan de pruebas manuales, datos de prueba y registro de resultados |
| [[cambios]] | Registro de cambios funcionales y documentales |
| [[contrato-api]] | Extensiones propuestas (y aplicadas) al contrato `birds_apis.yaml` |

## Autenticación actual

El registro y el inicio de sesión ya existen en la app, con mock local por defecto y soporte real cuando haya BFF:

- **Registro** (`RegistroScreen`): pide **usuario**, **correo electrónico** y **contraseña** (con confirmación). El usuario es el identificador público; el correo queda como forma de volver a entrar.
- **Inicio de sesión** (`LoginScreen`): se entra con **correo** y **contraseña**. No se pide el nombre de usuario.
- **Contrato**: `POST /user/signin` recibe `user`, `email`, `password`, `confirm_password`; `POST /user/login` recibe `email` y `password`. El servidor devuelve siempre el identificador público en `user` (ver [[contrato-api]]).
- **Persistencia**: el JWT se guarda en `SharedPreferences` bajo `session_usuario_v1` y se revalida con `GET /api/user/me` al abrir la app.
- **Modo mock** (`ApiConfig.usarMock`, por defecto): no pide servidor. El registro valida formato de correo y longitud de usuario/contraseña; el login valida el formato del correo.

Pantallas: `mobile/lib/screens/login_screen.dart`, `mobile/lib/screens/registro_screen.dart`; servicio: `mobile/lib/services/auth_service.dart`.

## Cómo ejecutar y verificar

```bash
cd mobile
flutter pub get
flutter run                          # modo mock por defecto
flutter analyze
flutter test
```

Con el BFF real:

```bash
flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000
```

En el emulador de Android, `10.0.2.2` apunta al `localhost` de la máquina.

## Sitio Antora

Desde la raíz del repositorio: `npm ci` y `npm run docs`. La salida queda en `build/site/`, incluidos los diagramas C4 renderizados como SVG localmente (requiere Java o `JAVA_HOME`). También puedes abrir los `.adoc` en VS Code con `AsciiDoc: Open Preview`.

## Responsabilidad

La documentación de esta sección cubre solo mobile. El liderazgo técnico mobile indicado para el proyecto es Maximiliano. El equipo mobile debe validar los requisitos y criterios con gestión, y acordar contratos de API con backend antes de presentar las funciones de red como disponibles.
