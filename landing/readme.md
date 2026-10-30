# Landing y dashboard

Sitio web del proyecto **CORON: Bitácora de Aves** hecho con Elixir y Phoenix
LiveView. **No usa base de datos** (no depende de Ecto) ni requiere el backend
para arrancar.

## Puesta en marcha

Requiere Elixir y Erlang. Desde la raíz del repositorio:

```bash
cd landing
mix setup
PORT=4001 mix phx.server
```

Queda en `http://127.0.0.1:4001`.

El puerto por defecto de Phoenix es el 4000, que ya ocupa la API REST. Si el
backend no está corriendo puedes omitir `PORT=4001` y usar
`http://127.0.0.1:4000`.

En PowerShell, para fijar el puerto:

```powershell
$env:PORT="4001"; mix phx.server
```

`mix setup` instala dependencias y compila los assets (Tailwind y esbuild).

## Rutas

| Ruta | Descripción |
|---|---|
| `/` | Página pública del proyecto |
| `/login/` | Inicio de sesión |
| `/signup/` | Registro de usuario |
| `/admin/` | Panel de administración (métricas, usuarios, reportes) |
| `/admin/aves/` | Administración del catálogo de aves |
| `/admin/aves/new/` | Alta de un ave |
| `/admin/aves/:id/edit/` | Edición de un ave |
| `/moderator/` | Cola de reportes para moderación (RF-14) |
| `/propaganda/` | Sitio promocional del proyecto |

En desarrollo también están disponibles `/dev/dashboard` (LiveDashboard) y
`/dev/mailbox` (vista previa de correos).

## Estado actual

Las vistas del dashboard y del sitio muestran **datos de ejemplo definidos en
el propio LiveView**; todavía no consumen la API REST de `backend/`. La
conexión con el backend es trabajo pendiente.

## Pruebas

```bash
cd landing
mix test
```

También existe `mix precommit`, que compila con warnings como errores, formatea
y corre las pruebas. No se necesita base de datos para ninguna de las dos.

## Estructura

- `lib/landing_web/live/` — LiveViews (`admin_live`, `moderator_live`,
  `propaganda_live`, `login_live`, `signup_live`).
- `lib/landing_web/components/layouts/` — layouts por sección.
- `assets/` — CSS y JS (Tailwind y esbuild).
- `priv/static/images/` — logos e isotipo de la marca.
