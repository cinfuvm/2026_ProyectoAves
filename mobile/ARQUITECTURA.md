# Arquitectura y estructura de `mobile/`

Aplicación Flutter **CORON: Bitácora de Aves**. Este documento describe la organización del código, el flujo de datos y las decisiones de arquitectura del proyecto móvil.

---

## 1. Visión general

La app es un cliente Flutter (Android/iOS/Windows) que funciona **offline-first**: el catálogo de aves se descarga desde la web de *Aves de Chile*, mientras que la colección personal, los avistamientos propios, las fotos guardadas y los reportes se conservan localmente en el dispositivo. La autenticación y el feed social funcionan en **modo mock por defecto** y pueden conectarse a un BFF real mediante flags de compilación.

No hay backend en el repositorio: toda la lógica de persistencia local y de mock vive dentro de `mobile/`.

---

## 2. Entrada y tema

- `lib/main.dart`
  - Inicializa `WidgetsFlutterBinding`.
  - Lee la preferencia de modo oscuro desde `SharedPreferences`.
  - Arranca `BitacoraAvesApp`, que expone `MaterialApp` con `AppTheme.claro()` / `AppTheme.oscuro()` y `HomeScreen` como pantalla inicial.
- `lib/theme/app_theme.dart`
  - Define la paleta CORON (violeta cordillera, sol de mediodía, etc.) y la tipografía (Fraunces para títulos, Roboto para cuerpo) usando GoogleFonts.
  - Provee variantes claro y oscuro.

---

## 3. Navegación principal

- `lib/screens/home_screen.dart` es el **contenedor raíz** y coordinador de la app:
  - Usa un `PageController` para navegar entre secciones sin perder estado.
  - Barra de navegación inferior (Inicio, Buscar, Explorar, Colección, Perfil).
  - Mantiene el estado global: catálogo cargado, colección, avistamientos propios, reportes, feed de inicio, sesión, subidas pendientes.
  - Coordina la captura de fotos (`ImagePicker`), el formulario de avistamiento y el reintento de subidas pendientes.
- Pantallas de sección:
  - `inicio_screen.dart`: panel de bienvenida, contadores, últimos avistamientos, feed reciente, accesos rápidos.
  - `catalogo_screen.dart`: catálogo de 216 especies con filtros por nombre, científico, descripción, palabras clave y categorías.
  - `explorar_screen.dart`: feed de fotos de la comunidad, guardado en colección personal y reporte de fotos.
  - `coleccion_screen.dart`: aves guardadas del catálogo y avistamientos propios.
  - `perfil_screen.dart`: perfil con sesión mock o real.
- Autenticación: `login_screen.dart`, `registro_screen.dart`.
- Moderación: `reportes_screen.dart`.

---

## 4. Capas del código

### 4.1 Configuración
- `lib/config/api_config.dart`
  - `BFF_ACTIVO` (default `false`) activa el BFF real.
  - `MOCK_BFF` fuerza el mock aunque el BFF esté activo.
  - `BFF_URL` permite apuntar a un host distinto (por defecto `10.0.2.2:4000` en Android).
  - `usarMock` decide si la app usa servicios mock o BFF.

### 4.2 Modelos (`lib/models/`)
- `ave_catalogo.dart`: especie del catálogo (nombre común, científico, categoría, imágenes, descripción).
- `avistamiento_propio.dart`: observación registrada por el usuario (nombre, científico, categoría, lugar, fecha, comentario, ruta de imagen).
- `categoria_ave.dart`: categorías generales (Terrestres, Acuáticas, Rapaces, Marinas, Otras) y normalización.
- `filtro_coleccion.dart`: filtros de la colección personal.
- `foto_guardada.dart`, `foto_publica.dart`: fotos de la comunidad y guardadas.
- `reporte_foto.dart`, `reporte_moderacion.dart`: reportes de moderación.
- `usuario.dart`: sesión de usuario.

### 4.3 Servicios (`lib/services/`)
- `api_client.dart`: cliente HTTP base, timeouts y parseo de respuestas.
- `auth_service.dart`: autenticación mock o real (`POST /user/login`, `POST /user/signin`, JWT).
- `catalogo_aves_service.dart`: descarga y parseo del índice y fichas JSON de Aves de Chile.
- `coleccion_local_service.dart`: persistencia de imágenes y datos en el dispositivo (`path_provider` + `shared_preferences`).
- `fotos_service.dart`: interfaz común para el feed de fotos.
- `fotos_service_mock.dart`: implementación mock con datos de ejemplo.
- `fotos_service_bff.dart`: implementación contra el BFF real.
- `subidas_pendientes_service.dart`: cola de reintentos para avistamientos y reportes que fallaron por falta de conexión.

