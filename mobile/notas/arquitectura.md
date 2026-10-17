# Arquitectura mobile

> Arquitectura C4 en PlantUML de la aplicación Flutter CORON: Bitácora de Aves.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-architecture.adoc`.

## Alcance y estado

Este documento modela la implementación mobile actual, no una arquitectura desplegada completa. La app Flutter consulta el índice y las fichas del catálogo en [Aves de Chile](https://uvm.neocities.org/aves/), persiste la colección y los reportes en el dispositivo, y se comunica con el BFF propio para cuentas, publicación de imágenes, feed comunitario y moderación.

El BFF se consume en dos modos que se eligen en tiempo de compilación: **local** (mock, el valor por defecto de `lib/config/api_config.dart`) y **remoto** (`--dart-define=BFF_ACTIVO=true`). Arrancar la app no requiere servidor. El dashboard web sigue sin existir.

El usuario del producto objetivo aportará la mayor parte de las imágenes. Las imágenes propias se seleccionan desde cámara/galería, se guardan primero en local y se publican al BFF desde la cola de subidas pendientes. El catálogo externo proporciona las fichas de especies; no es la fuente arquitectónica de las contribuciones comunitarias.

## C4 · Contexto

![Diagrama C4 de contexto de CORON: Bitácora de Aves](../modules/ROOT/images/mobile-c4-context.svg)

## C4 · Contenedores mobile

![Diagrama C4 de contenedores de CORON: Bitácora de Aves](../modules/ROOT/images/mobile-c4-containers.svg)

## Límites y responsabilidades

| Elemento | Responsabilidad actual |
|---|---|
| Aplicación Flutter | Presenta Inicio, Buscar, Explorar, Colección y Perfil; administra interacciones, formularios, autenticación y estado de pantalla. |
| BFF propio (Elixir Phoenix) | Autentica con JWT (`POST /api/user/login` y registro), publica imágenes (`POST /images`), sirve el feed paginado (`GET /images`) y atiende reportes de moderación (`GET /images/reports`, `PUT /images/reports/{id}`). Se declara en `mobile/birds_apis.yaml`. Modo mock por defecto; modo remoto con `BFF_ACTIVO=true`. |
| Aves de Chile (uvm.neocities.org/aves) | Provee el índice, las fichas taxonómicas, descripciones e imágenes del catálogo. El índice permite presentar especies y miniaturas mientras se solicitan fichas en lotes limitados; la app agrupa los órdenes de la fuente en categorías generales para explorar y filtrar. No almacena observaciones de usuarios ni reportes del proyecto. |
| Almacenamiento local | Conserva en el mismo dispositivo metadatos JSON y archivos de imagen. Es la fuente de verdad del modo offline: los reportes y los avistamientos propios se registran aquí primero. No sincroniza ni constituye un respaldo. |
| Cámara/galería | Permite seleccionar una imagen mediante el plugin de plataforma. El usuario confirma los metadatos antes de guardar el registro. |
| Dashboard web | No existe todavía. La moderación se atiende desde la pantalla `ReportesScreen` de la app, restringida al rol `admin`. |

## Capa de red y autenticación

- `config/api_config.dart` fija la URL base por `--dart-define=BFF_URL=...` y el modo mock/real (`MOCK_BFF`/`BFF_ACTIVO`); por defecto está en mock.
- `services/api_client.dart` encapsula HTTP con timeouts, manejo del schema `Error` y cabecera `Authorization: Bearer`.
- `services/auth_service.dart` gestiona la sesión:

```text
RegistroScreen ──registrarse(user, email, password, confirm)──▶ AuthService
LoginScreen    ──iniciarSesion(correo, password)───────────────▶ AuthService
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
        modo mock (por defecto)          BFF real (HTTP)
        valida formato y crea            POST /user/signin  (user+email+password)
        sesión local mock                POST /user/login   (email+password)
                                               │
                                               ▼
                                     JWT guardado en SharedPreferences
                                     revalidado con GET /api/user/me
```

- `cerrarSesion()` llama a `DELETE /api/user/logout` cuando hay token y borra la sesión local, con o sin conexión.
- Si `GET /api/user/me` responde 401/403 se limpia la sesión local; ante un error de red se conserva la sesión en caché.

## Datos y persistencia

- Los metadatos de catálogo guardado se serializan bajo la clave local `aves_guardadas_catalogo_v1`; si no existe, se leen registros de la clave previa para conservar la colección local.
- Los avistamientos propios se serializan bajo `avistamientos_propios_v1`; sus imágenes se copian a un subdirectorio `avistamientos` del directorio de documentos.
- Los reportes se serializan bajo `reportes_fotos_pendientes_v1` y siempre se conservan en el dispositivo. Solo los reportes cuya foto viene del feed remoto se envían además al BFF; los de fotos locales se quedan sin enviar y la propia interfaz lo indica.
- La cola de subidas pendientes (`subidas_bff_pendientes_v1`) retiene las publicaciones fallidas por red y las reintenta al abrir la app; el registro local existe antes de que el BFF confirme.
- Las fotos guardadas del catálogo se copian al directorio privado `coleccion_aves`.
- La sesión (JWT, identificador, rol y datos de usuario) se guarda en `SharedPreferences` bajo `session_usuario_v1`.
- Borrar los datos de la app o desinstalarla puede eliminar estos datos locales; no hay restauración de servidor para la colección.

## Consideraciones de seguridad y privacidad

- La app debe pedir acceso a cámara/galería a través de las APIs de plataforma y respetar la decisión del usuario.
- Los archivos locales son privados al sandbox de la aplicación; no se afirma que estén cifrados.
- El JWT se guarda sin cifrar en `SharedPreferences`; no debería almacenarse en logs ni en la documentación.
- Las fotos del feed se suben al BFF propio, no a servicios externos de terceros. Aún no existe una política de privacidad publicada por el proyecto.
- Los enlaces del catálogo abren la página fuente en navegador externo; los derechos de imagen dependen de cada recurso.
- No incluir datos personales, tokens ni contenido sensible en logs ni en la documentación.

## Contratos pendientes

El cliente ya implementa identidad, publicación, feed y reportes, pero estos puntos siguen abiertos y pueden obligar a cambiar el código:

1. Aprobación formal de identidad y autorización por rol del contrato (el registro/login ya está en [[contrato-api]]).
2. Modelo de observación, identificador estable y estrategia para borrado/edición.
3. Almacenamiento de imágenes en el servidor, formatos y tamaños permitidos, URL de acceso.
4. Conflictos de la cola de subida: reintentos, idempotencia y estado en servidor.
5. Taxonomía de categorías y validación de especie/lugar.
6. Estados de reporte: la app usa `abierto|revisado|descartado` y el contrato declara `recibido|en_revision|resuelto|descartado`; hay que alinearlos.
7. Migración de registros locales existentes y tratamiento de fallos parciales.

La arquitectura objetivo debe actualizarse como una versión nueva de este documento cuando esos contratos estén aprobados. No se deben representar como ya desplegados elementos que solo existen en modo mock.

## Reproducción de diagramas

Las fuentes PlantUML se mantienen en `mobile/docs/modules/ROOT/partials/` (`mobile-c4-context.puml`, `mobile-c4-containers.puml`) y usan C4-PlantUML 2.12.0. Para generar los SVG y el sitio HTML completo, desde la raíz del repositorio ejecuta `npm ci` una vez y luego `npm run docs`. La compilación renderiza los diagramas con Java local y descarga la interfaz Antora y la librería C4 fijada a una versión; el código de los diagramas no se envía a un servicio de renderizado externo.
