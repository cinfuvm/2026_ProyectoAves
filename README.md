# CORON: Bitácora de Aves

Sistema de administración de datos de aves de Chile y bitácora de avistamientos por usuario. Incluye una aplicación móvil para Android, iOS y Windows. La API REST (Elixir Phoenix) y el dashboard web de administración (LiveView) están pendientes de reconstrucción.

## Requisitos funcionales

Los requisitos funcionales los lleva el equipo de gestión y documentación; en esta rama `docs/` queda como placeholder y el detalle no se publica aquí.

| Grupo | Requisitos |
|---|---|
| Cuentas y acceso | RF-01 a RF-04 |
| Catálogo de aves | RF-05 a RF-07 |
| Bitácora de avistamientos | RF-08 a RF-12 |
| Moderación y popularidad | RF-13 a RF-15 |
| Dashboard web y landing | RF-16 a RF-18 |
| API y documentación | RF-19 a RF-20 |

Cada issue del proyecto indica en su descripción el RF que cubre.

## Equipo

| Equipo | Líder | Integrantes |
|---|---|---|
| Backend | Josué Luis | Marcelo Guzman, Mauricio Zuñiga |
| Dashboard web | Vicente Araya | Sebastián Hugueño, Daniel Castro |
| Móvil | Maximiliano Mateo | Justin Vidaure |
| Gestión y documentación | Ignacio Latorre | Johan Cortés |

## Documentación

Para levantar la app móvil en local (emulador o celular físico) y ejecutarla
con `flutter run`, sigue [`mobile/readme.md`](mobile/readme.md).

La documentación se escribe con [Antora](https://antora.org/) y vive en `mobile/docs/`, con el PRD, la arquitectura C4, el plan de pruebas UAT y el registro de cambios de la aplicación móvil.

`docs/` queda como placeholder reservado para el equipo: esta rama no construye ese componente, solo el de mobile.

Para generarla en local (requiere Node.js 18 o superior, y Java 21 para renderizar los diagramas C4):

```
npm ci
npm run docs
```

El sitio queda en `build/site/index.html`.

Para agregar una página, crea un archivo `.adoc` en `mobile/docs/modules/ROOT/pages/` y agrégalo a `mobile/docs/modules/ROOT/nav.adoc`.
