# docs/

Documentación del proyecto escrita con [Antora](https://antora.org/) en
formato AsciiDoc. Cubre requisitos funcionales, PRD, arquitectura, calidad,
DevOps, UAT y el contrato de la API REST.

- Componente Antora: `antora.yml` (nombre `bitacora-aves`).
- Páginas: `modules/ROOT/pages/`. Al agregar una página hay que registrarla en
  `modules/ROOT/nav.adoc`.
- Contratos OpenAPI: `modules/ROOT/attachments/openapi/`.

Para generar el sitio desde la raíz del repositorio (requiere Node.js 18 o
superior):

```bash
npm ci
npm run docs
```

El resultado queda en `build/site/index.html`.

La documentación propia de la aplicación móvil (PRD, arquitectura C4, UAT y
changelog) vive en [`mobile/docs/`](../mobile/docs/), que es un componente
Antora autocontenido. Se genera con `npm run docs:mobile` y ambos sitios con
`npm run docs:all`.
