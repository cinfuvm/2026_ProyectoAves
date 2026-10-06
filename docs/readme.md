# Documentación

## Autenticación y BFF

La app móvil incluye por ahora una autenticación de demostración local:
`AuthService` guarda la sesión del usuario en `SharedPreferences`.

El backend está planificado como un BFF/API REST en `backend/`.
Cuando se implemente, los flujos de `AuthService` deberán reemplazarse por
llamadas HTTP con token seguro, sin cambiar la interfaz de las pantallas de
perfil y login.

Flujo objetivo futuro:
1. Login con email/contraseña contra el BFF.
2. Recepción de token de sesión.
3. Perfil consultado con token.
4. Cierre de sesión invalidando token en servidor.
