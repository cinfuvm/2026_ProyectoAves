# Bitácora de Aves (CORON)

Sistema de administración de datos de aves de Chile y bitácora de avistamientos por usuario.

El proyecto se compone de cuatro partes:

| Componente | Tecnología | Carpeta |
|---|---|---|
| API REST | Elixir, Phoenix, Ash, PostgreSQL | [`backend/`](backend/) |
| Sitio web y dashboard | Elixir, Phoenix LiveView | [`landing/`](landing/) |
| Aplicación móvil | Flutter (Android e iOS) | [`mobile/`](mobile/) |
| Documentación | Antora (AsciiDoc) | [`docs/`](docs/) |

## Requisitos funcionales

El detalle completo está en [`docs/modules/ROOT/pages/requisitos.adoc`](docs/modules/ROOT/pages/requisitos.adoc).

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

## Puesta en marcha

### Backend (API REST)

Requiere Docker Desktop, Elixir 1.20 y OTP 29.

```bash
docker compose up -d db

cd backend/aves
mix deps.get
mix ecto.create
mix ash.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

Queda en `http://127.0.0.1:4000`. Las instrucciones completas (permisos, seeds, colección de Bruno y pruebas) están en [`backend/readme.md`](backend/readme.md).

### Landing y dashboard

Requiere Elixir. El landing **no usa base de datos** (no depende de Ecto). Ambos proyectos Phoenix usan el puerto 4000 por defecto, así que el landing se levanta con otro puerto:

```bash
cd landing
mix deps.get
PORT=4001 mix phx.server
```

Queda en `http://127.0.0.1:4001`. Ver [`landing/readme.md`](landing/readme.md).

### Aplicación móvil

Requiere Flutter y un emulador o dispositivo conectado.

```bash
cd mobile
flutter pub get
flutter run
```

Por defecto la app usa datos mock. Para conectarla al backend:

```bash
flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://10.0.2.2:4000
```

En el emulador de Android, `10.0.2.2` apunta al `localhost` de la computadora. El detalle de funcionalidades y estado está en [`mobile/readme.md`](mobile/readme.md).

### Documentación

La documentación general se escribe con [Antora](https://antora.org/) en `docs/` (requiere Node.js 18 o superior):

```bash
npm ci
npm run docs
```

El sitio queda en `build/site/index.html`. Para agregar una página, crea un archivo `.adoc` en `docs/modules/ROOT/pages/` y agrégalo a `docs/modules/ROOT/nav.adoc`.

La documentación propia de la app móvil (PRD, arquitectura C4, UAT y changelog) vive en `mobile/docs/` y se genera desde `mobile/` con `npm ci && npm run docs`; también puedes construir ambas con `npm run docs:all` desde la raíz.
