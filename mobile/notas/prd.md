# PRD · Aplicación mobile CORON: Bitácora de Aves

> Requisitos de producto, alcance y criterios de aceptación para la solución mobile Flutter CORON: Bitácora de Aves.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-prd.adoc`.

## 1. Resumen de la solución

CORON: Bitácora de Aves Mobile es una aplicación Flutter para que una persona registre encuentros con aves, guarde imágenes y consulte sus registros desde una interfaz móvil. El valor principal de la versión objetivo es facilitar que la comunidad aporte observaciones e imágenes, y que esas contribuciones se compartan con moderación a través del backend del proyecto.

El repositorio implementa una **aplicación mobile** que trabaja contra dos fuentes distintas: el catálogo externo de [Aves de Chile](https://uvm.neocities.org/aves/) para las fichas de especies, y el BFF propio (Elixir Phoenix) para cuentas, publicación de imágenes, feed comunitario y reportes. El BFF se consume en dos modos: **local** (mock, el valor por defecto) y **remoto** (`--dart-define=BFF_ACTIVO=true`), de modo que la app arranca sin servidor. No hay sincronización entre dispositivos ni conteo de popularidad. El catálogo externo no debe confundirse con la fuente del contenido comunitario.

En autenticación, la app ya incluye el flujo de **registro (usuario + correo + contraseña)** y **login (correo + contraseña)**, con sesión mock por defecto y llamadas reales al BFF en modo remoto: ver [[cambios]] y [[contrato-api]].

### Problema y oportunidad

Las observaciones de aves suelen quedar dispersas entre fotografías y notas. Una bitácora móvil puede asociar una imagen con especie, lugar, fecha y comentario, y ofrecer una forma sencilla de revisar el historial. La contribución comunitaria necesita moderación para ser compartida de forma segura; por eso el envío de reportes forma parte del alcance actual y no de un entregable futuro.

### Usuarios y actores

- **Observador/a de aves:** registra y consulta sus observaciones, explora el feed comunitario, administra su colección local y se autentica con una cuenta.
- **Moderador/a:** entra con rol `admin` y atiende los reportes desde la pantalla de moderación de la app.
- **Equipo de gestión:** requiere reportes utilizables y trazables; se envían al BFF con su estado.
- **Backend:** proveedor de identidad, API y almacenamiento compartido; su contrato está en `birds_apis.yaml` y aún puede cambiar.
- **Dashboard:** herramienta web para gestión y moderación; fuera del alcance de esta solución mobile.

### Objetivos de producto

1. Permitir registrar una observación propia con fotografía y datos contextuales.
2. Mantener los registros propios accesibles después de reiniciar la aplicación.
3. Permitir explorar y filtrar los registros de la colección.
4. Facilitar el descubrimiento de especies con el catálogo externo.
5. Compartir aportes con la comunidad y atender reportes de moderación a través del BFF.

### Fuera de alcance del prototipo actual

- Sincronización, copias de seguridad o migración de registros entre dispositivos.
- Dashboard web de moderación y gestión; la moderación se atiende desde la app.
- Conteo de vistas, ranking de popularidad, comentarios, chat o seguimiento de perfiles.
- Taxonomía definitiva administrada por el backend.

## 2. Requisitos funcionales

Los estados indican la implementación observada en el repositorio al redactar este documento: *Implementado local* significa que la función opera en el dispositivo; *Catálogo externo* indica una dependencia de Aves de Chile; *Implementado contra BFF* funciona en modo mock por defecto y contra el servidor con `--dart-define=BFF_ACTIVO=true`; *Pendiente de integración* no debe presentarse como función ya disponible.

| ID | Requisito | Estado | Prioridad |
|---|---|---|---|
| MOB-FR-01 | La app presenta navegación entre Inicio, Buscar, Explorar, Colección y Perfil. | Implementado local | Alta |
| MOB-FR-02 | La app muestra el catálogo externo de Aves de Chile con imagen, descripción, nombre científico y enlace a la ficha. | Catálogo externo: Aves de Chile | Media |
| MOB-FR-03 | La persona puede buscar especies por nombre común, nombre científico, descripción o palabras clave, y filtrar por categorías generales (Terrestres, Acuáticas, Rapaces, Marinas y Otras). | Implementado sobre catálogo externo | Media |
| MOB-FR-04 | La persona puede guardar y quitar una especie del catálogo en su colección local. | Implementado local | Media |
| MOB-FR-05 | La persona puede seleccionar una imagen de cámara o galería y registrar nombre del ave, lugar, fecha y comentario; nombre científico y categoría son opcionales. | Implementado local; sujeto a disponibilidad de permisos y plataforma | Alta |
| MOB-FR-06 | La app conserva las imágenes y metadatos de los registros propios localmente y los vuelve a cargar al iniciar. | Implementado local; sin sincronización | Alta |
| MOB-FR-07 | La persona puede filtrar la colección por tipo de registro, por categoría y por texto libre sobre nombre, científico, lugar y comentario; los filtros se aplican en conjunto. | Implementado local | Media |
| MOB-FR-08 | La persona puede quitar un registro propio o un ave guardada de la colección local. | Implementado local | Alta |
| MOB-FR-09 | La persona puede reportar una imagen seleccionando uno o más motivos y, opcionalmente, detallar Otro. El reporte siempre se conserva en el dispositivo y, si la foto pertenece al feed remoto, se envía además al BFF. | Implementado local; envío al BFF para fotos del feed | Baja |
| MOB-FR-10 | La app publica observaciones propias y obtiene los aportes de otros usuarios en el feed *Explorar*, con paginación. | Implementado contra BFF; mock por defecto | Alta para producto objetivo |
| MOB-FR-11 | La app envía reportes al servicio de moderación y presenta su estado desde la pantalla de moderación. | Implementado contra BFF; acceso restringido a rol `admin` | Media |
| MOB-FR-12 | La persona puede crear una cuenta indicando usuario, correo y contraseña, e iniciar sesión con correo y contraseña. | Implementado local (mock); contra BFF con `--dart-define=BFF_ACTIVO=true` | Alta |

### Requisitos de experiencia y accesibilidad

- Las acciones de guardar, quitar y reportar deben informar claramente el resultado.
- Las operaciones de guardado deben indicar progreso y no bloquear la interacción sin explicación.
- Los errores de permisos, almacenamiento o red deben ofrecer mensajes comprensibles y no simular éxito.
- Los filtros deben ser distinguibles visualmente, mantener su selección durante la sesión y poder combinarse.
- La interfaz debe adaptarse a temas claro y oscuro, y a anchos de pantalla habituales.
- La imagen no debe ser la única fuente de información: nombre, lugar, fecha y comentario deben seguir disponibles como texto.
- Los formularios de registro y login deben validar antes de enviar y mostrar el error del servidor sin perder lo escrito.

## 3. Restricciones y dependencias

### Restricciones técnicas actuales

- Aplicación desarrollada en Flutter y Dart; manifiesto con mínimo de SDK Dart `^3.13.4`.
- Paquetes principales: `image_picker`, `http`, `http_parser`, `url_launcher`, `path_provider`, `shared_preferences` y `google_fonts` (tipografía del tema).
- La colección se guarda en preferencias locales y las imágenes en directorios de documentos de la app.
- La consulta del catálogo depende de conectividad para obtener el índice y las fichas JSON de Aves de Chile; las fichas se solicitan en lotes limitados.
- Destinos de compilación configurados: Android e iOS, además de Windows. Android y Windows tienen build verificado; iOS lleva solo el scaffolding y requiere validación específica antes de declararse soportado.
- La app arranca en modo mock; el BFF real solo se activa en tiempo de compilación con `--dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=...`.
- No hay almacenamiento remoto propio: las imágenes del feed viven en el BFF, no en un almacenamiento gestionado por mobile.

### Dependencias y acuerdos entre equipos

- Backend confirma autenticación, contratos, validación, límites de carga, almacenamiento de imágenes y errores de API; el cliente ya implementa sus endpoints pero el contrato puede cambiar.
- Dashboard y gestión deben acordar motivos, estados y trazabilidad de reportes/moderación. Hoy la app usa los estados `abierto`, `revisado` y `descartado`, que no coinciden con el enum `recibido|en_revision|resuelto|descartado` del contrato.
- El equipo mobile debe mantener esos contratos acordados como requisitos y pruebas antes de cada integración.
- DevOps mantiene la publicación de documentación HTML; mobile mantiene sus fuentes AsciiDoc y diagramas.
- El catálogo de Aves de Chile contiene información e imágenes externas; revisar los créditos y condiciones de uso publicados por la fuente antes de reutilizar sus recursos.

## 4. Criterios de aceptación

La versión prototipo mobile se acepta cuando se cumplen los criterios `MOB-AC-*`. Los requisitos que dependen de servidor se verifican en modo remoto una vez aprobados los contratos de integración.

| ID | Criterio verificable | Casos UAT |
|---|---|---|
| MOB-AC-01 | La app inicia y permite navegar por sus cinco secciones sin errores de runtime. | [[uat#UAT-01 - Arranque y navegación]], [[uat#UAT-02 - Estado inicial y colección vacía]] |
| MOB-AC-02 | Con conectividad, carga el índice y las fichas del catálogo externo; una falla de red ofrece reintento y no cierra la app. | [[uat#UAT-03 - Catálogo y pérdida de conexión]] |
| MOB-AC-03 | La búsqueda y el filtro por categoría general reducen los resultados correctamente. | [[uat#UAT-04 - Buscar y filtrar especies del catálogo]] |
| MOB-AC-04 | Un ave del catálogo guardada aparece en Colección, sobrevive al reinicio y puede quitarse. | [[uat#UAT-05 - Guardar y quitar ave del catálogo]] |
| MOB-AC-05 | Un registro propio con imagen, nombre, lugar, fecha y comentario aparece en Colección, sobrevive al reinicio y puede quitarse. | [[uat#UAT-06 - Registrar observación propia desde galería]], [[uat#UAT-07 - Persistencia y eliminación de observación propia]] |
| MOB-AC-06 | Los filtros Tipo, Categoría y texto se combinan y muestran solo los registros coincidentes. | [[uat#UAT-08 - Filtros combinados de Colección]] |
| MOB-AC-07 | Un reporte seleccionado se conserva localmente y, si la foto viene del feed remoto, se envía al BFF y aparece en moderación. | [[uat#UAT-09 - Reporte local, no envío remoto]] |
| MOB-AC-08 | Cancelar la selección, denegar permisos o cancelar formularios no crea registros parciales ni produce una pantalla de error. | [[uat#UAT-10 - Cancelación y permisos de imagen]] |
| MOB-AC-09 | En caso de error de almacenamiento, la app comunica el fallo sin indicar que el registro se guardó correctamente. | [[uat#UAT-11 - Fallo de almacenamiento y archivo ausente]] |
| MOB-AC-10 | La sincronización entre dispositivos y el conteo de popularidad permanecen identificados como no disponibles; el resto de capacidades remotas se declara según el modo (mock o BFF) activo. | Revisión de alcance; [[uat#UAT-12 - Verificación de límites del alcance]] |
| MOB-AC-11 | El registro exige usuario, correo y contraseña válidos, y el login solo acepta correo y contraseña; los campos inválidos se rechazan antes de enviar. | [[uat#UAT-16 - Autenticación real (cuando el BFF esté disponible)]], [[uat#UAT-17 - Registro e inicio de sesión en modo mock]] |

## 5. Flujo principal de registro

1. La persona toca *Agregar foto*.
2. Selecciona cámara o galería y elige una imagen.
3. Completa nombre del ave, lugar, fecha y comentario; puede cancelar sin guardar.
4. La app copia la imagen a almacenamiento privado y guarda los metadatos localmente.
5. La app muestra el nuevo registro en Colección y confirma el guardado.
6. La persona puede filtrar o quitar ese registro.

Si no hay conectividad, la publicación al BFF queda en la cola de subidas pendientes y se reintenta después; el registro local existe desde el primer momento.

La implementación del almacenamiento local y sus límites se muestra en [[arquitectura]]. Los pasos de aceptación se describen en [[uat]].

### Flujo de autenticación

1. Desde **Perfil**, la persona toca *Iniciar sesión*.
2. Ingresa **correo** y **contraseña**; el formulario valida el formato antes de enviar.
3. Con sesión mock se crea la sesión local; con el BFF se llama a `POST /user/login` (bajo el prefijo `/api/`) y se guarda el JWT.
4. Si no tiene cuenta, toca *¿No tienes cuenta? Regístrate* e ingresa **usuario**, **correo**, **contraseña** y su confirmación (`POST /user/signin`).
5. Al volver al perfil aparece el identificador público y la opción *Cerrar sesión*.

## 6. Recursos de UX

La interfaz contiene una barra de navegación (rail en pantallas anchas, barra inferior en pantallas estrechas), tarjetas de imagen y formularios de registro/reporte. Los filtros de Colección viven en una hoja modal y combinan tres ejes: *Tipo* (Todo, Aves guardadas, Mis avistamientos), *Categoría* y un campo de *texto libre*; los ejes activos se muestran como chips removibles. El sistema visual sí es definitivo: la guía de marca de CORON y la paleta `PaletaCoron` están documentadas en `mobile/DESIGN.md` y aplicadas en `lib/theme/app_theme.dart`.

No se incluye un enlace a un prototipo externo aprobado. Si el equipo adopta un diseño/wireframe oficial, agregarlo aquí y registrar su versión para mantener trazabilidad entre diseño, implementación y UAT.

## 7. Casos borde y riesgos

- Permiso de cámara/galería denegado o cancelación del selector.
- Android finaliza la actividad mientras el selector nativo está abierto; la recuperación de datos perdidos debe revisarse en dispositivo.
- Archivo grande, extensión inesperada, archivo inaccesible o espacio insuficiente.
- La app se cierra durante la copia o antes de persistir los metadatos.
- Una ruta local deja de existir; la interfaz debe mostrar estado de imagen faltante y conservar información textual útil.
- Aves de Chile no responde, limita solicitudes, devuelve formato inesperado o una ficha sin imagen.
- El nombre de especie escrito por una persona no coincide con el catálogo y queda como `Sin clasificar`, salvo que la categoría se indique manualmente.
- Datos locales corruptos o versión futura del esquema requieren manejo explícito; no borrar datos automáticamente.
- Quitar una entrada y fallar al borrar el archivo debe distinguir el éxito parcial del borrado completo.
- Dos operaciones de guardado simultáneas no deben crear estados inconsistentes.
- Escalado de fuente, teclado visible, pantalla pequeña y tema oscuro pueden provocar overflow.
- El BFF no responde o devuelve un error; la cola de subidas pendientes no debe duplicar aportes ni perder el registro local.
- El contrato del BFF cambia de forma incompatible; el modo mock permite seguir verificando la app sin servidor.
- Registro con correo o usuario ya existente (409) y credenciales inválidas (401): el mensaje debe ser claro y no borrar lo escrito.

## 8. Dependencias de negocio

- Gestión valida alcance, prioridad y definición de listo.
- Liderazgo mobile indicado: Maximiliano.
- Backend confirma identidad, contratos y políticas; el cliente ya los consume pero la aprobación formal sigue pendiente.
- Gestión/moderación confirma taxonomía de categorías, reportes y proceso de atención.
- DevOps publica el sitio HTML de Antora desde las fuentes versionadas.

## 9. Trazabilidad de implementación

| Flujo | Pantalla | Servicio |
|---|---|---|
| Navegación y estado (las cinco secciones) | `lib/screens/home_screen.dart`, `lib/main.dart` | — |
| Catálogo y búsqueda | `lib/screens/catalogo_screen.dart` | `lib/services/catalogo_aves_service.dart` |
| Colección local | `lib/screens/coleccion_screen.dart` | `lib/services/coleccion_local_service.dart` |
| Feed Explorar | `lib/screens/explorar_screen.dart` | `lib/services/fotos_service.dart` |
| Registro de observación | `lib/screens/coleccion_screen.dart` (diálogo) | `lib/services/fotos_service.dart` |
| Login y registro | `lib/screens/login_screen.dart`, `lib/screens/registro_screen.dart` | `lib/services/auth_service.dart` |
| Subida al BFF y cola de pendientes | — | `lib/services/subidas_pendientes_service.dart` |
| Moderación de reportes | `lib/screens/reportes_screen.dart` | `lib/services/fotos_service.dart` |
| Configuración de red | — | `lib/config/api_config.dart`, `lib/services/api_client.dart` |

La información de estado de producto debe actualizarse cuando cambien las capacidades mobile.

## Referencia metodológica

Estructura basada en la guía de [Product Requirements Document (PRD)](https://elixircl.github.io/elixir-fullstack/swe/prd.html) del equipo.