### 4.4 Widgets reutilizables (`lib/widgets/`)
- `tarjeta_avistamiento.dart`, `texto_expandible.dart`, `visor_foto.dart`, `boton_reportar.dart`, `dialogo_reporte.dart`, `formulario_avistamiento_dialog.dart`, `hoja_filtros_coleccion.dart`, `logo_marca.dart`, `aparicion_diferida.dart`.

---

## 5. Flujo de datos

1. **Inicio**: `main()` carga preferencias → `HomeScreen` inicializa servicios y carga catálogo, colección, sesión y feed.
2. **Catálogo**: `CatalogoAvesService` descarga el índice y las fichas desde Aves de Chile; se agrupan en categorías generales.
3. **Registro de avistamiento**: el usuario selecciona una foto → `FormularioAvistamientoDialog` captura datos → se guarda localmente (`ColeccionLocalService`) y, si hay sesión, se intenta subir al BFF; si falla, se encola en `SubidasPendientesService`.
4. **Colección**: se leen desde almacenamiento local; se pueden filtrar por nombre, científico, categoría, etc.
5. **Explorar**: `FotosService` (mock o BFF) entrega el feed; el usuario puede guardar fotos en su colección o reportarlas.
6. **Tema**: el modo oscuro se persiste en `SharedPreferences` y se aplica globalmente.

---

## 6. Persistencia y offline

- **Imágenes**: se copian al directorio de la app (`path_provider`) para poder verse sin conexión.
- **Datos**: JSON en `SharedPreferences` (colección, avistamientos, reportes, fotos guardadas).
- **Sin conexión**: el catálogo y las imágenes del feed requieren Internet; el resto funciona offline.
- **Reintentos**: las subidas fallidas quedan encoladas y se reintentan al abrir la app o tener conectividad.

---

## 7. Backend / BFF

- Por defecto la app corre en **mock local** (`ApiConfig.usarMock == true`); no requiere servidor.
- Para usar el BFF real:
  ```bash
  flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000
  ```
- `mobile/scripts/mock_backend.dart` simula las 4 rutas de autenticación (`/api/user/signin`, `/api/user/login`, `/api/user/me`, `/api/user/logout`) sin Elixir ni PostgreSQL.
- El contrato REST está en `mobile/birds_apis.yaml`.

---

## 8. Testing

- `mobile/test/`: pruebas unitarias y de widgets (modelos, pantallas, widgets, tema).
  - Convención: cualquier test que bombee `AppTheme` debe llamar `setUpAll(prepararGoogleFontsParaTests)` (helper en `test/ayuda/google_fonts_test_helper.dart`) para desactivar la descarga de fuentes por red.
- `mobile/integration_test/bff_e2e_test.dart`: prueba E2E contra el BFF real en un dispositivo/emulador; se salta automáticamente si el BFF no está disponible.
- Verificación estándar:
  ```bash
  cd mobile
  flutter analyze
  flutter test
  ```

---

## 9. Documentación

- `mobile/docs/` es un componente Antora autocontenido: PRD, arquitectura C4 (PlantUML), plan de pruebas UAT y registro de cambios.
- El build se ejecuta desde `mobile/`:
  ```bash
  cd mobile
  npm ci
  npm run docs
  ```
- Salida: `mobile/build/site/index.html`.
- Los diagramas C4 requieren Java 21 (`JAVA_HOME` o Adoptium en `Program Files`).
- Para agregar una página: crear `.adoc` en `mobile/docs/modules/ROOT/pages/` y registrarla en `mobile/docs/modules/ROOT/nav.adoc`.

---

## 10. Assets y recursos

- `mobile/assets/`: `logo_isotipo.png`, `logo_isotipo_pink.png`.
- `mobile/coron-logos/`: isotipos de la marca.
- Identidad visual y tokens de diseño: `mobile/DESIGN.md`.
- Configuración de íconos de lanzador: `mobile/flutter_launcher_icons.yaml`.
```|<|start|>write to=assistant<|channel|>analysis<|message|>Created file successfully: mobile/ARQUITECTURA.md