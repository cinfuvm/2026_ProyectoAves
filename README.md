# Bitácora de Aves

Sistema de administración de datos de aves de Chile y bitácora de avistamientos por usuario. Incluye una API REST (Elixir Phoenix), un dashboard web de administración (LiveView) y una aplicación móvil para Android e iOS.

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

## Documentación

La documentación se escribe con [Antora](https://antora.org/) en la carpeta `docs/`.

Para generarla en local (requiere Node.js 18 o superior):

```
npm install
npx antora antora-playbook.yml
```

El sitio queda en `build/site/index.html`.

Para agregar una página, crea un archivo `.adoc` en `docs/modules/ROOT/pages/` y agrégalo a `docs/modules/ROOT/nav.adoc`.

## Landing y API

La landing usa la API del backend para registrar e iniciar sesión. En la primera ejecución, configura PostgreSQL y ejecuta `mix setup` en el backend. Inicia el backend en el puerto `4000` y luego la landing en otro puerto:

```powershell
cd backend\aves
mix phx.server
```

En otra terminal:

```powershell
cd landing
$env:PORT = "4001"
$env:AVES_API_URL = "http://localhost:4000"
mix phx.server
```

Abre `http://localhost:4001/propaganda/`. `AVES_API_URL` debe apuntar a la URL base del backend; la landing mantiene el token de autenticación en una cookie de sesión cifrada.
