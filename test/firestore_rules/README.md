# Tests de firestore.rules (Emulator Suite)

Valida `firestore.rules` contra el Firestore Emulator local. Nunca toca un
proyecto real: usa el projectId `demo-conectamarket`, que el CLI reconoce como
demo y aisla por completo de la nube.

## Requisitos
- Node + `firebase-tools` (`npm i -g firebase-tools`)
- Un JDK en el PATH. En Windows alcanza el que trae Android Studio:
  `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"`

## Correr
```sh
cd test/firestore_rules
npm install
npm test
```

`npm test` levanta el emulador, corre mocha y lo apaga. El puerto es 8085
(8080 suele estar ocupado en la maquina de desarrollo).

## Que cubre
31 aserciones sobre el subarbol `/bodegas/**`: acceso del dueno a sus
productos/ventas/compras (get, list, write), denegacion cruzada contra la
bodega de otro uid, `forecasts` de solo lectura para el dueno, y denegacion
total para usuarios sin autenticar.
