---
name: Bitácora de Aves
description: Sistema visual móvil — fotografía de aves chilenas con morado de cordillera, amarillo de sol y serif con carácter.
colors:
  violeta-cordillera: "#5B2D91"
  violeta-claro: "#8B5CC7"
  lavanda-suave: "#F2EAFB"
  sol-de-mediodia: "#FFD447"
  sol-tenue: "#FFE88A"
  fondo-dia: "#FBF8FF"
  superficie-dia: "#FFFCFF"
  cuerpo-dia: "#403A48"
  secundario-dia: "#6E6379"
  borde-dia: "#E5D8F5"
  fondo-noche: "#15111C"
  superficie-noche: "#1D1726"
  cuerpo-noche: "#E5DFEB"
  borde-noche: "#51415F"
  blanco: "#FFFFFF"
typography:
  display:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "30px"
    fontWeight: 700
  headline:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "28px"
    fontWeight: 700
  title:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "22px"
    fontWeight: 700
  body:
    fontFamily: "Roboto, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  label:
    fontFamily: "Roboto, Arial, sans-serif"
    fontSize: "12px"
    fontWeight: 500
rounded:
  xs: "4px"
  chip: "14px"
  md: "16px"
  field: "18px"
  pill: "20px"
  card: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "20px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.violeta-cordillera}"
    textColor: "{colors.blanco}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  button-fab:
    backgroundColor: "{colors.sol-de-mediodia}"
    textColor: "{colors.violeta-cordillera}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "16px 20px"
  chip-selected:
    backgroundColor: "{colors.violeta-cordillera}"
    textColor: "{colors.blanco}"
    rounded: "{rounded.chip}"
    padding: "8px 14px"
  chip:
    backgroundColor: "{colors.superficie-dia}"
    textColor: "{colors.violeta-cordillera}"
    rounded: "{rounded.chip}"
    padding: "8px 14px"
  card-ave:
    backgroundColor: "{colors.superficie-dia}"
    rounded: "{rounded.card}"
    padding: "16px"
  input:
    backgroundColor: "{colors.superficie-dia}"
    textColor: "{colors.cuerpo-dia}"
    rounded: "{rounded.field}"
    padding: "16px 18px"
  nav-indicator:
    backgroundColor: "{colors.sol-de-mediodia}"
    rounded: "{rounded.pill}"
    padding: "6px 16px"
---

# Design System: Bitácora de Aves

## Overview

**Creative North Star: "El Mirador"**

El sistema es un mirador fotográfico: la imagen del ave es el observado y la interfaz es el punto de observación. La personalidad es lúdica y fotográfica — cercana a una red social de fotos sin ser una red social — con la calidez de quien sale a mirar aves al amanecer. La estructura es de app operativa (Material 3, navegación fija, tarjetas escaneables), pero la voz la pone una serif con carácter (Fraunces) sobre una base robusta y neutra (Roboto), y una pareja de color de paisaje chileno: el morado de la cordillera al atardecer y el amarillo del sol de mediodía.

La profundidad se resuelve en capas cálidas: fondos con gradiente sutil, tarjetas que flotan con sombras teñidas de morado y barras (app y navegación) que son gradiente en sí mismas. Nada de grises neutros ni esquinas rectas. El momento focal del sistema es la foto: al tocarla, la imagen crece a un visor a pantalla completa con transición Hero.

**Key Characteristics:**

- Pareja cromática fija: Violeta Cordillera + Sol de Mediodía, con neutros teñidos de violeta.
- Dos voces tipográficas: Fraunces para títulos, Roboto para cuerpo y controles.
- Esquinas generosas: 24px en tarjetas, píldoras en acciones.
- Gradiente morado→violeta como firma en app bar y barra de navegación.
- Amarillo solar siempre como acento de selección (píldora del nav, FAB, reglas decorativas).

## Colors

La paleta es un paisaje: morado profundo de fondo, amarillo de sol como señal, y neutros que nunca son gris puro sino violetas claros o cálidos.

### Primary

