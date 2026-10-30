# Colección Bruno: Aves API

Colección de pruebas de los endpoints del backend. Se puede usar desde la app de Bruno o desde el CLI.

## Requisitos

1. Base de datos y servidor corriendo (ver `backend/aves`):
   ```
   docker compose up -d db
   cd backend/aves && mix phx.server
   ```
2. Usuarios de prueba: `usuario@aves.test`, `moderador@aves.test` y `admin@aves.test`, con contraseña `supersecret123`. Se crean con `mix run priv/repo/seeds.exs`.

## Uso

Abrir la carpeta `backend/bruno` en Bruno y elegir el entorno **Local**, o por CLI:

```
cd backend/bruno
npx @usebruno/cli run -r --env Local
```

La colección se puede correr varias veces seguidas: cada corrida crea sus propios datos de prueba.

## Estructura

| Carpeta | Contenido |
|---|---|
| `auth` | Registro, logins por rol (guardan `token`, `moderadorToken` y `adminToken`), perfil |
| `categorias` | CRUD de categorías |
| `aves` | Búsqueda, ranking, ficha (RF-07), CRUD de aves |
| `avistamientos` | Bitácora, registro con y sin foto, edición y borrado |
| `fotos` | Crea una foto de otro usuario y lista fotos ajenas (RF-11) |
| `coleccion` | Guardar y quitar de la colección (RF-12) |
| `reportes` | Reportar, listar pendientes, aprobar y retirar (RF-13, RF-14) |
| `sesion-final` | Cierra la sesión del usuario. Ejecutar al final |

## Tokens: cuál usa cada request

Cada login guarda su token en una variable:

| Variable | Quién la llena | La usan |
|---|---|---|
| `token` | **Cualquier login**: la última sesión iniciada | Requests generales (perfil, ranking, búsquedas, fotos ajenas, categorías). Si inicias sesión como admin, estas requests van como admin. |
| `userToken` | Solo `Login usuario` | Requests que dependen de quién creó el dato: avistamientos propios, colección, reportes, edición del perfil de usuario y `Cerrar sesion`. |
| `moderadorToken` | `Login moderador` | Crear y editar aves y categorías, reportes pendientes, aprobar y retirar. |
| `adminToken` | `Login admin` | Eliminar aves y crear la foto de otro usuario. |

Por eso, si solo inicias sesión como admin, las requests generales funcionan. Las que dependen de `userToken` responden 401 hasta ejecutar `Login usuario`.

## Variables que se encadenan

Los scripts de cada request guardan IDs para las siguientes:

- `birdId`: primera ave de la búsqueda por nombre.
- `categoryId`: primera categoría del listado.
- `nuevaCategoriaId`, `nuevaAveId`: registros que crea la colección y que luego edita y borra.
- `photoId`: foto del admin que creó "Crear foto de otro usuario".
- `sightingId`, `collectionItemId`, `reportId`: registros de cada flujo.

Los nombres de los registros de prueba llevan un sufijo con la hora (`Date.now()`), así que no chocan con corridas anteriores.

## Notas

- **Registrar avistamiento con foto:** sube `fixtures/ave.png`, una imagen de prueba.
- **Registrar usuario:** responde 422 si `nuevo@aves.test` ya existe. La request acepta ambos casos.
- **Eliminar categoria y Eliminar ave:** borran solo los registros que creó la colección. Una categoría con aves no se puede borrar (422), y tampoco un ave con avistamientos.
- **Cerrar sesion:** revoca el token de `usuario`. Por eso va en la última carpeta.
