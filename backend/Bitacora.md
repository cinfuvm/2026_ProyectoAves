# Proyecto 2: Bitácora de Aves  
Utilizando la información proporcionada en el proyecto base "Aves de Chile" se debe crear un sistema de administración de datos de aves y bitácora de visualización por usuario. El cual permita realizar un CRUD completo de cada ave y ser mostrada en un frontend con una API Rest o GraphQL. Esta debe ser desplegada utilizando Github Actions a un servidor en Fly.io.  
* Equipo Frontend Dashboard Web: 3 personas.  
* Equipo Frontend Mobile: 3 personas.  
* Equipo Backend: 3 personas.  
* Equipo Devops, Gestión y Documentación: 2 personas.  
## Requisitos  
* El proyecto debe permitir tener un buscador de las aves utilizando la API REST (https://www.openapis.org/) o GraphQL (a elección) (con Phoenix, Ash Framework y Bruno)  
* El proyecto debe permitir a usuarios registrarse y añadir aves visualizadas a su colección personal.  
* El proyecto debe contar con un panel de administración para gestión de usuarios, aves y colecciones personales de visualización de aves.  
* La visualización de aves debe ser añadida como Lugar, Fecha, Comentario y Fotografía.  
* Se debe poder reportar una foto que no sea de un ave para que sea vista por un moderador.  
* El proyecto debe mostrar "Aves populares" donde se muestra cuáles han sido las más vistas por los usuarios.  
* Utilización de frameworks CSS permitida. (Tailwind, Bootstrap, UIKit, otro).  
* Utilización de OpenCode permitida.  
* Aplicación Mobile (Android e iOS) solo Nativo, Flutter, Mob o Flet permitido (No PWA, No React Native).  
* Documentación con Antora Docs y Bruno.  
* En pocas palabras es como un Instagram de Aves Chilenas, pero sin las funciones de chat o seguir perfiles, solo subir fotos según categoría y agregar las fotos de otros usuarios a una colección personal. Usar templates de ejemplo como https://www.graphicpear.com/instagram-mockup-and-ui-template/  
## Entregables  
* Frontend en un framework definido: LiveView + CSS Framework (Tailwind, UIKit, otro). Uso de Docker recomendado para desarrollo local.  
* Backend en Elixir Phoenix. API Rest + Bruno + PostgreSQL. Además de un Dashboard Grafana que tenga las Golden metrics. Uso de Docker para levantamiento local de servidor y base de datos.  
* Creación de Github Actions y scripts de Despliegue. (Yaml, Docker, Fly.io).  
* Documentación en Antora Docs. Planificación del Proyecto siguiendo buenas prácticas de Ingeniería de Software. Manual de usuario del sistema.  
* URL pública del proyecto funcionando en fly.io o en un servidor vps (digital ocean, hetzner, propio)  
* Aplicaciones Web, Android e iOS.  
## Flujo de Trabajo  
Los equipos serán distribuidos de la siguiente forma:  
* El equipo de frontend web (LiveView) debe realizar un dashboard de administración que solo sea utilizado por administradores y moderadores del sitio (permite modificar usuarios y contenido). Además de un sitio web landing page que fomente a las personas a instalar la aplicación mobile.  
* El equipo de frontend mobile debe realizar la aplicación que permita subir fotos e buscar (según categorías de cada ave), e interactuar con fotos subidas por los demás usuarios, además de reportar fotografías que no son apropiadas (no son relativa a aves).  
* El equipo de backend (Phoenix, Ash y Postgres) debe crear un sistema que soporte tanto el dashboard administrativo web como el frontend mobile.  
* Todos los equipos estarán haciendo commits y cambios en un solo repositorio (mono repo)  
* Debe realizar el despliegue a fly.io correctamente y tener las aplicaciones funcionando en un simulador o dispositivo real  
