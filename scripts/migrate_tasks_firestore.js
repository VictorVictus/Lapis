/// Run: node scripts/migrate_tasks_firestore.js
/// Requires: npm install firebase-admin
/// Steps:
///   1. Go to Firebase Console > Project Settings > Service Accounts
///   2. "Generate new private key", save as serviceAccountKey.json in project root
///   3. Run this script

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
  const snapshot = await db.collection('tasks').get();
  let batch = db.batch();
  let ops = 0;
  let count = 0;

  snapshot.forEach((doc) => {
    const data = doc.data();
    const updates = {};

    if (data['isArchived'] === undefined) updates['isArchived'] = false;
    if (data['pinned'] === undefined) updates['pinned'] = false;

    if (Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
      ops++;
      count++;
    }

    if (ops >= 500) {
      batch.commit();
      batch = db.batch();
      ops = 0;
    }
  });

  if (ops > 0) await batch.commit();
  console.log(`Migrated ${count} documents`);
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
