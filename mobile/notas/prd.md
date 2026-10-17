# PRD · Aplicación mobile CORON: Bitácora de Aves

> Requisitos de producto, alcance y criterios de aceptación para la solución mobile Flutter.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-prd.adoc`.

## 1. Resumen de la solución

CORON: Bitácora de Aves Mobile es una aplicación Flutter para que una persona registre encuentros con aves, guarde imágenes y consulte sus registros desde una interfaz móvil. El valor principal de la versión objetivo es facilitar que la comunidad aporte observaciones e imágenes, y que esas contribuciones puedan integrarse posteriormente con un backend y herramientas de gestión.

El repositorio implementa un **prototipo mobile local**. Permite guardar fotos y sus datos en el dispositivo y explorar el catálogo de 216 especies consultado desde [Aves de Chile](https://uvm.neocities.org/aves/). No hay actualmente feed remoto de aportes comunitarios, API propia, sincronización entre dispositivos, envío real de reportes a moderación ni conteo de popularidad. El catálogo externo no debe confundirse con la fuente objetivo del contenido comunitario.

En autenticación, la app ya incluye el flujo de **registro (usuario + correo + contraseña)** y **login (correo + contraseña)** funcionando en modo mock local, con llamadas reales a `POST /user/signin` y `POST /user/login` cuando el BFF esté disponible: ver [[cambios]] y [[contrato-api]]. Mientras no exista backend, no hay cuentas persistentes en servidor.

### Problema y oportunidad

Las observaciones de aves suelen quedar dispersas entre fotografías y notas. Una bitácora móvil puede asociar una imagen con especie, lugar, fecha y comentario, y ofrecer una forma sencilla de revisar el historial. A futuro, la contribución comunitaria necesita servicios de backend y procesos de moderación para ser compartida de forma segura.

### Usuarios y actores

- **Observador/a de aves:** registra y consulta sus observaciones, explora especies y administra su colección local.
- **Equipo de gestión y moderación:** requiere reportes utilizables y trazables; el prototipo solo almacena reportes localmente y no satisface el flujo remoto.
- **Backend:** futuro proveedor de identidad, API, almacenamiento compartido y reglas de negocio.
- **Dashboard:** futura herramienta web para gestión y moderación; fuera del alcance de esta solución mobile.

### Objetivos de producto

1. Permitir registrar una observación propia con fotografía y datos contextuales.
2. Mantener los registros propios accesibles después de reiniciar la aplicación.
3. Permitir explorar y filtrar los registros de la colección.
4. Facilitar el descubrimiento de especies con el catálogo externo mientras se define el contrato de datos definitivo.
5. Preparar una arquitectura mobile que pueda integrarse con la API y los procesos de moderación del proyecto.

### Fuera de alcance del prototipo actual

- Cuentas persistentes en servidor y permisos por rol (el registro/login local opera en mock; la identidad real depende del BFF).
- Publicación o consulta de fotos aportadas por otros usuarios contra servidor.
- Sincronización, copias de seguridad o migración de registros entre dispositivos.
- Envío de reportes o moderación desde un dashboard.
- Conteo de vistas, ranking de popularidad, comentarios, chat o seguimiento de perfiles.
- Taxonomía definitiva administrada por el backend.

## 2. Requisitos funcionales

Los estados indican la implementación observada en el repositorio al redactar este documento: *Implementado local* significa que la función opera en el dispositivo; *Catálogo externo* indica una dependencia de Aves de Chile; *Pendiente de integración* no debe presentarse como función ya disponible.

| ID | Requisito | Estado | Prioridad |
|---|---|---|---|
| MOB-FR-01 | La app presenta navegación entre Inicio, Buscar, Explorar, Colección y Perfil. | Implementado local | Alta |
| MOB-FR-02 | La app muestra el catálogo externo de Aves de Chile con imagen, descripción, nombre científico y enlace a la ficha. | Catálogo externo: Aves de Chile | Media |
| MOB-FR-03 | La persona puede buscar especies por nombre común, nombre científico, descripción o palabras clave, y filtrar por categorías generales (Terrestres, Acuáticas, Rapaces, Marinas y Otras). | Implementado sobre catálogo externo | Media |
| MOB-FR-04 | La persona puede guardar y quitar una especie del catálogo en su colección local. | Implementado local | Media |
| MOB-FR-05 | La persona puede seleccionar una imagen de cámara o galería y registrar nombre del ave, lugar, fecha y comentario; nombre científico y categoría son opcionales. | Implementado local; sujeto a disponibilidad de permisos y plataforma | Alta |
| MOB-FR-06 | La app conserva las imágenes y metadatos de los registros propios localmente y los vuelve a cargar al iniciar. | Implementado local; sin sincronización | Alta |
| MOB-FR-07 | La persona puede filtrar la colección por tipo de registro, categoría y un texto de búsqueda sobre nombre, lugar o comentario; los filtros se aplican en conjunto y cada opción informa cuántos resultados aporta. | Implementado local | Media |
| MOB-FR-08 | La persona puede quitar un registro propio o un ave guardada de la colección local. | Implementado local | Alta |
| MOB-FR-09 | La persona puede reportar una imagen seleccionando uno o más motivos y, opcionalmente, detallar Otro. | Solo persistencia local; no se envía a moderación | Baja |
| MOB-FR-10 | La app puede publicar observaciones propias y obtener aportes de otros usuarios mediante el backend acordado. | Pendiente de integración; requiere contrato y API | Alta para producto objetivo |
| MOB-FR-11 | La app puede enviar reportes al servicio de moderación y presentar su estado. | Pendiente de integración | Media |
| MOB-FR-12 | La persona puede crear una cuenta indicando usuario, correo y contraseña, e iniciar sesión con correo y contraseña. | Implementado local (mock); contra BFF pendiente de integración | Alta |

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
- Paquetes principales: `image_picker`, `http`, `url_launcher`, `path_provider` y `shared_preferences`.
- La colección se guarda en preferencias locales y las imágenes en directorios de documentos de la app.
- La consulta del catálogo depende de conectividad para obtener el índice y las fichas JSON de Aves de Chile; las fichas se solicitan en lotes limitados.
- El README identifica Android como plataforma actualmente configurada; Android e iOS son objetivo de entrega, pero iOS necesita validación específica antes de declararse soportado.
- No hay servicio de API propio conectado ni almacenamiento remoto; la sesión autenticada vive en `SharedPreferences` (`session_usuario_v1`).

### Dependencias y acuerdos entre equipos

- Backend debe acordar autenticación (registro con usuario + correo y login por correo), contratos, validación, límites de carga, almacenamiento de imágenes y errores de API.
- Dashboard y gestión deben acordar motivos, estados y trazabilidad de reportes/moderación.
- El equipo mobile debe convertir esos contratos acordados en requisitos y pruebas antes de integrar.
- DevOps mantiene la publicación de documentación HTML; mobile mantiene sus fuentes AsciiDoc y diagramas.
- El catálogo de Aves de Chile contiene información e imágenes externas; revisar los créditos y condiciones de uso publicados por la fuente antes de reutilizar sus recursos.

## 4. Criterios de aceptación

La versión prototipo mobile se acepta cuando se cumplen los criterios `MOB-AC-*`. Los requisitos que necesitan servidor se aceptan solo en una entrega posterior una vez aprobados los contratos de integración.

| ID | Criterio verificable | Casos UAT |
|---|---|---|
| MOB-AC-01 | La app inicia y permite navegar por sus secciones sin errores de runtime. | [[uat#UAT-01 - Arranque y navegación]], [[uat#UAT-02 - Estado inicial y colección vacía]] |
| MOB-AC-02 | Con conectividad, carga el índice y las fichas del catálogo externo; una falla de red ofrece reintento y no cierra la app. | [[uat#UAT-03 - Catálogo y pérdida de conexión]] |
| MOB-AC-03 | La búsqueda y el filtro por categoría general reducen los resultados correctamente. | [[uat#UAT-04 - Buscar y filtrar especies del catálogo]] |
| MOB-AC-04 | Un ave del catálogo guardada aparece en Colección, sobrevive al reinicio y puede quitarse. | [[uat#UAT-05 - Guardar y quitar ave del catálogo]] |
| MOB-AC-05 | Un registro propio con imagen, nombre, lugar, fecha y comentario aparece en Colección, sobrevive al reinicio y puede quitarse. | [[uat#UAT-06 - Registrar observación propia desde galería]], [[uat#UAT-07 - Persistencia y eliminación de observación propia]] |
| MOB-AC-06 | Los filtros Tipo, Categoría y Búsqueda se combinan y muestran solo los registros coincidentes, con sus conteos. | [[uat#UAT-08 - Filtros combinados de Colección]] |
| MOB-AC-07 | Un reporte seleccionado se conserva localmente, e informa que aún no se envió a moderación. | [[uat#UAT-09 - Reporte local, no envío remoto]] |
| MOB-AC-08 | Cancelar la selección, denegar permisos o cancelar formularios no crea registros parciales ni produce una pantalla de error. | [[uat#UAT-10 - Cancelación y permisos de imagen]] |
| MOB-AC-09 | En caso de error de almacenamiento, la app comunica el fallo sin indicar que el registro se guardó correctamente. | [[uat#UAT-11 - Fallo de almacenamiento y archivo ausente]] |
| MOB-AC-10 | Catálogo, reportes remotos, cuentas y sincronización permanecen identificados como no disponibles mientras no exista integración backend. | Revisión de alcance; [[uat#UAT-12 - Verificación de límites del prototipo]] |
| MOB-AC-11 | El registro exige usuario, correo y contraseña válidos, y el login solo acepta correo y contraseña; los campos inválidos se rechazan antes de enviar. | [[uat#UAT-16 - Autenticación real (cuando el BFF esté disponible)]], [[uat#UAT-17 - Registro e inicio de sesión en modo mock]] |

## 5. Flujo principal de registro

1. La persona toca *Agregar foto*.
2. Selecciona cámara o galería y elige una imagen.
3. Completa nombre del ave, lugar, fecha y comentario; puede cancelar sin guardar.
4. La app copia la imagen a almacenamiento privado y guarda los metadatos localmente.
5. La app muestra el nuevo registro en Colección y confirma el guardado.
6. La persona puede filtrar o quitar ese registro.

La implementación del almacenamiento local y sus límites se muestra en [[arquitectura]]. Los pasos de aceptación se describen en [[uat]].

### Flujo de autenticación

1. Desde **Perfil**, la persona toca *Iniciar sesión*.
2. Ingresa **correo** y **contraseña**; el formulario valida el formato antes de enviar.
3. Con sesión mock se crea la sesión local; con BFF se llama a `POST /user/login` y se guarda el JWT.
4. Si no tiene cuenta, toca *¿No tienes cuenta? Regístrate* e ingresa **usuario**, **correo**, **contraseña** y su confirmación (`POST /user/signin`).
5. Al volver al perfil aparece el identificador público y la opción *Cerrar sesión*.

## 6. Recursos de UX

La interfaz del prototipo contiene una barra de navegación inferior, tarjetas de imagen y formularios de registro/reporte/login. Los filtros de Colección se concentran en una hoja inferior deslizante (*Mostrar*, *Categoría* y búsqueda), abierta desde un botón `Filtrar` que indica cuántos ejes están activos; los filtros en uso se resumen como chips removibles junto al botón. La implementación actual sirve como referencia funcional, no como sistema visual definitivo.

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
- Registro con correo o usuario ya existente (409) y credenciales inválidas (401): el mensaje debe ser claro y no borrar lo escrito.

## 8. Dependencias de negocio

- Gestión valida alcance, prioridad y definición de listo.
- Liderazgo mobile indicado: Maximiliano.
- Backend confirma identidad (registro/login por correo), contratos y políticas antes de implementar aportes remotos.
- Gestión/moderación confirma taxonomía de categorías, reportes y proceso de atención.
- DevOps publica el sitio HTML de Antora desde las fuentes versionadas.

## 9. Trazabilidad de implementación

| Flujo | Pantalla | Servicio |
|---|---|---|
| Navegación y estado | `lib/screens/home_screen.dart`, `lib/main.dart` | — |
| Catálogo y búsqueda | `lib/screens/catalogo_screen.dart` | `lib/services/catalogo_aves_service.dart` |
| Colección local | `lib/screens/coleccion_screen.dart` | `lib/services/coleccion_local_service.dart` |
| Feed Explorar | `lib/screens/explorar_screen.dart` | `lib/services/fotos_service.dart` |
| Registro de observación | `lib/screens/coleccion_screen.dart` (diálogo) | `lib/services/fotos_service.dart` |
| Login y registro | `lib/screens/login_screen.dart`, `lib/screens/registro_screen.dart` | `lib/services/auth_service.dart` |
| Configuración de red | — | `lib/config/api_config.dart`, `lib/services/api_client.dart` |

La información de estado de producto debe actualizarse cuando se integren servicios o cambien las capacidades mobile.

## Referencia metodológica

Estructura basada en la guía de [Product Requirements Document (PRD)](https://elixircl.github.io/elixir-fullstack/swe/prd.html) del equipo.
