# Prompts das cenas da simulação visual (Gemini, 3:2, depois recorte para 14:9)

Gerar: `python3 docs/gen-cena.py gemini-3-pro-image saida.png prompt.txt 3:2` (chave em `~/.config/iolcalc/gemini.key`).

## Dia — cafeteria

```
Photorealistic first-person point-of-view photograph, seen through the eyes of a person sitting at a wooden table in a bright, cozy café during the day. Composition, from near to far:
- Lower foreground, slightly right of center: the person's own right hand holding a modern smartphone at reading distance (about 40 cm), screen facing the camera, tilted only slightly; the screen is completely blank, plain light gray, no interface.
- Middle distance on the table (about 65 cm away): an open laptop facing the camera with a completely blank white screen, no interface; next to it a cup of coffee.
- Background left: a wall with a chalkboard menu with clearly legible handwritten prices and several framed photographs.
- Background right: a large window onto a city street with parked cars, shop signs with legible text and pedestrians.
Everything must be sharp and in focus from the phone to the street (deep depth of field, small aperture). Natural daylight, soft shadows, realistic colors, 28 mm lens, no motion blur, no bokeh, no people's faces in the foreground, no text on the screens.
```

## Noite — direção

```
Photorealistic first-person point-of-view photograph from the driver's seat of a car at night, looking straight through the windshield, the driver's two hands on the steering wheel in the lower part of the frame. Composition, from near to far:
- Lower right foreground: the front passenger's hand holds a modern smartphone toward the camera at reading distance (about 40 cm); its screen is completely blank, plain dark gray, no interface.
- Center of the dashboard (about 65 cm away): a car infotainment navigation screen, completely blank dark screen, no interface; illuminated instrument cluster.
- Through the windshield, close ahead: a car stopped at an intersection, its rear license plate large and clearly legible, brake lights on.
- Above the intersection a traffic light showing red; on the right, road signs with legible text; illuminated storefront signs, street lamps and the headlights of oncoming cars in the distance.
Everything must be sharp and in focus from the phone to the traffic light (deep depth of field). Realistic night exposure, clean windshield, no rain, no motion blur, no bokeh, no lens flare, no text on the screens.
```
