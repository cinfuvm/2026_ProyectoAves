# AGENTS.md

## Proyecto
- App Flutter en `mobile/` (CORON: Bitácora de Aves). La raíz solo contiene herramientas: sitio de documentación Antora y verificación de la app.
- Backend y BFF se eliminaron del repo; la app corre en **mock local por defecto** (`ApiConfig.usarMock`).

## Comandos
- Instalar deps: `cd mobile && flutter pub get`
- Analizar: `cd mobile && flutter analyze`
- Tests: `cd mobile && flutter test` (un archivo: `flutter test test/<ruta>.dart`)
- Verificación completa (desde la raíz): `npm run test:mobile` (= analyze + test)
- Todo + docs: `npm run test:all`
- App en mock: `cd mobile && flutter run`
- App contra BFF real: `cd mobile && flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000`
- Mock del backend Phoenix: `cd mobile && dart scripts/mock_backend.dart` (puerto 4001 por defecto; `--port N`)
- Integración (dispositivo/emulador): `cd mobile && flutter test integration_test -d <dispositivo> --dart-define=BFF_ACTIVO=true`
- Docs: `npm ci` (Node 18+) y `npm run docs`; salida en `build/site/index.html`

## Gotchas
- `flutter analyze` excluye `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Cualquier test que bombee `AppTheme` debe llamar `setUpAll(prepararGoogleFontsParaTests)` (helper en `mobile/test/ayuda/google_fonts_test_helper.dart`); sin eso GoogleFonts intenta descargar fuentes por red y el test se cuelga.
- Los diagramas C4 requieren Java 21 (`JAVA_HOME` o Adoptium en `Program Files`); `npm run docs` ejecuta `docs:diagrams` antes de Antora.
- Nueva página de docs: crear `.adoc` en `mobile/docs/modules/ROOT/pages/` y agregarla a `mobile/docs/modules/ROOT/nav.adoc`.
- `docs/` (raíz) y `landing/` son placeholders; la documentación real vive en `mobile/docs/`.
- No versionar `build/`, `node_modules/`, `.dart_tool/`.
- Rama activa de desarrollo: `mobile_dev`. Diseño/tokens: `mobile/DESIGN.md`.