import fs from 'node:fs';
import assert from 'node:assert';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, collection, getDocs } from 'firebase/firestore';

const UID_PROPIO = 'uid-bodega-A';
const UID_AJENO  = 'uid-bodega-B';
const COLECCIONES = ['productos', 'ventas', 'compras'];

let testEnv, propio, anonimo;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-conectamarket',
    firestore: {
      rules: fs.readFileSync('../../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
  });
  propio  = testEnv.authenticatedContext(UID_PROPIO).firestore();
  anonimo = testEnv.unauthenticatedContext().firestore();
});

after(() => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Siembra con reglas desactivadas: simula lo que ya escribio la Cloud
  // Function (forecasts) y datos preexistentes de ambas bodegas.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of [UID_PROPIO, UID_AJENO]) {
      for (const col of [...COLECCIONES, 'forecasts']) {
        await setDoc(doc(db, `bodegas/${uid}/${col}/doc1`), { seed: true });
      }
    }
  });
});

describe('1. El dueno sobre su propia bodega', () => {
  for (const col of COLECCIONES) {
    it(`puede LEER bodegas/{suUid}/${col}/doc1`, async () => {
      await assertSucceeds(getDoc(doc(propio, `bodegas/${UID_PROPIO}/${col}/doc1`)));
    });
    it(`puede LISTAR bodegas/{suUid}/${col}`, async () => {
      await assertSucceeds(getDocs(collection(propio, `bodegas/${UID_PROPIO}/${col}`)));
    });
    it(`puede ESCRIBIR en bodegas/{suUid}/${col}`, async () => {
      await assertSucceeds(setDoc(doc(propio, `bodegas/${UID_PROPIO}/${col}/nuevo`), { n: 1 }));
    });
  }
});

describe('2. El mismo usuario sobre la bodega de otro', () => {
  for (const col of COLECCIONES) {
    it(`NO puede LEER bodegas/{otroUid}/${col}/doc1`, async () => {
      await assertFails(getDoc(doc(propio, `bodegas/${UID_AJENO}/${col}/doc1`)));
    });
    it(`NO puede LISTAR bodegas/{otroUid}/${col}`, async () => {
      await assertFails(getDocs(collection(propio, `bodegas/${UID_AJENO}/${col}`)));
    });
    it(`NO puede ESCRIBIR en bodegas/{otroUid}/${col}`, async () => {
      await assertFails(setDoc(doc(propio, `bodegas/${UID_AJENO}/${col}/nuevo`), { n: 1 }));
    });
  }
  it('NO puede leer forecasts de otra bodega', async () => {
    await assertFails(getDoc(doc(propio, `bodegas/${UID_AJENO}/forecasts/doc1`)));
  });
});

describe('3. forecasts: nadie escribe, ni el dueno (allow write: if false)', () => {
  it('el dueno NO puede CREAR un forecast', async () => {
    await assertFails(setDoc(doc(propio, `bodegas/${UID_PROPIO}/forecasts/nuevo`), { v: 1 }));
  });
  it('el dueno NO puede SOBREESCRIBIR un forecast existente', async () => {
    await assertFails(setDoc(doc(propio, `bodegas/${UID_PROPIO}/forecasts/doc1`), { v: 2 }));
  });
});

describe('4. forecasts: el dueno SI puede leer los propios', () => {
  it('puede LEER bodegas/{suUid}/forecasts/doc1', async () => {
    const snap = await assertSucceeds(getDoc(doc(propio, `bodegas/${UID_PROPIO}/forecasts/doc1`)));
    assert.strictEqual(snap.data().seed, true);
  });
  it('puede LISTAR bodegas/{suUid}/forecasts', async () => {
    await assertSucceeds(getDocs(collection(propio, `bodegas/${UID_PROPIO}/forecasts`)));
  });
});

describe('5. Usuario NO autenticado bajo /bodegas/**', () => {
  for (const col of [...COLECCIONES, 'forecasts']) {
    it(`NO puede LEER bodegas/{uid}/${col}/doc1`, async () => {
      await assertFails(getDoc(doc(anonimo, `bodegas/${UID_PROPIO}/${col}/doc1`)));
    });
    it(`NO puede ESCRIBIR en bodegas/{uid}/${col}`, async () => {
      await assertFails(setDoc(doc(anonimo, `bodegas/${UID_PROPIO}/${col}/nuevo`), { n: 1 }));
    });
  }
});
