# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Personas que observan y fotografían aves en Chile (aficionados a la observación y la fotografía de aves). Su trabajo: explorar el catálogo de aves chilenas, guardar aves en una colección personal y registrar sus propios avistamientos con fotografía, lugar, fecha y comentario.

## Product Purpose

Sistema "Bitácora de Aves": administrar datos de aves de Chile y llevar una bitácora de avistamientos por usuario, con una experiencia móvil inspirada en una red social de fotografía (sin chat ni seguimiento de perfiles). El proyecto nace como trabajo de curso con ambición de publicarse después. Éxito: entregar los requisitos funcionales RF-01 a RF-20 con calidad, manteniendo una base que permita el lanzamiento futuro.

## Positioning

Catálogo de aves de Chile + bitácora personal de avistamientos + colección, con moderación por reportes de los propios usuarios. Mecanismo propio que un producto vecino no replica sin construir el mismo sistema: fichas del catálogo con fuente enlazada (Aves de Chile) y una cola de moderación alimentada por reportes de la comunidad, dentro de una experiencia de fotografía de aves sin redes sociales convencionales.

## Operating Context

- Proyecto 2026_ProyectoAves con cuatro equipos: Backend (API REST BFF en Elixir Phoenix, pendiente de reconstruir), Dashboard web (LiveView de administración y moderación), Móvil (esta app Flutter), y Gestión y documentación.
- Cada issue del proyecto indica en su descripción el RF que cubre; el detalle lo lleva el equipo de gestión y documentación en su propio componente, que esta rama no construye.
- Documentación escrita con Antora en `mobile/docs/` (PRD, arquitectura C4, plan UAT y registro de cambios) y generada con `npm run docs` desde la raíz (salida en `build/site/`).
- Desarrollo y verificación de la app en Android (emulador/dispositivo); autenticación actualmente demo local en `SharedPreferences` hasta que exista el BFF.
- El catálogo se carga en tiempo de ejecución desde el índice y las fichas JSON de Aves de Chile (uvm.neocities.org/aves); las fichas enlazan al artículo fuente.

## Capabilities and Constraints

- App móvil Flutter con distribución objetivo Android e iOS; diseño Material 3 y verificación realizada en Android.
- Funciones disponibles hoy: buscar aves por texto y categoría; guardar aves del catálogo en Colección con copia local de la imagen; registrar aves propias desde cámara o galería con nombre del ave, lugar, fecha y comentario; reportar fotos con motivos; perfil y sesión demo; navegación con Inicio, Buscar, Colección y Perfil.
- Persistencia local: colección y avistamientos propios se consultan sin conexión; se necesita Internet para cargar el catálogo y guardar una imagen nueva desde Aves de Chile.
- Los reportes y sus motivos se almacenan solo en el dispositivo y todavía no se envían a moderación (sin conexión al backend).
- Perfil provisional: no hay registro real de usuarios (RF-01/RF-02 pendientes sobre el BFF).
- RF previstos pero no implementados en la app hoy: interacciones entre usuarios, feed de fotos de otros usuarios (RF-11), colección desde fotos ajenas (RF-12) y sección de aves populares (RF-15).
- Las categorías del catálogo (Bosque, Rapaces, Humedal, Pradera, Picaflores) son agrupaciones demostrativas, no definitivas.
- Las imágenes provienen de Aves de Chile y pueden tener licencias distintas: los créditos y condiciones se consultan en la página fuente.

## Brand Commitments

- Nombre: "Bitácora de Aves"; referencia de proyecto base declarada: "Aves de Chile".
- Experiencia visual inspirada en una red social de fotografía, sin funciones de chat ni seguimiento de perfiles.
- Interfaz y contenido en español (Chile).

## Evidence on Hand

- `README.md` (requisitos RF-01–RF-20 y equipos), `mobile/README.md` (alcance y estado de la app).
- `mobile/docs/modules/ROOT/pages/` con el PRD, la arquitectura, el plan UAT y el registro de cambios; los 20 requisitos funcionales los publica el equipo en su propio componente.
- `birds_apis.yaml` (especificación OpenAPI). La carpeta `backend/` y el BFF fueron retirados del repositorio y están pendientes de reconstrucción.
- Catálogo de 216 especies cargado desde Aves de Chile en tiempo de ejecución.
- Ausencias que el trabajo futuro no debe inventar: usuarios reales, métricas de uso, testimonios, contenido moderado o datos de lanzamiento.

## Product Principles

1. Los RF mandan: cada entrega se traza a un requisito y el alcance declarado pesa más que features extra.
2. Offline-first para lo personal: colección y avistamientos propios funcionan sin conexión.
3. Transparencia de la fuente: cada ficha enlaza su origen en Aves de Chile y las imágenes se atribuyen desde allí.
4. Social sin ruido: inspiración fotográfica, pero nunca chat ni seguimiento de perfiles.
5. Puente al BFF: la sesión demo no quiebra la migración futura a HTTP con token sin tocar las pantallas.
