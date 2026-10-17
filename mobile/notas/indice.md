# CORON: Bitácora de Aves · Documentación mobile

> [!info] Nota de lectura
> Esta carpeta `mobile/notas/` es la copia en **Markdown** de la documentación mobile, pensada para leerla en **Obsidian**. Las fuentes originales en AsciiDoc siguen en `mobile/docs/modules/ROOT/pages/` y son las que compila el sitio Antora (`npm run docs`). Cuando algo cambie, actualiza primero la fuente `.adoc` y luego esta copia.

CORON: Bitácora de Aves es una aplicación Flutter para registrar observaciones de aves, conservar una colección personal en el dispositivo y compartir aportes con la comunidad.

Esta documentación describe **la solución mobile y su estado actual**. La app habla con el BFF propio (Elixir Phoenix) para cuentas, feed y moderación, en modo local (mock, por defecto) o remoto (`--dart-define=BFF_ACTIVO=true`). Lo que sí queda fuera del alcance declarado es la sincronización entre dispositivos, el conteo de popularidad y el dashboard web; la moderación se atiende desde la propia app.

## Notas

| Nota | Contenido |
|---|---|
| [[prd]] | Alcance, actores, requisitos funcionales, restricciones y criterios de aceptación |
| [[arquitectura]] | Diagramas C4, límites de integración, datos y privacidad |
| [[uat]] | Plan de pruebas manuales, datos de prueba y registro de resultados |
| [[cambios]] | Registro de cambios funcionales y documentales |
| [[contrato-api]] | Extensiones propuestas (y aplicadas) al contrato `birds_apis.yaml` |

## Autenticación actual

El registro y el inicio de sesión ya existen en la app, con mock local por defecto y soporte real cuando el BFF está activo:

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

Este directorio (`mobile/docs/`) es un componente Antora autocontenido dentro de `mobile/`. No tiene playbook ni dependencias propias: el playbook de la raíz lo declara con `start_path: mobile/docs` y es lo único que construye esta rama.

Desde la raíz del repositorio: `npm ci` y `npm run docs`. La salida queda en `build/site/`. Los diagramas C4 se renderizan como SVG con `npm run docs:diagrams`, que invoca a `mobile/docs/scripts/render-diagrams.mjs` (requiere Java o `JAVA_HOME`). También puedes abrir los `.adoc` en VS Code con `AsciiDoc: Open Preview`.

## Relación con el resto del sitio

Los requisitos funcionales del proyecto los publica el equipo en su propio componente (`docs/`), que esta rama no construye. Este componente solo cubre lo móvil.

## Responsabilidad

La documentación de esta carpeta cubre solo mobile. El liderazgo técnico mobile indicado para el proyecto es Maximiliano. El equipo mobile debe validar los requisitos y criterios con gestión, y acordar contratos de API con backend antes de presentar las funciones de red como disponibles.