- **Violeta Cordillera** (#5B2D91): el color de la marca. Gradiente de app bar y navegación, títulos de ave en modo claro, botones primarios, chips seleccionados, iconos de marca. En modo oscuro su rol lo toma un claro equivalente (primary #D1B2FF) para conservar legibilidad.
- **Violeta Claro** (#8B5CC7): terminación del gradiente de cabeceras destacadas y segundo paso del gradiente de marca; nunca como color de texto sobre fondos claros.

### Secondary

- **Sol de Mediodía** (#FFD447): el acento. Píldora indicadora de la navegación, FAB "Agregar foto", círculo del toggle día/noche, reglas decorativas y estados de destacado. Siempre sobre superficie morada u oscura.
- **Sol Tenue** (#FFE88A): final del gradiente propio del FAB; solo como matiz de ese gradiente.

### Neutral

- **Fondo Día** (#FBF8FF) / **Superficie Día** (#FFFCFF): scaffold y tarjetas en modo claro.
- **Cuerpo Día** (#403A48) / **Secundario Día** (#6E6379): texto de descripción y texto secundario (metadatos, notas). El secundario está siempre teñido de violeta.
- **Borde Día** (#E5D8F5): bordes de inputs y chips en modo claro; lavanda, no gris.
- **Fondo Noche** (#15111C) / **Superficie Noche** (#1D1726): scaffold y tarjetas en modo oscuro.
- **Cuerpo Noche** (#E5DFEB) / **Borde Noche** (#51415F): equivalente oscuro de cuerpo y borde.

### Named Rules

**La Regla del Sol.** El amarillo nunca es color de texto ni icono suelto sobre fondo claro (falla contraste); solo actúa sobre morado o superficie oscura, donde su fuerza es la señal de selección.

**La Regla de los Grises Tinteados.** Nunca gris neutro (`Colors.grey`) en texto, bordes ni estados secundarios; todo neutro se tiñe de violeta o se toma de la escala Neutral documentada arriba.

## Typography

**Display Font:** Fraunces (con Georgia, serif)
**Body Font:** Roboto (con Arial, sans-serif)

**Character:** Fraunces aporta el carácter editorial-lúdico: títulos con presencia, ligeros y conversadores. Roboto desaparece en función: cuerpo, controles y etiquetas de navegación con máxima claridad a 12–15px.

### Hierarchy

- **Display** (700, 30px): títulos de cabecera destacada ("Aves de Chile", "Explora y descubre").
- **Headline** (700, 28px): títulos de sección ("Tu colección", "Aves guardadas", estados vacíos).
- **Title** (700, 22px): nombres de ave en tarjetas; en la app bar el título de pantalla usa Fraunces 700 a 20px con letter-spacing -0.2px.
- **Body** (400, 15px): descripciones, formulario y textos largos. Las notas al pie y metadatos bajan a 11–12px en Roboto con color secundario teñido.
- **Label** (500, 12px): chips, navegación y botones; el destino seleccionado sube a 700. Botones grandes usan label a mayor escala de Material.

### Named Rules

**La Regla de las Dos Voces.** Fraunces habla (títulos, celebración, nombre del ave); Roboto trabaja (cuerpo, controles, metadatos). No se cruzan: ningún párrafo en Fraunces, ninguna etiqueta de control en Fraunces.

## Layout

Modelo de una sola columna, móvil primero (verificado a 1080×2400 y con escala de fuente 1.3). Margen lateral constante de 16px en listas y formularios; ritmo vertical de 8/16/20/24px según jerarquía. AppBar fija arriba (gradiente, 56px + área de status), navegación de 4 destinos fija abajo (gradiente, indicador tipo píldora); el cuerpo se desplaza entre ambas. El catálogo deja 96px de padding inferior para que el FAB nunca tape acciones de la última tarjeta. Las listas son de tarjetas apiladas sin grid; los filtros viven en chips con scroll horizontal. El visor de foto rompe el layout a pantalla completa (negro, sin chrome, InteractiveViewer).

## Elevation & Depth

El sistema es de capas cálidas, no plano: las tarjetas se elevan con sombras teñidas de morado en modo claro y negras suaves en modo oscuro; las barras no usan sombra (elevation 0) porque su profundidad ya la da el gradiente; el fondo del scaffold es un gradiente diagonal muy sutil que da aire a toda la app.

### Shadow Vocabulary

- **Sombra de tarjeta** (representativa: `0 6px 20px rgba(91,45,145,0.12)`, elevación 5): tarjetas de ave y superficies elevadas en modo claro; el tinte morado es obligatorio.
- **Sombra de tarjeta en noche** (representativa: `0 6px 20px rgba(0,0,0,0.25)`): mismo rol en modo oscuro.
- **Barras sin sombra** (elevation 0): app bar y navegación jamás proyectan sombra.

### Named Rules

**La Regla de la Sombra Cálida.** Toda sombra en modo claro se tiñe de Violeta Cordillera al 12%; prohibido el gris/negro puro sobre fondo claro.

## Shapes

Lenguaje generoso y táctil: nada de esquinas rectas. Las tarjetas usan 24px de radio (silueta casi suave), los campos de texto 18px, las acciones son píldoras (20px+ efectivo), los chips 14px y los micro-badges 4px. Los bordes son finos (1–1.5px) y siempre lavanda en día o violeta oscuro en noche; el foco sube a 1.5px en Violeta Cordillera. Todo lo redondeable se redondea: snackbar 16px, indicador de navegación píldora, círculo del toggle.

## Components

### Buttons

- **Shape:** píldoras (radio 20px+); el FAB extendido y "Entrar" son píldoras completas.
- **Primary (FilledButton):** fondo Violeta Cordillera, texto blanco, label Roboto; presión = elevación sutil.
- **FAB "Agregar foto":** fondo Sol de Mediodía con gradiente a Sol Tenue, texto e icono en Violeta Cordillera; flota abajo a la derecha con 16px de margen.
- **Outlined ("Guardar"):** contorno Violeta Cordillera sobre tarjeta, texto morado; estados de toque a 150–180ms.

### Chips

- **Style:** fondo Superficie, texto Violeta Cordillera, borde lavanda 1px, radio 14px.
- **State:** seleccionado = relleno Violeta Cordillera con texto blanco y check; no seleccionado mantiene borde. Se usan para categorías y filtros con scroll horizontal.

### Cards / Containers

- **Corner Style:** 24px.
- **Background:** Superficie (día/noche); la imagen ocupa el tercio superior a sangre con esquinas superiores heredadas.
- **Shadow Strategy:** Sombra de tarjeta (ver Elevation).
- **Internal Padding:** 16px; dentro, el orden es imagen → chips superpuestos → título Fraunces → nombre científico itálico → cuerpo → acciones.

### Inputs / Fields

- **Style:** fondo Superficie, borde lavanda 1px, radio 18px, padding 16×18px.
- **Focus:** borde 1.5px en Violeta Cordillera (o #D1B2FF en noche); sin glow.
- **Error:** hereda color de error Material; el mensaje va debajo en label pequeño.

### Navigation

- **Style:** barra de gradiente morado (misma familia que la app bar), 4 destinos, sin sombra.
- **States:** el seleccionado muestra píldora Sol de Mediodía bajo el icono, icono en Violeta Cordillera a 26px y etiqueta blanca 700; los no seleccionados, icono y etiqueta en blanco al 72%, 24px/500.

### [Signature Component] Visor de foto (Hero)

La fotografía es el momento focal: al tocarla, la imagen viaja con Hero desde la tarjeta a un visor a pantalla completa (fondo negro, chrome mínimo: X de cierre, título Fraunces blanco y nombre científico itálico), con transición de entrada 480ms y salida 360ms, InteractiveViewer para zoom/pan y scrim para legibilidad del título.

### [Signature Component] Barras en gradiente

App bar y navegación comparten la firma: gradiente morado→violeta, badge/logo en círculo amarillo con el búho, título Fraunces blanco y toggle día/noche en círculo Sol de Mediodía con icono morado.

## Do's and Don'ts

### Do:

- **Do** usar Violeta Cordillera como color de títulos, acciones primarias y selección en fondos claros.
- **Do** usar Fraunces solo para títulos, nombres de ave y momentos de celebración; Roboto para todo lo demás.
- **Do** mantener las sombras teñidas de morado al 12% en modo claro y la profundidad en capas (gradientes de fondo + tarjetas elevadas).
- **Do** reservar Sol de Mediodía para píldoras de selección, FAB y acentos sobre superficie morada/oscura.
- **Do** respetar el ritmo de 16px de margen lateral y dejar 96px de cola en listas con FAB.

### Don't:

- **Don't** usar gris neutro para texto secundario, bordes o estados apagados — todo neutro es violeta.
- **Don't** usar amarillo como color de texto ni icono aislado sobre fondo claro.
- **Don't** poner descripciones ni párrafos en Fraunces, ni etiquetas de control en Fraunces.
- **Don't** dibujar esquinas rectas ni radios menores a 14px en superficies grandes.
- **Don't** agregar sombra gris a las barras ni elevar la app bar; su profundidad es el gradiente.
