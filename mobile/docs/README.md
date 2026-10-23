# Documentación móvil — CORON: Bitácora de Aves

Esta carpeta es un **componente Antora autocontenido** que documenta la aplicación móvil (producto, arquitectura, pruebas UAT y registro de cambios). No tiene playbook ni dependencias propias: el playbook que la construye está en `mobile/antora-playbook.yml` y declara esta carpeta como `start_path: mobile/docs`.

## Estructura

```
mobile/docs/
├── antora.yml                 # Metadatos del componente Antora
├── modules/ROOT/
│   ├── nav.adoc               # Navegación del componente
│   ├── pages/                 # Páginas .adoc (index, mobile-*.adoc)
│   ├── partials/              # Diagramas PlantUML (C4)
│   └── images/                # SVG generados (mobile-c4-*.svg)
└── scripts/
    └── render-diagrams.mjs    # Renderiza los diagramas C4 a SVG
```

## Requisitos previos

- Node.js 18+ y npm.
- Java 21 (JDK) disponible o la variable de entorno `JAVA_HOME` configurada. En Windows también se busca Eclipse Adoptium en `Program Files`.
- Git (el playbook lee la fuente desde la raíz del repositorio).

## Iniciar la documentación

Desde la carpeta `mobile/`:

1. Instalar las herramientas de documentación:
   ```bash
   npm ci
   ```

2. Renderizar los diagramas C4 (requiere Java 21):
   ```bash
   npm run docs:diagrams
   ```

3. Generar el sitio HTML con Antora:
   ```bash
   npm run docs:site
   ```
   O todo junto:
   ```bash
   npm run docs
   ```

La salida se genera en `mobile/build/site/index.html`.

## Previsualización rápida

Para leer un documento sin compilar, abre los archivos `.adoc` en VS Code y usa el comando `AsciiDoc: Open Preview`.

## Agregar una nueva página

1. Crear el archivo `.adoc` en `modules/ROOT/pages/`.
2. Registrarlo en `modules/ROOT/nav.adoc` con un `xref:`.

## Notas

- Los SVG de los diagramas C4 se generan localmente y no se envían a un servicio de renderizado.
- La documentación de esta carpeta cubre solo la parte móvil; el resto del sitio se publica en su propio componente.