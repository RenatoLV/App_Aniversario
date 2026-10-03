'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {unpack, owns, transfer, variant} = require('./inventory.cjs');
initializeApp();
const db = getFirestore();
const progress = uid => db.doc(`players/${uid}/progress/current`);
const listing = (core, name) => ({name, variants: core.cardVariants,
  updatedAt: FieldValue.serverTimestamp()});

exports.cardTrades = onRequest({region: 'us-central1', cors: true,
  maxInstances: 3, memory: '256MiB', timeoutSeconds: 30}, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({error: 'Usa POST.'});
  try {
    const token = (req.get('Authorization') || '').match(/^Bearer (.+)$/)?.[1];
    if (!token) return res.status(401).json({error: 'Inicia sesión con Google.'});
    const {uid} = await getAuth().verifyIdToken(token);
    const input = req.body || {};
    if (input.action === 'publish') {
      const [saved, profile] = await Promise.all([progress(uid).get(), db.doc(`players/${uid}`).get()]);
      const {core} = unpack(saved.data());
      await db.doc(`card_collections/${uid}`).set(listing(core, profile.data()?.nickname || 'Jugador'));
      return res.json({ok: true});
    }
    if (input.action === 'view') {
      const target = input.target;
      if (typeof target !== 'string' || !/^[\w-]{1,128}$/.test(target)) throw Error('Usuario inválido.');
      const shared = await db.doc(`card_collections/${target}`).get();
      if (!shared.exists) throw Error('Este usuario aún no comparte su colección.');
      const {core} = unpack((await progress(target).get()).data());
      return res.json({name: shared.data().name, variants: core.cardVariants});
    }
    if (input.action === 'propose') {
      const {target, give, receive, id} = input;
      if (typeof target !== 'string' || !/^[\w-]{1,128}$/.test(target) || target === uid)
        throw Error('Elige otro jugador.');
      if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id)) throw Error('Solicitud inválida.');
      variant(give); variant(receive);
      if (give === receive) throw Error('Elige dos cartas distintas.');
      const request = db.doc(`card_trades/${id}`);
      await db.runTransaction(async tx => {
        const [old, fromDoc, toDoc, visible, profile, pending] = await Promise.all([
          tx.get(request), tx.get(progress(uid)), tx.get(progress(target)),
          tx.get(db.doc(`card_collections/${target}`)), tx.get(db.doc(`players/${uid}`)),
          tx.get(db.collection('card_trades').where('fromUid', '==', uid).where('status', '==', 'pending').limit(10))]);
        if (old.exists) {
          if (old.data().fromUid === uid && old.data().toUid === target && old.data().give === give && old.data().receive === receive) return;
          throw Error('La solicitud ya existe.');
        }
        if (pending.size >= 10) throw Error('Puedes tener hasta 10 propuestas pendientes.');
        if (!visible.exists) throw Error('Este usuario no comparte su colección.');
        if (!owns(unpack(fromDoc.data()).core, give) || !owns(unpack(toDoc.data()).core, receive))
          throw Error('Una de las cartas ya no está disponible.');
        tx.create(request, {fromUid: uid, toUid: target, name: profile.data()?.nickname || 'Jugador',
          give, receive, status: 'pending', updatedAt: FieldValue.serverTimestamp()});
      });
      return res.json({ok: true, id});
    }
    if (input.action === 'respond') {
      if (!/^[a-f0-9]{32}$/.test(input.id || '') || !['accept', 'reject', 'cancel'].includes(input.choice))
        throw Error('Respuesta inválida.');
      const request = db.doc(`card_trades/${input.id}`);
      await db.runTransaction(async tx => {
        const snap = await tx.get(request);
        if (!snap.exists) throw Error('Solicitud no encontrada.');
        const trade = snap.data();
        const actor = input.choice === 'cancel' ? trade.fromUid : trade.toUid;
        if (actor !== uid) throw Error('Esta solicitud no te pertenece.');
        if (trade.status !== 'pending') {
          if (trade.status === ({accept:'accepted',reject:'rejected',cancel:'cancelled'})[input.choice]) return;
          throw Error('La solicitud ya fue resuelta.');
        }
        if (input.choice === 'accept') {
          const fromRef = progress(trade.fromUid), toRef = progress(trade.toUid);
          const [fromDoc, toDoc] = await Promise.all([tx.get(fromRef), tx.get(toRef)]);
          const [fromPayload, toPayload] = transfer(fromDoc.data(), toDoc.data(), trade.give, trade.receive, input.id);
          tx.update(fromRef, {payload: fromPayload, revision: fromDoc.data().revision + 1, updatedAt: FieldValue.serverTimestamp()});
          tx.update(toRef, {payload: toPayload, revision: toDoc.data().revision + 1, updatedAt: FieldValue.serverTimestamp()});
        }
        tx.update(request, {status: ({accept:'accepted',reject:'rejected',cancel:'cancelled'})[input.choice],
          updatedAt: FieldValue.serverTimestamp()});
      });
      return res.json({ok: true});
    }
    throw Error('Acción inválida.');
  } catch (error) {
    const authError = String(error.code || '').startsWith('auth/');
    res.status(authError ? 401 : 400).json({error: authError ? 'Vuelve a iniciar sesión.' : error.message});
  }
});
