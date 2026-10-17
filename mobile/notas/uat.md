# Plan de pruebas y UAT · Mobile

> Plan manual de pruebas de aceptación para el prototipo Flutter Bitácora de Aves.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-uat.adoc`.

## 1. Objetivo

Verificar manualmente que la app mobile cumple los criterios de aceptación definidos en el [[prd]], especialmente el registro y persistencia local de observaciones propias. UAT es una prueba funcional/de contrato con evidencia y seguimiento de defectos; no reemplaza pruebas unitarias, análisis estático ni validación de seguridad.

## 2. Alcance

### Incluido

- Inicio (panel de bienvenida y resumen), Buscar, navegación y estados de carga/error del catálogo externo de Aves de Chile.
- Reorganización de navegación y contenido al usar la app en orientación horizontal.
- Búsqueda, categorías generales, guardado y eliminación de aves de catálogo.
- Selección de imagen, formulario de observación propia, persistencia y eliminación.
- Filtros combinados de tipo, categoría y búsqueda en Colección, con sus conteos y chips-resumen.
- Registro local de reportes y mensajes que describen correctamente su estado.
- Registro con usuario + correo + contraseña e inicio de sesión con correo + contraseña (modo mock y, cuando exista BFF, contra el servidor).
- Manejo de cancelación, permisos, red y fallos de almacenamiento.

### Excluido / no aceptable como disponible hoy

- Feed comunitario y subida/reportes reales contra el BFF: se prueban en modo mock (UAT-13..UAT-15); la integración real (UAT-16) requiere el backend Phoenix disponible.
- Moderación desde dashboard, notificaciones de estado de reporte.
- Popularidad basada en vistas, comentarios, chat y seguimiento de perfiles.
- Certificación iOS: ejecutar estos casos en iOS solo después de configurar y validar ese target en un Mac.

## 3. Estrategia

- Tipo: aceptación manual funcional en dispositivo/emulador.
- Ambiente primario: Android emulator o dispositivo Android con la misma versión de la app candidata.
- Ambiente adicional recomendado: dispositivo Android físico y, cuando esté configurado, dispositivo iOS.
- Ejecución: por un integrante mobile y una persona representante de producto/gestión.
- Evidencia: captura o video sin datos sensibles, versión/build, dispositivo/OS, fecha, resultado y defectos relacionados.
- Regla de aislamiento: usar datos de prueba y no borrar datos reales de usuarios.

## 4. Preparación y datos de prueba

1. Instalar el build candidato limpio y registrar versión, commit, dispositivo y OS.
2. Disponer de conectividad para los casos del catálogo y habilitar la opción de desactivarla.
3. Preparar una imagen válida en galería y, si el emulador lo permite, cámara virtual.
4. Preparar estos datos: `Chucao`, lugar `Parque de prueba`, fecha de hoy y comentario `Observación UAT`.
5. Para filtros, usar nombres que correspondan a catálogo y un nombre no incluido, por ejemplo `Ave de prueba sin catálogo`.
6. Para autenticación: usuario `avesdemo`, correo `avesdemo@ejemplo.cl`, contraseña `secret123`.
7. Acordar antes de ejecutar cualquier caso destructivo si se puede borrar o reiniciar los datos locales de prueba.

## 5. Criterios de entrada y salida

### Entrada

- Build identificable disponible y arranque correcto.
- Casos de prueba revisados por el equipo mobile y gestión.
- Dispositivo con permisos/almacenamiento disponibles; datos de prueba preparados.
- Para casos de red, servicio externo accesible o desconectable de forma controlada.

### Salida

- Todos los casos P0 ejecutados; todo fallo bloqueante debe tener issue y responsable.
- Ningún defecto crítico/alto abierto que impida registrar, conservar, consultar o quitar observaciones locales.
- Evidencia adjunta a los resultados; regresiones verificadas después de corregir issues.
- Limitaciones conocidas (sin backend, sync y moderación remota) aceptadas y comunicadas.

## 6. Casos de aceptación

Estados sugeridos: `No ejecutado`, `Aprobado`, `Fallido`, `Bloqueado`. Registrar el resultado y la evidencia por cada ejecución; no marcar como aprobado por inferencia.

### UAT-01 - Arranque y navegación

**Prioridad:** P0

**Precondiciones:** app instalada.

1. Abrir la app.
2. Navegar por Inicio, Buscar, Explorar, Colección y Perfil.
3. Deslizar horizontalmente entre las secciones y comprobar que la barra inferior actualiza la selección.
4. Alternar tema claro/oscuro y volver a Colección.
5. Girar el dispositivo a orientación horizontal y cambiar de sección desde la navegación lateral.
6. Reducir el ancho de la ventana por debajo de 600 dp y comprobar que vuelve la barra inferior; volver a ampliarlo.

**Esperado:** en ventanas de menos de 600 dp se conserva la barra inferior; desde 600 dp se usa navegación lateral, que permite desplazarse si la altura disponible es reducida. En apaisado la cabecera y las tarjetas del catálogo reducen su altura; la imagen y los datos del ave aparecen lado a lado, y Agregar foto pasa a la barra superior para no cubrir el contenido. El contenido se centra con un ancho máximo en ventanas amplias para conservar la legibilidad. Las secciones siguen accesibles; los filtros horizontales de Buscar y Colección siguen desplazándose sin cambiar de sección; el tema cambia y no aparece una pantalla roja ni error de runtime.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-02 - Estado inicial y colección vacía

**Prioridad:** P1

**Precondiciones:** almacenamiento de prueba sin registros o conjunto vacío.

1. Abrir Colección.

**Esperado:** termina el indicador de carga; aparece el estado vacío; no hay tarjetas ni error de parseo.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-03 - Catálogo y pérdida de conexión

**Prioridad:** P1

**Precondiciones:** conectividad disponible.

1. Abrir Buscar y esperar la carga del catálogo.
2. Revisar una descripción larga contraída; tocar `Ver más` y luego `Ver menos`.
3. Desactivar la red y usar Reintentar desde el estado de error (si el servicio deja de responder).
4. Restaurar la red y reintentar.

**Esperado:** con red, el índice permite mostrar especies y miniaturas progresivamente mientras llegan las fichas por lotes; las imágenes fuera de pantalla no se descargan antes de necesitarlas. Las descripciones y comentarios extensos pueden expandirse y contraerse. Sin red, la app comunica el fallo y ofrece reintento sin cerrarse. Una respuesta externa inválida tampoco produce éxito falso.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-04 - Buscar y filtrar especies del catálogo

**Prioridad:** P1

**Precondiciones:** catálogo cargado.

1. Abrir Buscar y escribir un nombre común conocido.
2. Repetir con parte del nombre científico o descripción.
3. Elegir una categoría general y luego `Todas`.
4. Buscar un texto sin coincidencias.

**Esperado:** los resultados coinciden con texto y categoría general; limpiar búsqueda restaura resultados; sin coincidencias aparece estado vacío. Las especies quedan agrupadas como Terrestres, Acuáticas, Rapaces, Marinas u Otras.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-05 - Guardar y quitar ave del catálogo

**Prioridad:** P1

**Precondiciones:** catálogo cargado y espacio local disponible.

1. Guardar una especie.
2. Confirmar que aparece en Colección y que cambia el estado del botón del catálogo.
3. Cerrar y abrir la app.
4. Quitar la especie desde Colección o desde su ficha guardada.

**Esperado:** se conserva tras reinicio y se quita de la lista y del catálogo guardado; se informa el resultado. Si falla borrar el archivo después de actualizar los metadatos, el mensaje debe indicar el éxito parcial.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-06 - Registrar observación propia desde galería

**Prioridad:** P0

**Precondiciones:** imagen válida accesible en la galería.

1. Desde Inicio, tocar Agregar foto y elegir galería.
2. Seleccionar una imagen.
3. Completar nombre, lugar, fecha y comentario. Dejar vacíos el nombre científico y la categoría; tocar Guardar foto.
4. Repetir el registro incluyendo el nombre científico y la categoría.

**Esperado:** ambos registros se guardan; el nombre científico y la categoría pueden omitirse y se muestran cuando se ingresan. Se muestra progreso durante el guardado y una confirmación al finalizar. No hay congelamiento prolongado ni pantalla roja.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-07 - Persistencia y eliminación de observación propia

**Prioridad:** P0

**Precondiciones:** ejecutar UAT-06.

1. Cerrar y volver a abrir la app.
2. Abrir Colección y comprobar imagen y metadatos.
3. Quitar el registro.
4. Reiniciar la app y verificar que no reaparece.

**Esperado:** el registro persiste entre sesiones; al quitarlo se actualizan datos y archivo local; no queda una tarjeta huérfana.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-08 - Filtros combinados de Colección

**Prioridad:** P1

**Precondiciones:** disponer de al menos una especie guardada y una observación propia de especie reconocida por el catálogo; preparar también un nombre no catalogado.

1. En Colección, abrir `Filtrar` y escoger `Mis avistamientos` y `Acuáticas`.
2. Cambiar solo el tipo a `Todo`, conservando la categoría.
3. Escoger `Aves guardadas` y una categoría sin registros.
4. Escribir en la búsqueda un nombre no catalogado.
5. Cerrar la hoja y revisar los chips-resumen junto al botón `Filtrar`.

**Esperado:** los tres ejes se aplican simultáneamente y en vivo, sin botón de confirmación; la hoja informa en cada chip cuántos resultados aporta esa opción y el botón del pie muestra el total. Al cerrar, el botón indica cuántos ejes están activos y cada filtro aparece como chip con ✕ para quitarlo por separado. No hay resultados ajenos a los criterios y se informa claramente cuando no hay coincidencias. Un nombre no catalogado queda bajo `Sin clasificar`, salvo que se haya ingresado una categoría manualmente.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-09 - Reporte local, no envío remoto

**Prioridad:** P1

**Precondiciones:** disponer de una ficha o registro visible.

1. Abrir Reportar.
2. Seleccionar un motivo y guardar el reporte.
3. Abrir Perfil y revisar el contador.
4. Reiniciar la app y comprobar que el contador persiste.

**Esperado:** el reporte se conserva localmente y la interfaz aclara que aún no se envía a moderación. No se afirma que gestión/backend lo recibió.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-10 - Cancelación y permisos de imagen

**Prioridad:** P1

**Precondiciones:** posibilidad de cancelar el selector y controlar permisos del dispositivo.

1. Abrir selector y cancelar.
2. Repetir denegando permiso de cámara o galería.
3. Seleccionar imagen y cancelar el formulario de datos.

**Esperado:** la operación cancelada no crea registro ni archivo persistente incompleto; un permiso denegado produce un mensaje comprensible y permite continuar usando las otras secciones.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-11 - Fallo de almacenamiento y archivo ausente

**Prioridad:** P1

**Precondiciones:** entorno controlado que permita provocar espacio insuficiente, archivo inaccesible o ruta local ausente.

1. Intentar guardar un registro cuando el sistema no permita completar la escritura.
2. Si se prueba una ruta ausente, abrir una tarjeta cuyo archivo de prueba se haya retirado de forma controlada.

**Esperado:** no se comunica guardado exitoso cuando la persistencia falla; el usuario recibe un error accionable. Una imagen ausente muestra su placeholder y mantiene los metadatos, salvo que el caso pruebe deliberadamente eliminar el registro.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-12 - Verificación de límites del prototipo

**Prioridad:** P1

**Precondiciones:** build candidato.

1. Confirmar que la app no presenta sincronización de registros ni moderación remota como disponibles.
2. Guardar una observación propia y revisar que se muestra en el mismo dispositivo.
3. Crear un reporte y revisar el mensaje de no envío a moderación.
4. Comprobar que las fichas del catálogo enlazan a Aves de Chile y que no se presenta como API propia del proyecto.

**Esperado:** la app no presenta funcionalidades de backend aún no integradas como disponibles. El comportamiento local queda explicado en interfaz/documentación.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-13 - Feed Explorar (modo mock)

**Prioridad:** P0

**Precondiciones:** app en modo mock (por defecto), conectividad para cargar las imágenes de ejemplo.

1. Abrir la pestaña Explorar.
2. Verificar que se muestran fotos con autor y lugar.
3. Cambiar el filtro de categoría y comprobar que el feed se recarga.
4. Desplazarse al final para verificar la carga de más fotos si hay varias páginas.
5. Abrir una foto y verificar el visor con transición Hero.
6. Conectar internet y verificar el estado de error y el botón Reintentar si se interrumpe la red.

**Esperado:** el feed carga por categoría, pagina sus resultados y presenta estados de carga/vacío/error comprensibles.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-14 - Guardar y reportar fotos de la comunidad

**Prioridad:** P0

**Precondiciones:** pestaña Explorar con feed cargado.

1. Guardar una foto de la comunidad en la colección.
2. Abrir Colección y verificar que la foto aparece con el origen de la comunidad.
3. Reportar una foto con motivo "La foto no muestra un ave".
4. Verificar el mensaje de reporte (enviado en mock o guardado local como respaldo).
5. Quitar la foto de la colección y verificar que se elimina su archivo local.

**Esperado:** la foto ajena se guarda localmente, se reporta y se puede quitar sin dejar archivos huérfanos.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-15 - Subida de avistamiento con sesión mock

**Prioridad:** P1

**Precondiciones:** sesión iniciada (mock) y modo mock activo.

1. Registrar un avistamiento propio con lugar, fecha y comentario.
2. Verificar el mensaje de éxito local.
3. En modo mock, el `FotosService` simula la subida; verificar que no hay errores inesperados.
4. Probar el mismo flujo con la sesión cerrada y verificar que solo se guarda local (sin intento de subida).

**Esperado:** con sesión la app intenta subir al BFF (mock o real); sin sesión solo guarda local sin errores.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-16 - Autenticación real (cuando el BFF esté disponible)

**Prioridad:** P1

**Precondiciones:** BFF Phoenix corriendo y app compilada con `--dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=<url>`.

1. Registrar un usuario nuevo desde la app con **usuario**, **correo**, **contraseña** y su confirmación (o `POST /user/signin`).
2. Intentar registrar el mismo usuario o el mismo correo y verificar el error 409 sin perder lo escrito.
3. Cerrar sesión e iniciar sesión **solo con correo y contraseña** (no con el nombre de usuario).
4. Verificar que el perfil muestra el identificador público devuelto por el servidor.
5. Enviar un reporte y verificar que llega al servidor (respuesta 200).
6. Cerrar sesión y verificar que los flujos protegidos vuelven a pedir login.

**Esperado:** el login real devuelve y persiste un JWT; los endpoints autenticados funcionan con la sesión activa; entrar con un usuario que no sea un correo válido se rechaza en el formulario.

**Resultado/evidencia:** pendiente de ejecución.

### UAT-17 - Registro e inicio de sesión en modo mock

**Prioridad:** P0

**Precondiciones:** app en modo mock (por defecto), sin BFF.

1. Desde Perfil, abrir *Iniciar sesión*.
2. Enviar el formulario vacío y con un correo sin `@`: verificar los mensajes de validación.
3. Registrar una cuenta con usuario `avesdemo` (3 a 30 caracteres), correo `avesdemo@ejemplo.cl` y contraseña de 8 o más caracteres con su confirmación.
4. Verificar que el perfil muestra el usuario registrado y la opción *Cerrar sesión*.
5. Cerrar sesión y volver a entrar **con el correo** y la contraseña.
6. Probar registro con contraseñas que no coinciden y con usuario de 2 caracteres.

**Esperado:** el registro exige usuario + correo + contraseña; el login solo acepta correo + contraseña; los errores aparecen debajo del campo correspondiente y no se pierde lo escrito; la sesión mock queda abierta y sobrevive al reinicio de la app.

**Resultado/evidencia:** pendiente de ejecución.

## 7. Registro de ejecución

Copiar esta tabla para cada build/ciclo UAT. Adjuntar capturas/videos con nombres que incluyan ID de caso, fecha y build; ocultar información personal.

| Caso | Estado | Ejecutor | Fecha | Build/dispositivo | Issue/evidencia |
|---|---|---|---|---|---|
| UAT-01..UAT-17 | No ejecutado | Pendiente | Pendiente | Build y dispositivo por registrar | Pendiente |

## 8. Gestión de defectos

Para cada caso fallido:

1. Registrar los pasos exactos, resultado esperado/real, build, dispositivo/OS y evidencia.
2. Crear o vincular un GitHub Issue según el proceso del equipo de gestión; no duplicar un issue existente.
3. Clasificar prioridad con gestión y asignar el equipo responsable.
4. Repetir el caso fallido y sus regresiones relacionadas después del arreglo.
5. Conservar evidencia del resultado final y cerrar solo con confirmación del responsable de aceptación.

## 9. Aprobación

| Rol | Nombre | Aprobación/fecha |
|---|---|---|
| Representante producto/gestión | Pendiente de asignación | Pendiente |
| Líder técnico mobile | Maximiliano (según asignación del proyecto) | Pendiente |
| Backend (para alcance de integración futura) | Jose Luis (según asignación del proyecto) | Pendiente y fuera de aceptación del prototipo local |

La aprobación UAT aplica al build y alcance identificados, no a funcionalidades excluidas ni a versiones futuras.

## Referencia metodológica

Estructura basada en la guía de [User Acceptance Testing (UAT)](https://elixircl.github.io/elixir-fullstack/swe/uat.html) del equipo.
