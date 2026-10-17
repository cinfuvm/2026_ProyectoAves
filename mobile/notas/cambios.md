# Registro de cambios mobile

> Cambios funcionales y documentales de la aplicación mobile CORON: Bitácora de Aves.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-changes.adoc`.

Este registro resume los cambios de la solución mobile y su documentación que se encuentran en el repositorio. Para el alcance vigente, estados de implementación y criterios de aceptación, consultar el [[prd]] y el [[uat]].

## Funcionalidad de la aplicación

### Autenticación por correo (nuevo)

- **Registro** (`screens/registro_screen.dart`): el formulario pide **usuario**, **correo electrónico**, **contraseña** y su confirmación. Valida longitud de usuario (3–30), formato de correo y mínimo 8 caracteres de contraseña.
- **Inicio de sesión** (`screens/login_screen.dart`): el formulario pide **correo** y **contraseña**; el campo de usuario se eliminó del login y el teclado pasa a modo correo con autocompletado `AutofillHints.emailAddress`.
- **`AuthService`**:
  - `iniciarSesion(correo, password)` envía `POST /api/user/login` con `{email, password}`.
  - `registrarse(user, email, password, confirmacion)` envía `POST /user/signin` con `{user, email, password, confirm_password}`.
  - En modo mock, el registro valida usuario y correo y crea la sesión con el usuario elegido; el login valida el formato del correo y usa ese correo como identificador de la sesión demo.
  - `cerrarSesion()` sigue llamando a `DELETE /api/user/logout` y limpiando la sesión local.
- **Contrato** `birds_apis.yaml`: `LogIn` ahora exige `email` + `password` (antes `user` + `password`); `CrearUsuario` agrega `email` obligatorio; el 409 documenta tanto `usuario_duplicado` como `email_duplicado`.
- **Mock de backend** (`scripts/mock_backend.dart`): lee el identificador desde `user` (registro) o `email` (login) y lo devuelve siempre como `user`.
- **Pruebas**: el caso de integración de login ingresa un correo en el primer campo y llama a `iniciarSesion(correo: ...)`.
- **Docs**: ver [[contrato-api]] (sección 6) y el caso [[uat#UAT-17 - Registro e inicio de sesión en modo mock]].

### Integración con el BFF

- Se creó una capa de red configurable (`config/api_config.dart`) con URL base por `--dart-define=BFF_URL=...` y modo mock por defecto (`MOCK_BFF`/`BFF_ACTIVO`).
- `services/api_client.dart` encapsula HTTP con timeouts, manejo del schema `Error` y cabecera `Authorization: Bearer`.
- `services/fotos_service.dart` define la interfaz `FotosService` (getFotos, subirFoto, reportarFoto) con implementación BFF (`fotos_service_bff.dart`) y mock en memoria (`fotos_service_mock.dart`) con fotos de Aves de Chile por categoría.
- `AuthService` soporta autenticación real contra `POST /user/login` y `POST /user/signin` (JWT guardado en sesión); el mock local se mantiene como modo por defecto.
- El contrato actual solo envía `file` y `categoria` en `POST /images`; la app ya envía además lugar, fecha y comentario anticipando la extensión documentada en [[contrato-api]].
- Los motivos de reporte de la UI se mapean al enum del contrato (`no_es_ave`, `contenido_ofensivo`, `imagen_enganosa`, `derechos_autor`, `otro`).

### Feed comunitario Explorar

- Se agregó la pestaña Explorar (quinta sección) con feed de fotos de otros usuarios paginado y filtrable por categoría general.
- Cada tarjeta muestra autor, lugar y acciones de guardar en colección y reportar.
- La foto se abre en el visor con transición Hero; desde Explorar se puede guardar la foto ajena en la colección local (descarga y copia al almacenamiento privado) o reportarla enviándola al servidor con la cola local como respaldo.
- La colección distingue las fotos de la comunidad con el flag `esDeComunidad`.

### Subida de avistamientos al BFF

- Al registrar un avistamiento propio, la app además intenta subirlo al BFF (`POST /images` multipart con file, categoria, lugar, fecha y comentario) si hay sesión iniciada.
- Si el servidor no responde, la subida queda encolada en `subidas_bff_pendientes_v1` y se reintenta al abrir la app; el guardado local sigue funcionando sin conexión.

### Reportes al servidor

- Los reportes de fotos del feed intentan enviarse con `PUT /images?id=...` usando los motivos del contrato.
- Si el envío falla, el reporte se conserva localmente y se informa al usuario que se enviará después.

### Plataforma iOS

- Se generó el target `ios/` con `flutter create --platforms=ios` y se agregaron los usos de cámara y galería en `Info.plist`.

### Interfaz y navegación

- Se organizó la experiencia en Inicio, Buscar, Explorar, Colección y Perfil, accesibles desde la barra inferior y mediante deslizamientos horizontales.
- La navegación cambia de barra inferior a `NavigationRail` cuando la ventana tiene al menos 600 dp de ancho; el rail puede desplazarse cuando la altura disponible es reducida.
- En apaisado, la cabecera del catálogo es más compacta, las tarjetas presentan imagen y datos en paralelo, y Agregar foto pasa a la barra superior para no cubrir contenido.
- El contenido de las secciones se centra y limita a 1100 dp en ventanas amplias para evitar bloques de texto y tarjetas excesivamente extendidos.
- Se incorporaron los temas claro y oscuro y un estilo visual consistente para tarjetas y controles.
- Se agregaron filtros de Colección en una fila horizontal. El filtro de tipo y el filtro de categoría se combinan; las fotos propias sin categoría se presentan como sin clasificar.
- El catálogo agrupa las especies en categorías generales: Terrestres, Acuáticas, Rapaces, Marinas y Otras.

### Catálogo y colección local

- Se integró el índice de 216 especies y sus fichas desde Aves de Chile, con búsqueda y filtros por categorías generales.
- Buscar muestra las especies y miniaturas del índice mientras se completan las fichas por lotes; las imágenes de la lista se solicitan al acercarse a pantalla.
- Inicio es un panel de bienvenida y resumen, distinto de Buscar: presenta saludo con el nombre de la sesión, contadores de avistamientos y aves guardadas, los últimos avistamientos propios, las fotos más recientes de la comunidad y accesos rápidos a Buscar y Explorar.
- Las descripciones y comentarios largos de las tarjetas aparecen contraídos y se pueden expandir o volver a contraer.
- Se puede guardar y quitar un ave del catálogo desde la colección. La imagen se conserva como archivo privado de la app y los metadatos persisten en el dispositivo.
- El estado de guardado se recupera después de cerrar y volver a abrir la aplicación.
- Las observaciones propias pueden quitarse de la colección; al quitarlas, también se elimina su imagen local.
- Colección presenta estados de carga, vacío, error y reintento para evitar que los fallos de lectura se confundan con una lista sin datos.
- Los filtros de Colección pasan de dos filas de chips a una hoja inferior (*Filtrar colección*) con los tres ejes: `Mostrar`, `Categoría` y un campo de búsqueda sobre nombre, lugar o comentario. Los cambios se aplican en vivo, sin botón de confirmación, y el botón del pie solo cierra.
- Cada opción de la hoja informa cuántos resultados aporta y el botón del pie muestra el total. El botón `Filtrar` de la lista indica cuántos ejes están activos y los filtros en uso aparecen como chips con ✕ para quitarlos por separado. La búsqueda ignora acentos y mayúsculas.
- La lógica de filtrado y conteo vive en `lib/models/filtro_coleccion.dart`, compartida entre la pantalla y la hoja, para que los números no diverjan.

### Registro de observaciones y reportes

- La selección de una foto propia desde cámara o galería abre un formulario para ingresar ave, lugar, fecha y comentario; nombre científico y categoría son opcionales.
- El guardado copia el archivo seleccionado al almacenamiento privado en vez de cargar toda la imagen en memoria. Se muestra progreso durante la operación.
- Los controladores del formulario quedan asociados al ciclo de vida del diálogo para evitar errores al cerrarlo.
- Los motivos de reporte se guardan localmente. El prototipo no los envía al backend ni a un equipo de moderación.

### Fiabilidad de interacción

- Los mensajes de resultado comprueban que el widget siga montado y que exista un `ScaffoldMessenger` antes de mostrarse.
- Los errores de red, persistencia y archivo se comunican como errores; no se presentan como guardados exitosos.
- La colección local utiliza `shared_preferences` para metadatos y `path_provider` para localizar los directorios de imágenes.

## Documentación y build del sitio

- Se agregó al sitio Antora del proyecto la sección de documentación mobile con PRD, arquitectura C4, plan UAT y registro de cambios.
- **Nuevo:** carpeta `docs/mobile/` con la copia en Markdown de esos documentos, pensada para leerla en Obsidian (índice en [[indice]]).
- Los diagramas C4 se mantienen como fuentes PlantUML en `docs/modules/ROOT/partials/`; el build genera SVG localmente con PlantUML y Java.
- El build mobile se integró en el playbook y el package-lock de la raíz del repositorio; no hay un proyecto npm ni un sitio separados.
- El contenido generado en `build/` y `docs/_build/`, las dependencias instaladas y los SVG producidos por el script de build no son fuentes y se excluyen de Git.
- En VS Code se puede leer cada `.adoc` con la extensión AsciiDoc. El sitio completo se compila con `npm ci` y `npm run docs` desde la raíz del repositorio.

### Autocontención del dominio mobile (nuevo)

- La documentación AsciiDoc mobile se movió de `docs/modules/ROOT/pages/` a `mobile/docs/`, que ahora es un componente Antora propio (`bitacora-aves-mobile`) contenido dentro de `mobile/`.
- `docs/` de la raíz quedó como placeholder reservado para el equipo; esta rama solo construye `mobile/docs/` y el playbook apunta con `start_path: mobile/docs` al componente `bitacora-aves-mobile`.
- Los archivos del equipo que había en `docs/` (`antora.yml`, `nav.adoc`, `index.adoc` y `requisitos.adoc`) se retiran de esta rama: mobile deja de editarlos y por eso deja de chocar con las ramas del equipo.
- Se movieron también a `mobile/` los archivos de dominio que estaban en la raíz: `PRODUCT.md`, `DESIGN.md`, `birds_apis.yaml`, `scripts/mock_backend.dart` (ahora en `mobile/scripts/`) y esta carpeta de notas (antes `docs/mobile/`).
- `mobile/docs/` no lleva playbook ni dependencias npm propias: el build es el de la raíz, y `npm run docs:diagrams` invoca a `mobile/docs/scripts/render-diagrams.mjs`.

## Límites confirmados

La autenticación real, la subida de fotos y los reportes dependen del BFF Phoenix que está en desarrollo por el equipo backend; hasta entonces la app opera en modo mock. La app no implementa comentarios, chat, seguimiento de perfiles ni popularidad basada en vistas. Aves de Chile es una fuente externa del catálogo y no la fuente de contribuciones de la comunidad. Consultar [[arquitectura]] para límites de datos y privacidad, y [[contrato-api]] para los cambios pendientes en la API.
