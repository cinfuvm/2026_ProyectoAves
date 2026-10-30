# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Personas que observan y fotografían aves en Chile (aficionados a la observación y la fotografía de aves). Su trabajo: explorar el catálogo de aves chilenas, guardar aves en una colección personal, registrar sus propios avistamientos con fotografía, lugar, fecha y comentario, y compartir aportes en el feed de la comunidad.

## Product Purpose

Sistema "CORON: Bitácora de Aves": administrar datos de aves de Chile y llevar una bitácora de avistamientos por usuario, con una experiencia móvil inspirada en una red social de fotografía (sin chat ni seguimiento de perfiles). El proyecto nace como trabajo de curso con ambición de publicarse después. Éxito: entregar los requisitos funcionales RF-01 a RF-20 con calidad, manteniendo una base que permita el lanzamiento futuro.

## Positioning

Catálogo de aves de Chile + bitácora personal de avistamientos + colección, con moderación por reportes de los propios usuarios. Mecanismo propio que un producto vecino no replica sin construir el mismo sistema: fichas del catálogo con fuente enlazada (Aves de Chile) y una cola de moderación alimentada por reportes de la comunidad, dentro una experiencia de fotografía de aves sin redes sociales convencionales.

## Operating Context

- Proyecto 2026_ProyectoAves con cuatro equipos: Backend (API REST BFF en Elixir Phoenix, pendiente de reconstruir), Dashboard web (LiveView de administración y moderación), Móvil (esta app Flutter), y Gestión y documentación.
- Cada issue del proyecto indica en su descripción el RF que cubre; el detalle lo lleva el equipo de gestión y documentación en su propio componente, que esta rama no construye.
- Documentación escrita con Antora en `mobile/docs/` (PRD, arquitectura C4, plan UAT y registro de cambios) y generada con `npm run docs` desde la raíz (salida en `build/site/`).
- Desarrollo y verificación de la app en Android (emulador/dispositivo); también hay target de Windows. El BFF se consume en modo mock por defecto y en modo remoto con `--dart-define=BFF_ACTIVO=true`.
- El catálogo se carga en tiempo de ejecución desde el índice y las fichas JSON de Aves de Chile (uvm.neocities.org/aves); las fichas enlazan al artículo fuente.

## Capabilities and Constraints

- App móvil Flutter con distribución objetivo Android e iOS, más un target de Windows; diseño Material 3 y verificación realizada en Android. Android y Windows tienen build verificado; iOS lleva solo el scaffolding.
- Funciones disponibles hoy: buscar aves por texto y categoría; guardar aves del catálogo en Colección con copia local de la imagen; registrar aves propias desde cámara o galería con nombre del ave, lugar, fecha y comentario; publicar y consultar el feed *Explorar* con paginación; guardar fotos de la comunidad en la colección; reportar fotos con motivos; pantalla de moderación con rol `admin`; login, registro y cierre de sesión; navegación con Inicio, Buscar, Explorar, Colección y Perfil.
- Persistencia local: colección, avistamientos propios y reportes se consultan sin conexión; se necesita Internet para cargar el catálogo, autenticarse y publicar una imagen nueva.
- Los reportes siempre se almacenan en el dispositivo; solo los de fotos del feed remoto se envían además al BFF. Los de fotos locales quedan sin enviar y la interfaz lo indica.
- La sesión (JWT y usuario) se guarda en `SharedPreferences`; el registro y login funcionan contra el BFF, con datos locales mientras el modo sea mock.
- RF previstos pero no implementados en la app hoy: interacciones entre usuarios, sección de aves populares (RF-15), sincronización entre dispositivos y dashboard web.
- Las categorías del catálogo (Terrestres, Acuáticas, Rapaces, Marinas, Otras) son agrupaciones que la app deriva de los órdenes taxonómicos de Aves de Chile; no las fija el backend.
- Las imágenes provienen de Aves de Chile y pueden tener licencias distintas: los créditos y condiciones se consultan en la página fuente.

## Brand Commitments

- Nombre: "CORON: Bitácora de Aves"; referencia de proyecto base declarada: "Aves de Chile". El launcher y el AppBar usan la marca corta "CORON".
- Experiencia visual inspirada en una red social de fotografía, sin funciones de chat ni seguimiento de perfiles; sistema visual definido en `mobile/DESIGN.md` con la paleta `PaletaCoron`.
- Interfaz y contenido en español (Chile).

## Evidence on Hand

- `README.md` (requisitos RF-01–RF-20 y equipos), `mobile/README.md` (alcance y estado de la app).
- `mobile/docs/modules/ROOT/pages/` con el PRD, la arquitectura, el plan UAT y el registro de cambios; los 20 requisitos funcionales los publica el equipo en su propio componente.
- `birds_apis.yaml` (especificación OpenAPI). El backend vive en `backend/aves` y expone la API que consume la app; el cliente ya implementa los endpoints de ese contrato.
- Catálogo cargado desde Aves de Chile en tiempo de ejecución (la interfaz anuncia 216 especies).
- Ausencias que el trabajo futuro no debe inventar: usuarios reales, métricas de uso, testimonios, contenido moderado o datos de lanzamiento.

## Product Principles

1. Los RF mandan: cada entrega se traza a un requisito y el alcance declarado pesa más que features extra.
2. Offline-first para lo personal: colección y avistamientos propios funcionan sin conexión.
3. Transparencia de la fuente: cada ficha enlaza su origen en Aves de Chile y las imágenes se atribuyen desde allí.
4. Social sin ruido: inspiración fotográfica, pero nunca chat ni seguimiento de perfiles.
5. Puente al BFF: la sesión demo no quiebra la migración futura a HTTP con token sin tocar las pantallas.
