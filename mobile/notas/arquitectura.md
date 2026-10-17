# Arquitectura mobile

> Arquitectura C4 en PlantUML de la aplicación Flutter CORON: Bitácora de Aves.
> Fuente AsciiDoc: `mobile/docs/modules/ROOT/pages/mobile-architecture.adoc`.

## Alcance y estado

Este documento modela la implementación mobile del prototipo, no una arquitectura desplegada completa. La app Flutter consulta el índice y las fichas del catálogo en [Aves de Chile](https://uvm.neocities.org/aves/) y persiste la colección, los reportes y la sesión en el dispositivo. La capa de red contra el BFF ya está escrita (`api_config.dart`, `api_client.dart`, `auth_service.dart`, `fotos_service_bff.dart`) pero **opera en modo mock por defecto**: no se puede afirmar conexión con la API propia del proyecto ni con un backend de imágenes o dashboard.

El usuario del producto objetivo aportará la mayor parte de las imágenes. En el prototipo, las imágenes de observaciones propias se seleccionan desde cámara/galería y se guardan solo localmente. El catálogo externo proporciona las fichas de especies; no es la fuente arquitectónica de las futuras contribuciones comunitarias.

## C4 · Contexto

![Diagrama C4 de contexto de CORON: Bitácora de Aves](../modules/ROOT/images/mobile-c4-context.svg)

## C4 · Contenedores mobile

![Diagrama C4 de contenedores de CORON: Bitácora de Aves](../modules/ROOT/images/mobile-c4-containers.svg)

## Límites y responsabilidades

| Elemento | Responsabilidad actual |
|---|---|
| Aplicación Flutter | Presenta Inicio, Buscar, Explorar, Colección y Perfil; administra interacciones, formularios, sesión y estado de pantalla. |
| Aves de Chile (uvm.neocities.org/aves) | Provee el índice, las fichas taxonómicas, descripciones e imágenes del catálogo. El índice permite presentar especies y miniaturas mientras se solicitan fichas en lotes limitados; la app agrupa los órdenes de la fuente en categorías generales para explorar y filtrar. No almacena observaciones de usuarios ni reportes del proyecto. |
| Almacenamiento local | Conserva en el mismo dispositivo metadatos JSON, archivos de imagen y la sesión (`SharedPreferences`). No sincroniza ni constituye un respaldo. |
| Cámara/galería | Permite seleccionar una imagen mediante el plugin de plataforma. El usuario confirma los metadatos antes de guardar el registro. |
| BFF Phoenix (futuro) | Recibiría `POST /user/signin`, `POST /user/login`, `GET /user/me`, `DELETE /user/logout`, `GET/POST/PUT /images`. Hoy solo existe el contrato `birds_apis.yaml` y el mock de `scripts/mock_backend.dart`. |
| Dashboard | No está conectado en esta versión. La moderación remota es una integración futura, no un contenedor implementado. |

## Capa de red y autenticación

- `config/api_config.dart` fija la URL base por `--dart-define=BFF_URL=...` y el modo mock/movil real (`MOCK_BFF`/`BFF_ACTIVO`); por defecto está en mock.
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
- Los reportes se serializan bajo `reportes_fotos_pendientes_v1`. Su persistencia local no significa que un moderador los haya recibido.
- Las fotos guardadas del catálogo se copian al directorio privado `coleccion_aves`.
- Las subidas al BFF que fallan quedan en `subidas_bff_pendientes_v1` y se reintentan al abrir la app.
- La sesión autenticada se guarda en `session_usuario_v1` (identificador, rol y token).
- Borrar los datos de la app o desinstalarla puede eliminar estos datos locales; no hay restauración de servidor.

## Consideraciones de seguridad y privacidad

- La app debe pedir acceso a cámara/galería a través de las APIs de plataforma y respetar la decisión del usuario.
- Los archivos locales son privados al sandbox de la aplicación; no se afirma que estén cifrados. El JWT se guarda en texto plano en `SharedPreferences`.
- No cargar fotos de usuarios a servicios externos hasta que exista un contrato de backend, consentimiento y política de privacidad aprobados.
- Los enlaces del catálogo abren la página fuente en navegador externo; los derechos de imagen dependen de cada recurso.
- No incluir datos personales, tokens ni contenido sensible en logs ni en la documentación. El mock (`scripts/mock_backend.dart`) imprime el cuerpo de cada petición en consola: no usarlo con datos reales.

## Evolución propuesta y contratos pendientes

Cuando el backend esté disponible, el equipo debe definir antes de integrar:

1. ~~Identidad y autorización del usuario~~ — contrato de registro/login acordado en [[contrato-api]]; falta implementarlo en el servidor.
2. Modelo de observación, identificador estable y estrategia para borrado/edición.
3. Carga de imágenes, formatos y tamaños permitidos, almacenamiento y URL de acceso.
4. Operación offline: cola de subida, reintentos, conflictos y estados pendientes.
5. Taxonomía de categorías y validación de especie/lugar.
6. Contrato de envío de reportes y consulta de su estado por dashboard/moderación.
7. Migración de registros locales existentes y tratamiento de fallos parciales.

La arquitectura objetivo debe actualizarse como una versión nueva de este documento cuando esos contratos estén aprobados. No se deben representar endpoints, colas o bases de datos futuras como elementos ya desplegados.

## Reproducción de diagramas

Las fuentes PlantUML se mantienen en `mobile/docs/modules/ROOT/partials/` (`mobile-c4-context.puml`, `mobile-c4-containers.puml`) y usan C4-PlantUML 2.12.0. Para generar los SVG y el sitio HTML completo, desde la raíz del repositorio ejecuta `npm ci` una vez y luego `npm run docs`. La compilación renderiza los diagramas con Java local y descarga la interfaz Antora y la librería C4 fijada a una versión; el código de los diagramas no se envía a un servicio de renderizado externo.
