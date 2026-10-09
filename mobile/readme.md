# 🐦 Bitácora de Aves

Aplicación móvil del proyecto **Bitácora de Aves**, orientada a compartir fotografías de aves chilenas y a construir colecciones personales de observaciones. Este repositorio contiene el boceto inicial del frontend mobile, desarrollado con Flutter.

La propuesta toma como referencia el proyecto base **Aves de Chile** y plantea una experiencia visual inspirada en una red social de fotografía, sin funciones de chat ni seguimiento de perfiles.

## Alcance de la aplicación móvil

Las funcionalidades previstas para la app son:

- Buscar aves por categoría y consultar sus fotografías.
- Subir fotografías de aves e incluir lugar, fecha y comentario.
- Explorar fotografías publicadas por otros usuarios e interactuar con ellas.
- Añadir fotografías de otros usuarios a una colección personal.
- Reportar fotografías para su revisión por moderación (función completa prevista para cuando exista conexión con el backend).
- Consultar una sección de aves populares según las visualizaciones de los usuarios.

El sistema completo también contempla un dashboard web de administración y moderación. Su desarrollo corresponde al equipo frontend web; esta aplicación se enfoca en la experiencia móvil de los usuarios.

## Estado actual

El proyecto se encuentra en etapa de prototipo con integración inicial del BFF. Actualmente incluye:

- Proyecto Flutter con plataformas Android e iOS (el target iOS está generado, pendiente de validar en un Mac).
- Navegación entre Inicio, Buscar, Explorar, Colección y Perfil mediante la barra inferior o deslizamientos horizontales.
- En Inicio, el catálogo de 216 especies de Aves de Chile, con imágenes, descripciones y nombres científicos.
- En Buscar, filtros por nombre común, nombre científico, descripción, palabras clave y categorías generales (Terrestres, Acuáticas, Rapaces, Marinas y Otras).
- Enlace a la ficha de cada especie en [Aves de Chile](https://uvm.neocities.org/aves/).
- En **Explorar**, un feed de fotos de otros usuarios (mock local por defecto; se conectará al BFF Phoenix vía `birds_apis.yaml`), con filtro por categoría, guardado en la colección personal y reporte de fotos inapropiadas.
- Guardado de aves del catálogo en Colección, con copia local de la imagen y opción para quitarla.
- Registro de una foto propia desde la cámara o la galería. El formulario solicita nombre del ave, lugar, fecha y comentario; el nombre científico y la categoría son opcionales. Si hay sesión iniciada, la app intenta subir el avistamiento al BFF y lo encola para reintentar si no hay conexión.
- Botón superpuesto en las imágenes para reportarlas seleccionando uno o más motivos; los motivos se mapean al enum del contrato (`no_es_ave`, etc.) y, con sesión, se envían al servidor.
- Autenticación con modo mock por defecto y soporte real para `POST /user/login` y `POST /user/signin` (JWT) cuando el BFF esté disponible.

El catálogo se obtiene en tiempo de ejecución desde el índice y las fichas JSON de [Aves de Chile](https://uvm.neocities.org/aves/). La app agrupa los órdenes taxonómicos en categorías generales: Terrestres, Acuáticas, Rapaces, Marinas y Otras. Las imágenes del catálogo se descargan al guardarlas; el nombre científico y la categoría que se ingresan para una observación propia no son obligatorios. Se debe consultar el sitio fuente para sus créditos y condiciones de uso.

Las aves guardadas desde el catálogo, los avistamientos propios y las fotos guardadas de la comunidad se conservan localmente en el dispositivo y pueden consultarse sin conexión. Se necesita Internet para cargar el catálogo y las imágenes del feed. Los reportes y sus motivos se almacenan en el dispositivo y se envían al servidor cuando hay sesión y conectividad; si falla, quedan encolados. El perfil funciona con sesión mock por defecto; el registro/login real depende del BFF.

## Ejecución con el BFF (cuando esté disponible)

Por defecto la app usa un mock local. Para apuntar al BFF real:

```bash
flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000
```

En el emulador de Android, `10.0.2.2` apunta al `localhost` de la máquina.

## Tecnologías

- **Flutter** y **Dart** para la aplicación móvil.
- **image_picker** para seleccionar o tomar imágenes en el prototipo.
- **Aves de Chile** para el índice, las fichas, imágenes y descripciones del catálogo.
- **http** para consultar el catálogo y sus imágenes, y **url_launcher** para abrir las fichas fuente.
- **path_provider** y **shared_preferences** para conservar imágenes y datos de la colección local en el dispositivo.
- Android como plataforma actualmente configurada; Android e iOS son el objetivo de la entrega móvil.

El backend y la API son responsabilidades del equipo backend. La especificación del proyecto contempla una API REST o GraphQL.

## Estructura del proyecto

```text
bitacora_aves/
├── android/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   └── home_screen.dart
│   └── widgets/
│       └── tarjeta_avistamiento.dart
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Cómo ejecutar

Con Flutter instalado y un emulador o dispositivo conectado:

```bash
flutter pub get
flutter run
```

## Referencia del proyecto

El documento **Documento Proyecto 2** define el alcance general, los requisitos de la aplicación móvil, el dashboard web, el backend y el despliegue. Este README describe únicamente el alcance y el estado del frontend mobile.

## Documentación mobile

El PRD, la arquitectura C4/PlantUML, el plan de pruebas UAT y el registro de cambios están en [docs/](docs/). Para generar el sitio HTML completo con Antora, ejecuta desde esa carpeta:

```bash
npm ci
npm run build
```

La salida está en `docs/_build/site/bitacora-mobile/0.1/index.html`. Para los diagramas C4, el build requiere Java disponible o la variable `JAVA_HOME`; los SVG se generan localmente y no se envían a un servicio de renderizado.
