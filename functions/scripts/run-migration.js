/**
 * Script to run Firestore migration
 *
 * This calls the migrateUserCollections Cloud Function
 *
 * Usage:
 *   node scripts/run-migration.js dry-run
 *   node scripts/run-migration.js migrate
 *   node scripts/run-migration.js migrate-and-delete
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'messageai-dev-1f2ec'
});

const mode = process.argv[2] || 'dry-run';

async function runMigration() {
  console.log('=========================================');
  console.log('FIRESTORE MIGRATION');
  console.log('=========================================\n');

  let dryRun = true;
  let deleteOld = false;

  switch (mode) {
    case 'dry-run':
      console.log('MODE: DRY RUN (no changes will be made)\n');
      dryRun = true;
      deleteOld = false;
      break;
    case 'migrate':
      console.log('MODE: MIGRATE (copy data, keep originals)\n');
      dryRun = false;
      deleteOld = false;
      break;
    case 'migrate-and-delete':
      console.log('MODE: MIGRATE AND DELETE (copy data, delete originals)\n');
      console.log('⚠️  WARNING: This will DELETE old collections after copying!\n');
      dryRun = false;
      deleteOld = true;
      break;
    default:
      console.error('Invalid mode. Use: dry-run, migrate, or migrate-and-delete');
      process.exit(1);
  }

  // Directly call the migration logic (since we're running in the functions directory)
  const db = admin.firestore();
  const stats = {
    notificationDecisions: 0,
    notificationFeedback: 0,
    rateLimits: 0,
    userActivity: 0,
    contextCache: 0,
    errors: [],
  };

  try {
    // ========================================
    // 1. MIGRATE NOTIFICATION_DECISIONS
    // ========================================
    console.log('[Migration] Analyzing notification_decisions...');
    const decisionsSnapshot = await db.collection('notification_decisions').get();
    console.log(`  Found ${decisionsSnapshot.size} documents\n`);

    for (const doc of decisionsSnapshot.docs) {
      const data = doc.data();
      const userId = data.userId;

      if (!userId) {
        stats.errors.push(`notification_decisions/${doc.id}: Missing userId`);
        continue;
      }

      if (!dryRun) {
        await db.collection('users')
          .doc(userId)
          .collection('notification_decisions')
          .doc(doc.id)
          .set(data);

        if (deleteOld) {
          await doc.ref.delete();
        }
      }
      stats.notificationDecisions++;
    }

    // ========================================
    // 2. MIGRATE NOTIFICATION_FEEDBACK
    // ========================================
    console.log('[Migration] Analyzing notification_feedback...');
    const feedbackSnapshot = await db.collection('notification_feedback').get();
    console.log(`  Found ${feedbackSnapshot.size} documents\n`);

    for (const doc of feedbackSnapshot.docs) {
      const data = doc.data();
      const userId = data.userId;

      if (!userId) {
        stats.errors.push(`notification_feedback/${doc.id}: Missing userId`);
        continue;
      }

      if (!dryRun) {
        await db.collection('users')
          .doc(userId)
          .collection('notification_feedback')
          .doc(doc.id)
          .set(data);

        if (deleteOld) {
          await doc.ref.delete();
        }
      }
      stats.notificationFeedback++;
    }

    // ========================================
    // 3. MIGRATE RATE_LIMITS
    // ========================================
    console.log('[Migration] Analyzing rate_limits...');
    const rateLimitsSnapshot = await db.collection('rate_limits').get();
    console.log(`  Found ${rateLimitsSnapshot.size} documents\n`);

    for (const doc of rateLimitsSnapshot.docs) {
      const userId = doc.id;
      const data = doc.data();

      if (!dryRun) {
        await db.collection('users')
          .doc(userId)
          .collection('rate_limits')
          .doc('default')
          .set(data);

        if (deleteOld) {
          await doc.ref.delete();
        }
      }
      stats.rateLimits++;
    }

    // ========================================
    // 4. MIGRATE USER_ACTIVITY
    // ========================================
    console.log('[Migration] Analyzing user_activity...');
    const activitySnapshot = await db.collection('user_activity').get();
    console.log(`  Found ${activitySnapshot.size} documents\n`);

    for (const doc of activitySnapshot.docs) {
      const userId = doc.id;
      const data = doc.data();

      if (!dryRun) {
        await db.collection('users')
          .doc(userId)
          .collection('activity')
          .doc('current')
          .set(data);

        if (deleteOld) {
          await doc.ref.delete();
        }
      }
      stats.userActivity++;
    }

    // ========================================
    // 5. MIGRATE USER_CONTEXT_CACHE
    // ========================================
    console.log('[Migration] Analyzing user_context_cache...');
    const cacheSnapshot = await db.collection('user_context_cache').get();
    console.log(`  Found ${cacheSnapshot.size} documents\n`);

    for (const doc of cacheSnapshot.docs) {
      const data = doc.data();
      const userId = data.userId;

      if (!userId) {
        stats.errors.push(`user_context_cache/${doc.id}: Missing userId`);
        continue;
      }

      if (!dryRun) {
        await db.collection('users')
          .doc(userId)
          .collection('context_cache')
          .doc(doc.id)
          .set(data);

        if (deleteOld) {
          await doc.ref.delete();
        }
      }
      stats.contextCache++;
    }

    // ========================================
    // SUMMARY
    // ========================================
    console.log('\n=========================================');
    console.log('MIGRATION SUMMARY');
    console.log('=========================================');
    console.log(`Mode: ${dryRun ? 'DRY RUN (no changes made)' : 'LIVE MIGRATION'}`);
    console.log(`Delete old: ${deleteOld ? 'YES' : 'NO'}\n`);
    console.log(`notification_decisions:  ${stats.notificationDecisions} documents`);
    console.log(`notification_feedback:   ${stats.notificationFeedback} documents`);
    console.log(`rate_limits:             ${stats.rateLimits} documents`);
    console.log(`user_activity:           ${stats.userActivity} documents`);
    console.log(`user_context_cache:      ${stats.contextCache} documents`);
    console.log(`\nTotal documents:         ${stats.notificationDecisions + stats.notificationFeedback + stats.rateLimits + stats.userActivity + stats.contextCache}`);

    if (stats.errors.length > 0) {
      console.log(`\n⚠️  Errors: ${stats.errors.length}`);
      stats.errors.forEach(err => console.log(`  - ${err}`));
    } else {
      console.log('\n✅ No errors detected');
    }

    if (dryRun) {
      console.log('\n📋 This was a DRY RUN - no changes were made to Firestore.');
      console.log('   To perform the actual migration, run:');
      console.log('   node scripts/run-migration.js migrate');
    } else {
      console.log('\n✅ Migration completed successfully!');
      if (!deleteOld) {
        console.log('   Old collections are still in place.');
        console.log('   After verifying, run with "migrate-and-delete" to clean up.');
      }
    }

    console.log('\n=========================================\n');

    process.exit(0);

  } catch (error) {
    console.error('\n❌ MIGRATION FAILED:', error);
    process.exit(1);
  }
}

runMigration();
