# AGENTS.md

## Proyecto

Monorepo con cuatro componentes:

| Componente | Tecnología | Carpeta |
|---|---|---|
| API REST | Elixir, Phoenix, Ash, PostgreSQL | `backend/aves/` |
| Sitio web y dashboard | Elixir, Phoenix LiveView | `landing/` |
| Aplicación móvil | Flutter (Android e iOS) | `mobile/` |
| Documentación | Antora (AsciiDoc) | `docs/` y `mobile/docs/` |

La app móvil corre en **mock local por defecto** (`ApiConfig.usarMock`); el BFF real se activa con `--dart-define=BFF_ACTIVO=true`.

## Comandos

### Backend

- Base de datos: `docker compose up -d db` (Postgres 16, puerto 5432, usuario/clave `postgres`).
- Preparar: `cd backend/aves && mix deps.get && mix ecto.create && mix ash.migrate && mix run priv/repo/seeds.exs`
- Servidor: `cd backend/aves && mix phx.server` (`http://127.0.0.1:4000`)
- Pruebas + calidad: `cd backend/aves && mix precommit` (incluye `mix test`, 96 tests)
- Un archivo: `cd backend/aves && mix test test/<ruta>_test.exs`

### Landing

- No usa base de datos (sin Ecto).
- Servidor: `cd landing && mix deps.get && PORT=4001 mix phx.server` (`http://127.0.0.1:4001`)
- Pruebas: `cd landing && mix test`

### Móvil

- Instalar deps: `cd mobile && flutter pub get`
- Analizar: `cd mobile && flutter analyze`
- Pruebas: `cd mobile && flutter test` (un archivo: `flutter test test/<ruta>.dart`)
- Integración (dispositivo/emulador): `cd mobile && flutter test integration_test -d <dispositivo> --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000`
- App en mock: `cd mobile && flutter run`
- App contra el backend real: `cd mobile && flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000`

### Documentación

- Raíz: `npm ci && npm run docs` → `build/site/`
- Móvil: `cd mobile && npm ci && npm run docs` → `mobile/build/site/`
- Ambas: `npm run docs:all`

## Gotchas

- `flutter analyze` excluye `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Cualquier test que bombee `AppTheme` debe llamar `setUpAll(prepararGoogleFontsParaTests)` (helper en `mobile/test/ayuda/google_fonts_test_helper.dart`); sin eso GoogleFonts intenta descargar fuentes por red y el test se cuelga.
- Los diagramas C4 requieren Java 21 (`JAVA_HOME` o Adoptium en `Program Files`); `npm run docs` del móvil ejecuta `docs:diagrams` antes de Antora.
- Nueva página de docs generales: crear `.adoc` en `docs/modules/ROOT/pages/` y agregarla a `docs/modules/ROOT/nav.adoc`.
- Nueva página de docs móviles: crear `.adoc` en `mobile/docs/modules/ROOT/pages/` y agregarla a `mobile/docs/modules/ROOT/nav.adoc`.
- No versionar `build/`, `node_modules/`, `_build/`, `deps/`, `.dart_tool/`.
- Rama activa de desarrollo: `main`. Diseño/tokens móviles: `mobile/DESIGN.md`.
