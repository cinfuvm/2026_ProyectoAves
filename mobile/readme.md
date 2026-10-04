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

El proyecto se encuentra en etapa de boceto. Actualmente incluye:

- Proyecto Flutter y pantalla principal.
- Navegación inicial con secciones de Inicio, Buscar, Colección y Perfil.
- En Inicio, un feed de aves chilenas con imágenes y descripciones cargadas desde Wikipedia.
- En Buscar, filtros por texto (nombre común, nombre científico o descripción) y categoría de muestra (Bosque, Rapaces, Humedal, Pradera y Picaflores).
- Enlace a la página de Wikipedia de cada ave como referencia de la información e imagen.
- Guardado de aves del catálogo en Colección, con copia local de la imagen y opción para quitarla.
- Registro de una foto propia desde la cámara o la galería, solicitando nombre del ave, lugar, fecha y comentario antes de guardarla en Colección.
- Botón superpuesto en las imágenes para reportarlas seleccionando uno o más motivos.

Para esta versión inicial, las imágenes y descripciones del catálogo de muestra se obtienen en tiempo de ejecución desde la API de Wikipedia en español; no son contenido aportado por usuarios. Las categorías son agrupaciones demostrativas del catálogo local y no provienen de una API ni representan todavía las categorías definitivas del proyecto. Cada ficha enlaza al artículo de Wikipedia usado como fuente; las imágenes pueden tener licencias distintas, por lo que se debe consultar la página fuente para sus créditos y condiciones de reutilización.

Las aves guardadas desde el catálogo y los avistamientos propios (imagen, nombre del ave, lugar, fecha y comentario) se conservan localmente en el dispositivo y pueden consultarse sin conexión; se necesita Internet para guardar una nueva imagen desde Wikipedia. Los reportes y sus motivos también se almacenan solo en el dispositivo y todavía no se envían al equipo de moderación porque la app no está conectada al backend. El perfil sigue siendo provisional. Tampoco están implementados el registro de usuarios, las interacciones ni la carga de aves populares.

## Tecnologías

- **Flutter** y **Dart** para la aplicación móvil.
- **image_picker** para seleccionar o tomar imágenes en el prototipo.
- **Wikipedia en español** para las imágenes y descripciones de las especies de muestra.
- **http** para consultar Wikipedia y **url_launcher** para abrir los artículos fuente.
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
