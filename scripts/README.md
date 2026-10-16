# scripts/

Utilidades sueltas del repositorio. Hoy queda un único script: los que probaban
el BFF y el backend se eliminaron junto con `bff/` y `backend/`.

## `mock_backend.dart`

Servidor HTTP que **simula el backend Phoenix** sin necesidad de Elixir ni de
PostgreSQL. Reproduce las 4 rutas de autenticación que consume la app:

| Método | Ruta | Respuesta |
|---|---|---|
| `POST` | `/api/user/signin` | `201 {data:{token, user:{id,user,rol}}}` |
| `POST` | `/api/user/login` | `200 {data:{token, user:{id,user,rol}}}` |
| `GET` | `/api/user/me` | `200 {user:{id,user,rol}}` (requiere `Bearer`) |
| `DELETE` | `/api/user/logout` | `200 {message}` |

No valida credenciales: devuelve el usuario que se le pidió, para que el perfil
muestre lo mismo que se escribió en el formulario. El identificador viaja como
`user`, tal como fija `birds_apis.yaml`.

### Uso

```powershell
# Escucha en 0.0.0.0:4001 (puerto del backend real)
dart scripts\mock_backend.dart

# Puerto alternativo
dart scripts\mock_backend.dart --port 5000
```

### Cuándo tiene sentido

Cuando exista un BFF, se le puede apuntar a este mock en lugar del Phoenix real:

```powershell
$env:BACKEND_URL = 'http://127.0.0.1:4001'
```

**Hoy por defecto la app corre en modo mock local** (`ApiConfig.usarMock`),
así que no necesita ningún servidor: `mock_backend.dart` es solo el puente que
hará falta para probar `app → BFF` sin levantar Phoenix y PostgreSQL.

## Verificación de la app móvil

```powershell
cd mobile
flutter analyze
flutter test
```

## Documentación

```powershell
npm ci
npm run docs
