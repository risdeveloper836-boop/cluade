# HIS Digital — Video promocional (51 s, vertical 9:16)

> Pronunciación de la marca en la locución: **"JIS DIGITAL"**.
> Tono: dramático y cercano en el problema; enérgico y optimista en la solución.

Archivo final: `his-digital-video.mp4` (1080×1920, 30 fps, con música).
Pensado para Reels, TikTok, Shorts y Estados de WhatsApp.

---

## Escenas y locución

| # | Tiempo | Escena (lo que se ve) | Locución sugerida |
|---|--------|-----------------------|-------------------|
| 1 | 0:00–0:06 | **El gancho.** Reloj rojo marca 11:47 p.m. Un **enfermero** agotado frente a su escritorio mientras le caen pilas de hojas HIS. | "Son las once y cuarenta y siete de la noche. El turno terminó hace horas… pero el HIS recién empieza." |
| 2 | 0:06–0:12 | **Enfermería.** Un contador sube hasta **40 niños en control CRED** y aparecen 40 hojitas. La **enfermera**, cansada. | "Cuarenta niños en CRED. Cuarenta hojas. Decenas de códigos que recordar… a mano." |
| 3 | 0:12–0:18 | **Obstetricia.** Lista de atención prenatal: un ítem queda tachado con el sello **OLVIDADO**. La barra "Meta del mes" cae de 80 % a 52 %. | "Un código olvidado… es producción perdida. Y tu meta, también." |
| 4 | 0:18–0:24 | **Nutrición y Psicología.** Hoja HIS con letra ilegible, signos de interrogación y la pantalla tiembla. | "Letra ilegible. DNI incompletos. Y el digitador… tiene que adivinar." |
| 5 | 0:24–0:30 | **El giro.** Pantalla negra y línea de electrocardiograma: "¿Y si el HIS se llenara en segundos?". Destello y aparece el logo **HIS Digital**. | "¿Y si el HIS se llenara en segundos? … Llegó **JIS DIGITAL**." |
| 6 | 0:30–0:38 | **La solución.** En el celular se elige el **Kit CRED** y se marcan solos todos los ítems del control. Sale la **hoja HIS en PDF** con el sello "LISTO PARA DIGITACIÓN". | "Elige el kit y todo se marca solo. Tu hoja HIS sale en PDF, lista para imprimir y pasar a digitación." |
| 7 | 0:38–0:44 | **Beneficios.** Tarjetas de enfermería, obstetricia, nutrición y psicología, más los mensajes: Funciona sin internet · Menos errores · Más producción · Hojas legibles. | "Hecho para todo tu equipo de salud: enfermería, obstetricia, nutrición y psicología. Funciona sin internet, con menos errores y más producción." |
| 8 | 0:44–0:51 | **Llamada a la acción.** Logo y "Deja el papel atrás". Botón amarillo **SOLICITA TU DEMO AHORA** y el equipo sonriendo. | "Deja el papel atrás. **JIS DIGITAL.** Ponte en contacto ahora y solicita tu demo." |

**Texto para la publicación (copy):**
> ¿Sigues llenando el HIS a mano hasta la medianoche? 😩
> Con **HIS Digital** registras la atención, aplicas el kit (CRED, prenatal, PF, salud mental…) y tu hoja HIS sale en PDF, lista para digitación. ✅
> Funciona sin internet. Menos errores, más producción.
> 👉 Escríbenos y solicita tu DEMO hoy.
> #HISDigital #Enfermería #Obstetricia #Nutrición #Psicología #SaludPerú #CRED #PrimerNivel

---

## Cómo agregar la voz

1. Graba la locución con el celular en un lugar silencioso, siguiendo los tiempos de la tabla. También puedes usar una voz IA en español latino, como ElevenLabs o la función "texto a voz" de CapCut.
2. En CapCut (o similar), importa `his-digital-video.mp4`, añade el audio de la voz y baja la música a ~30 %.
3. Agrega tu **número de WhatsApp o enlace** en la última escena (0:44–0:51).

---

## Versión con actores generados por IA (opcional)

Si quieres escenas con personas "reales", puedes generar clips en Veo, Sora, Kling o Runway con estos prompts y montarlos con los mismos textos. Usa siempre personajes ficticios, sin datos reales de pacientes y sin logos oficiales.

1. *Cinematic vertical shot, night, small rural health post in Peru, tired Peruvian male nurse in teal scrubs writing on stacks of paper forms under a warm desk lamp, wall clock showing 11:47 PM, moody lighting, shallow depth of field.*
2. *Peruvian female nurse in teal scrubs with stethoscope, surrounded by dozens of paper forms, rubbing her eyes, child growth-control room with weighing scale in the background, dramatic cool lighting.*
3. *Peruvian female midwife (obstetrician) in purple scrubs looking worried at a paper checklist, prenatal care office, close-up of a red pen, tense atmosphere.*
4. *Peruvian male nutritionist and female psychologist with glasses in white coats, frustrated, looking at a messy handwritten form, data-entry clerk squinting at a computer in the background.*
5. *Black screen, glowing cyan heartbeat line crossing the frame, then a bright flash revealing a clean modern app logo on teal gradient.*
6. *Smiling Peruvian female nurse tapping a smartphone app in a bright modern health center, a printer printing a neat form, positive warm lighting.*
7. *Diverse Peruvian health team (nurse, midwife, nutritionist, psychologist) smiling together in a bright clinic hallway, confident, celebratory mood.*

---

## Cómo editar o volver a generar el video

- `escenas.html`: todas las escenas (texto, colores, tiempos). Se puede abrir en el navegador para verlo animado, o con `?t=12` para congelar un instante.
- `musica.py`: banda sonora sintetizada (sin derechos de terceros).
- `render.js`: genera el MP4.

```bash
python3 musica.py                                  # crea musica.wav
NODE_PATH=$(npm root -g) node render.js             # crea his-digital-video.mp4
```
Requiere Node con Playwright (Chromium), Python 3 con numpy, y ffmpeg.
