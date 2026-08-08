# Mini GTA Godot 4

Prototipo sencillo inspirado en juegos de mundo abierto.

## Incluye
- Personaje 3D en tercera persona
- Cámara con ratón
- WASD para moverse
- Espacio para saltar
- Colisiones
- Ciudad prototipo con edificios básicos
- Marcador de misión
- UI de misión
- Coche 3D conducible con sistema de entrar/salir

## Abrir
1. Instala Godot 4.x.
2. Abre Godot > Importar.
3. Selecciona `project.godot`.
4. Pulsa Ejecutar (F6/F5).

## Controles
- WASD: movimiento
- Ratón: cámara
- Espacio: salto
- Esc: liberar el ratón
- E: entrar/salir del coche
- WASD: conducir (cuando estás dentro)

## Assets de Fab
Pon modelos `.glb`/`.gltf` dentro de `assets/` y arrástralos a la escena desde Godot. No se incluyen assets de Fab en este ZIP porque sus licencias dependen de cada recurso.

## Coche
Acércate al coche y pulsa `E`. Mientras conduces, usa `WASD`; pulsa `E` otra vez para salir.
# Prueba en Android

El juego mantiene los controles de PC y activa automáticamente la interfaz táctil en Android:

- Joystick izquierdo: caminar; al llevarlo al borde, correr.
- Arrastrar en la zona derecha: mover la cámara.
- `SALTAR`, `ACCIÓN`, `ARMA` y `DISPARAR`: acciones a pie.
- Dentro del coche, el joystick controla dirección y aceleración y `SALIR` abandona el vehículo.
- En PC se puede pulsar `F10` para mostrar u ocultar la previsualización táctil.

Para probar por USB:

1. Instalar las plantillas de exportación de la misma versión de Godot.
2. En Godot, configurar Java SDK Path y Android SDK Path.
3. Activar Opciones de desarrollador y Depuración USB en el teléfono.
4. Conectar el teléfono, aceptar la huella RSA y comprobarlo con `adb devices`.
5. Abrir el proyecto y usar Ejecutar en dispositivo, o exportar `build/android/mini-gta.apk` e instalarlo con `adb install -r`.
