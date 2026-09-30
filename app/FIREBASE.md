# Firebase de Anivermaru

Proyecto: `cumplemes`. Android: `cl.nuestrorincon.nuestro_rincon`.
Storage: `gs://cumplemes.firebasestorage.app`.

## Servicios

- Authentication: acceso con Google. La identidad estable es el UID, no el correo.
- Firestore `players/{uid}`: perfil privado y espacio seleccionado.
- `players/{uid}/progress/current`: guardado de monedas, cartas y variantes, garantía de legendaria, partida de bloques, Wordlady/pistas/recompensas, Candy Churu Cat y récord de Ascenso.
- `progress/current/recovery`: copias conservadas al resolver conflictos entre dispositivos.
- `spaces/{id}/members`, `notes`: mural privado mediante listeners. `scores` se conserva por compatibilidad con versiones anteriores.
- `game_scores/{uid}_{game}`: rankings globales de los cuatro juegos para usuarios autenticados; no requieren compartir mural.
- Storage `spaces/{id}/notes/{note}/{version}`: fotos y dibujos. Firestore contiene referencias; no almacena imágenes base64.
- Realtime Database `spaces/{id}/presence/{uid}/{connection}`: presencia por conexión, retirada automática con `onDisconnect`.

## Uso

1. En Inicio, pulsa **Continuar con Google**.
2. El progreso de invitado se vincula a esa cuenta. Se conserva el guardado local cuando no hay conexión.
3. En **Nuestro bloc**, abre **Compartir / unirme al bloc** y envía el código solo a la persona invitada. Conocer ese código aleatorio de 20 caracteres permite unirse. No existe listado público de espacios.
4. Otra persona inicia sesión con su propio Google y pega el código para compartir el mural. Las cartas y monedas son personales; los rankings no dependen de esa invitación.

Cada juego tiene **Ver clasificación** dentro de su recuadro de Inicio. Muestra los resultados de ese juego de todos los jugadores autenticados, ordenados de mayor a menor y actualizados en vivo. Wordlady se clasifica por victorias; los demás por puntos. Las reglas impiden escribir por otro UID o disminuir su récord.
5. En otro dispositivo, usa el mismo Google para recuperar tu progreso. Si ambos dispositivos avanzaron desde el último guardado común, debes elegir cuál conservar; ambas versiones se archivan. No se suman monedas ni cartas automáticamente.
6. Al cerrar sesión y entrar con otra cuenta, los guardados locales se separan y archivan por UID.

Los dibujos siguen siendo imágenes editables en el pintor; no se conserva un historial vectorial de trazos. Notas pendientes tienen IDs estables y cola persistida, con reintentos. Las partidas abiertas no se reemplazan por guardados remotos hasta regresar al menú.

## Sin conexión y reconexión

- Guardado local antes de red: notas/fotos/dibujos y tablero, monedas, cartas y récords permanecen en preferencias.
- La interfaz no espera una subida para terminar de guardar una nota. Reintentos periódicos de progreso y notas, además de intentar al regresar a la app.
- La cuenta y el espacio recordados permiten arrancar sin internet; si falla la consulta de perfil, se reintenta sin bloquear los juegos.
- `HighscoreOutbox` toma los mejores resultados locales; solo confirma por UID/juego tras subir. Un fallo no bloquea los demás, y una nueva marca durante la subida queda pendiente.
- La cola sobrevive reinicios. Una caché Firestore incompleta no debe eliminar notas locales; fallos de Storage no eliminan textos ni adjuntos locales.
- No hay subida permanente con la app cerrada. La sincronización se completa al abrirla o mantenerla abierta con conexión. Primer login/registro requiere internet.
- Conflictos de progreso entre dispositivos siguen requiriendo elegir versión; se conservan copias. Notas concurrentes usan la última escritura por nota, no una fusión de texto/trazos.

## Android y web

Google habilitado en Authentication. La huella SHA-1 de depuración está registrada y `android/app/google-services.json` contiene los clientes OAuth. Para una publicación con otra firma, registrar las huellas de esa firma y de Play App Signing y volver a descargar ese archivo.

La configuración actual cubre Android y web. iOS requiere registrar su propia app, configurar Google y comprobar su compilación antes de publicarla.

El acceso web local permite `localhost` y `127.0.0.1`. Para alojar la web en otro dominio, añadirlo a Authentication → Configuración → Dominios autorizados.

## Comprobaciones

Desde `app/`:

```powershell
..\.tools\flutter\bin\flutter.bat analyze --no-pub
..\.tools\flutter\bin\flutter.bat test
..\.tools\flutter\bin\flutter.bat build apk --debug
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$env:_JAVA_OPTIONS = '-Xmx256m -Xms32m'
firebase emulators:exec --project demo-cumplemes --only auth,firestore,database,storage 'node tool/firebase_tests/rules.test.cjs'
```

Las pruebas de reglas usan REST y Node sin dependencias npm y un proyecto de demostración, nunca usuarios reales. Verifican privacidad, revisiones obsoletas, invitaciones, adjuntos, presencia e intentos de suplantación.

Despliegue de reglas:

```powershell
firebase deploy --only firestore:rules,storage,database --project cumplemes
```

## Límites actuales

Al registrarse con Google por primera vez se pide un nombre de usuario (2–24 caracteres). Se almacena en `players/{uid}` junto al correo y se usa también en miembros, presencia y récords. Puede editarse desde Inicio; no es un identificador único ni reemplaza el UID de Firebase.

Los cuatro juegos sincronizan sus récords. Bloques conserva su tablero en `rincon.v1`; Wordlady guarda ronda y victorias en `wordle.v1`; Candy conserva tablero y récord en `sweet.v1`/`sweet.best`; Ascenso guarda récord y resumen de la última subida en `leap.best`/`leap.last`. El resumen de Ascenso no restaura una simulación a mitad de salto.

Storage consulta membresía en Firestore. Se habilitó `roles/firebaserules.firestoreServiceAgent` para `service-273979503185@gcp-sa-firebasestorage.iam.gserviceaccount.com`. `node tool/firebase_admin_check.cjs --diagnose-notes` permite revisar sin imprimir credenciales; `--storage-permissions` verifica y puede añadir el rol necesario (usa Firebase CLI). `--audit-leaderboard` solo lee; `--migrate-leaderboard` migra récords históricos sin disminuir marcas.

Las monedas, aperturas y puntuaciones se calculan en el cliente. Las reglas protegen la propiedad y evitan sobrescrituras obsoletas, pero no prueban que una partida o una recompensa sea legítima. Antes de una competición pública o monetización se necesita validación de esas operaciones en servidor y App Check. La migración conserva los guardados de este dispositivo; no exporta datos históricos de Supabase de otros dispositivos.

Los archivos del mural se guardan también localmente para uso offline. En web muchos adjuntos pueden alcanzar la cuota de almacenamiento del navegador; el error de guardado es visible. Las versiones antiguas de imágenes se conservan actualmente en Storage.
