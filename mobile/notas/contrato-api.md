# Extensiones propuestas al contrato de la API

> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-contrato.adoc`.

## Contexto

El equipo mobile implementa el cliente HTTP contra `birds_apis.yaml` en `mobile/lib/services/` (`auth_service.dart` y `fotos_service_bff.dart` con su variante mock). La app ya habla contra estos endpoints; lo que sigue pendiente es que el contrato declare lo que el cliente usa y que el backend lo confirme antes de la integración final. La sección sobre registro con usuario + correo y login por correo ya quedó aplicada en el archivo de contrato y **pendiente de implementación en el servidor**.

## 1. Endpoints que la app ya llama y el contrato no declara

| Método | Ruta que usa la app | Uso |
|---|---|---|
| GET | `/api/user/me` | Revalida la sesión JWT al arrancar |
| DELETE | `/api/user/logout` | Cierra sesión en el servidor |
| GET | `/images/reports` | Lista reportes para la pantalla de moderación |
| PUT | `/images/reports/{id}` | Cambia el estado de un reporte (solo rol `admin`) |

Además, el contrato declara las rutas como `/user/login` y `/user/signin` mientras el cliente las llama bajo el prefijo `/api/`. Hay que acordar si el prefijo lo añade el servidor o si debe figurar en el contrato.

## 2. `POST /images`: aceptar lugar, fecha y comentario

El RF-08 exige registrar el avistamiento con Lugar, Fecha, Comentario y Fotografía. El cliente ya envía estos campos en `multipart/form-data`; el contrato actual solo documenta `file` y `categoria`, así que la propuesta es incorporarlos a la especificación.

Campos adicionales sugeridos:

| Campo | Descripción | Requerido |
|---|---|---|
| `lugar` | Lugar donde se observó el ave | no |
| `fecha` | Fecha del avistamiento en formato `YYYY-MM-DD` | no |
| `comentario` | Texto libre del observador (máx. 500) | no |

## 3. `GET /images`: devolver autor, lugar, fecha y comentario

Para el feed comunitario (RF-11) la app muestra quién subió la foto, dónde y cuándo. El parser del cliente ya acepta estos campos; el schema `Imagen` del contrato solo declara `id`, `url`, `categoria` y `subida_en`.

Campos adicionales sugeridos:

| Campo | Descripción |
|---|---|
| `autor` | Identificador público del usuario que subió la foto |
| `lugar` | Lugar del avistamiento |
| `fecha` | Fecha del avistamiento (`YYYY-MM-DD`) |
| `comentario` | Comentario del observador |

## 4. `categoria` como enum cerrado

La app agrupa los órdenes taxonómicos en categorías generales. Para que el filtro de `GET /images` y el campo de `POST /images` sean coherentes, `categoria` debería ser un enum con valores en minúscula:

| Valor | Categoría general |
|---|---|
| `terrestres` | Terrestres |
| `acuaticas` | Acuáticas |
| `rapaces` | Rapaces |
| `marinas` | Marinas |
| `otras` | Otras |

La app envía y recibe estos valores (o sus formas con tilde/espacio), y normaliza internamente con `categoriaGeneralAves`.

## 5. `GET /images`: filtro opcional por autor

Para poder consultar "mis fotos subidas" desde el perfil:

| Parámetro | Descripción | Requerido |
|---|---|---|
| `autor` | Identificador público del usuario | no |

## 6. Estados de reporte: hay que alinearlos

El contrato define el enum `recibido`, `en_revision`, `resuelto`, `descartado` (`birds_apis.yaml:368-370`). La app y su pantalla de moderación usan `abierto`, `revisado`, `descartado` (`mobile/lib/models/reporte_moderacion.dart:52`, `mobile/lib/screens/reportes_screen.dart:201-203`).

Hay que elegir un solo conjunto y actualizar la otra parte. Esta discrepancia está documentada porque afecta directamente a la integración del RF-14.

## 7. Motivos de reporte

La app envía los motivos del enum del contrato:

- `no_es_ave`
- `contenido_ofensivo`
- `imagen_enganosa`
- `derechos_autor`
- `otro` (con `detalle` libre de hasta 500 caracteres)

El detalle de la UI se mapea en `motivosReporteContrato` (`mobile/lib/services/fotos_service.dart`).

## 8. Erratas en el esquema

- `confirm_pasword` aparece escrito así en dos lugares (`birds_apis.yaml:242` y `:257`); debería ser `confirm_password`. Si se corrige, avisar al equipo mobile porque la app lo serializa.

## Registro con usuario + correo y login por correo *(aplicado al contrato)*

Actualizado en `birds_apis.yaml`; la app ya lo envía así. **Pendiente de implementación en el backend.**

### `POST /user/signin` · Crear usuario

| Campo | Tipo | Requerido | Reglas |
|---|---|---|---|
| `user` | string | sí | 3–30 caracteres; identificador público |
| `email` | string (email) | sí | correo único; forma de iniciar sesión |
| `password` | string | sí | mínimo 8 caracteres |
| `confirm_password` | string | sí | debe coincidir con `password` |

Respuestas: `201` con la sesión inicial (`token` + `user`), `400/422` con `Error` de validación y `409` cuando ya existe el usuario (`usuario_duplicado`) o el correo (`email_duplicado`).

> [!nota]
> El esquema `CrearUsuario` del contrato llama a este último campo `confirm_pasword` (typo heredado; ver la errata de la sección 8), mientras la app envía `confirm_password`. Conviene acordar con backend cuál de los dos nombres queda y corregir el archivo.

### `POST /user/login` · Iniciar sesión

| Campo | Tipo | Requerido | Reglas |
|---|---|---|---|
| `email` | string (email) | sí | correo con el que se registró el usuario |
| `password` | string | sí | — |

Antes el login recibía `user` + `password`; ahora **el nombre de usuario ya no sirve para entrar**, solo el correo. Respuestas: `200` con la sesión (`token` + `user`, este último es el identificador público, no el correo), `400` con `Error` de validación y `401` con credenciales inválidas.

### Implementación en la app

| Aspecto | Ubicación |
|---|---|
| Formulario de registro (usuario, correo, contraseña, confirmación) | `mobile/lib/screens/registro_screen.dart` |
| Formulario de login (correo, contraseña) | `mobile/lib/screens/login_screen.dart` |
| Llamadas HTTP y sesión | `mobile/lib/services/auth_service.dart` |
| Lectura del identificador en el mock | `mobile/scripts/mock_backend.dart` → `_identificador()` |
| Caso UAT | [[uat#UAT-16 - Autenticación real (cuando el BFF esté disponible)]], [[uat#UAT-17 - Registro e inicio de sesión en modo mock]] |

## Puntos abiertos con backend

1. Confirmar los cuatro campos de `signin` y el nombre exacto del de confirmación.
2. Confirmar que `GET /api/user/me` devuelve `user`, `email` y `rol` (hoy la app solo lee `user` y `rol`).
3. Aplicar las extensiones 2–5 antes de la integración final del feed y la subida de fotos.
4. Acordar el mensaje y código de los errores duplicados (409) para mostrarlos tal cual en la app.
