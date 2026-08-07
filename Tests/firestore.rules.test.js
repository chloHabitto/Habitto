const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const fs = require('fs');
const path = require('path');

let testEnv;

// Test data helpers
const createHabitData = () => ({
  name: 'Morning Run',
  color: 'green500',
  type: 'formation',
  createdAt: new Date(),
  active: true,
});

const createGoalVersionData = (habitId) => ({
  habitId: habitId,
  effectiveLocalDate: '2025-10-15',
  goal: 2,
  createdAt: new Date(),
});

const createCompletionData = () => ({
  count: 1,
  updatedAt: new Date(),
});

const createXPStateData = () => ({
  totalXP: 100,
  level: 2,
  currentLevelXP: 10,
  lastUpdated: new Date(),
});

const createXPLedgerData = () => ({
  delta: 50,
  reason: 'Completed daily habit',
  timestamp: new Date(),
});

const createStreakData = () => ({
  current: 5,
  longest: 10,
  lastCompletionDate: '2025-10-14',
  updatedAt: new Date(),
});

/** Path helper matching FirestoreRepository: goalVersions/{habitId}/versions/{versionId} */
const goalVersionRef = (db, userId, habitId, versionId) =>
  db
    .collection('users')
    .doc(userId)
    .collection('goalVersions')
    .doc(habitId)
    .collection('versions')
    .doc(versionId);

/** Path helper matching FirestoreRepository: completions/{date}/habits/{habitId} */
const completionRefFor = (db, userId, dateStr, habitId) =>
  db
    .collection('users')
    .doc(userId)
    .collection('completions')
    .doc(dateStr)
    .collection('habits')
    .doc(habitId);

/** Path helper: /users/{uid}/xp/ledger/entries/{eventId} */
const xpLedgerRef = (db, userId, eventId) =>
  db
    .collection('users')
    .doc(userId)
    .collection('xp')
    .doc('ledger')
    .collection('entries')
    .doc(eventId);

// Setup and teardown
beforeAll(async () => {
  // Read the rules file
  const rulesPath = path.join(__dirname, '../firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: 'habitto-test',
    firestore: {
      rules,
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ============================================================================
// AUTHENTICATION TESTS
// ============================================================================

describe('Authentication Requirements', () => {
  test('Unauthenticated users cannot read any data', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthedDb.collection('users').doc('user1').get());
  });

  test('Unauthenticated users cannot write any data', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthedDb.collection('users').doc('user1').set({ test: 'data' })
    );
  });

  test('Authenticated users can read their own data', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    // This will fail because document doesn't exist, but not due to security rules
    await assertSucceeds(
      authedDb.collection('users').doc('user1').collection('habits').get()
    );
  });

  test('Authenticated users cannot read other users data', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertFails(
      authedDb.collection('users').doc('user2').collection('habits').get()
    );
  });
});

// ============================================================================
// HABITS COLLECTION TESTS
// ============================================================================

describe('Habits Collection Rules', () => {
  test('User can create valid habit', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    await assertSucceeds(habitRef.set(createHabitData()));
  });

  test('User cannot create habit without required fields', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    await assertFails(habitRef.set({ name: 'Incomplete' }));
  });

  test('User cannot create habit with invalid type', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    const invalidData = createHabitData();
    invalidData.type = 'invalid_type';

    await assertFails(habitRef.set(invalidData));
  });

  test('User cannot create habit with empty name', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    const invalidData = createHabitData();
    invalidData.name = '';

    await assertFails(habitRef.set(invalidData));
  });

  test('User cannot create habit with name > 100 chars', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    const invalidData = createHabitData();
    invalidData.name = 'a'.repeat(101);

    await assertFails(habitRef.set(invalidData));
  });

  test('User can update allowed habit fields', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    // Create habit first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData());
    });

    // Update allowed fields
    await assertSucceeds(
      habitRef.update({
        name: 'Updated Name',
        color: 'blue500',
        active: false,
      })
    );
  });

  test('User cannot update createdAt field', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    // Create habit first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData());
    });

    // Try to update createdAt
    await assertFails(habitRef.update({ createdAt: new Date() }));
  });

  test('User can delete their own habit', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    // Create habit first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData());
    });

    await assertSucceeds(habitRef.delete());
  });

  test('User cannot delete another users habit', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('habit1');

    await assertFails(habitRef.delete());
  });
});

// ============================================================================
// GOAL VERSIONS TESTS
// ============================================================================

describe('Goal Versions Rules', () => {
  test('User can create valid goal version', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    await assertSucceeds(goalRef.set(createGoalVersionData('habit1')));
  });

  test('User cannot create goal with invalid date format', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    const invalidData = createGoalVersionData('habit1');
    invalidData.effectiveLocalDate = '2025/10/15'; // Wrong format

    await assertFails(goalRef.set(invalidData));
  });

  test('User cannot create goal with negative goal value', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    const invalidData = createGoalVersionData('habit1');
    invalidData.goal = -1;

    await assertFails(goalRef.set(invalidData));
  });

  test('User can create goal with zero value', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    const validData = createGoalVersionData('habit1');
    validData.goal = 0;

    await assertSucceeds(goalRef.set(validData));
  });

  test('User cannot update goal version (immutable)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    // Create goal first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await goalVersionRef(context.firestore(), 'user1', 'habit1', 'version1').set(
        createGoalVersionData('habit1')
      );
    });

    // Try to update
    await assertFails(goalRef.update({ goal: 5 }));
  });

  test('User can delete goal version', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'version1');

    // Create goal first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await goalVersionRef(context.firestore(), 'user1', 'habit1', 'version1').set(
        createGoalVersionData('habit1')
      );
    });

    await assertSucceeds(goalRef.delete());
  });
});

// ============================================================================
// COMPLETIONS TESTS
// ============================================================================

describe('Completions Rules', () => {
  test('User can create valid completion', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = completionRefFor(authedDb, 'user1', '2025-10-15', 'habit1');

    await assertSucceeds(completionRef.set(createCompletionData()));
  });

  test('User cannot create completion with invalid date format', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = completionRefFor(authedDb, 'user1', '10-15-2025', 'habit1');

    await assertFails(completionRef.set(createCompletionData()));
  });

  test('User cannot create completion with negative count', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = completionRefFor(authedDb, 'user1', '2025-10-15', 'habit1');

    const invalidData = createCompletionData();
    invalidData.count = -1;

    await assertFails(completionRef.set(invalidData));
  });

  test('User can update completion count', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = completionRefFor(authedDb, 'user1', '2025-10-15', 'habit1');

    // Create completion first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await completionRefFor(context.firestore(), 'user1', '2025-10-15', 'habit1').set(
        createCompletionData()
      );
    });

    await assertSucceeds(
      completionRef.update({
        count: 2,
        updatedAt: new Date(),
      })
    );
  });

  test('User cannot update completion with negative count', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = completionRefFor(authedDb, 'user1', '2025-10-15', 'habit1');

    // Create completion first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await completionRefFor(context.firestore(), 'user1', '2025-10-15', 'habit1').set(
        createCompletionData()
      );
    });

    await assertFails(
      completionRef.update({
        count: -5,
        updatedAt: new Date(),
      })
    );
  });
});

// ============================================================================
// XP STATE TESTS
// ============================================================================

describe('XP State Rules', () => {
  test('User can create valid XP state', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const xpRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('state');

    await assertSucceeds(xpRef.set(createXPStateData()));
  });

  test('User cannot create XP state with negative totalXP', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const xpRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('state');

    const invalidData = createXPStateData();
    invalidData.totalXP = -10;

    await assertFails(xpRef.set(invalidData));
  });

  test('User cannot create XP state with level < 1', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const xpRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('state');

    const invalidData = createXPStateData();
    invalidData.level = 0;

    await assertFails(xpRef.set(invalidData));
  });

  test('User can update XP state', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const xpRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('state');

    // Create state first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('xp')
        .doc('state')
        .set(createXPStateData());
    });

    await assertSucceeds(
      xpRef.update({
        totalXP: 150,
        level: 3,
        currentLevelXP: 25,
        lastUpdated: new Date(),
      })
    );
  });
});

// ============================================================================
// XP LEDGER TESTS
// ============================================================================

describe('XP Ledger Rules', () => {
  test('User can create valid ledger entry', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    await assertSucceeds(ledgerRef.set(createXPLedgerData()));
  });

  test('User cannot create ledger entry with negative delta', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    const invalidData = createXPLedgerData();
    invalidData.delta = -25;

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot create ledger entry with zero delta', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event-zero');

    const invalidData = createXPLedgerData();
    invalidData.delta = 0;

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot create ledger entry with empty reason', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    const invalidData = createXPLedgerData();
    invalidData.reason = '';

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot create ledger entry with reason > 500 chars', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    const invalidData = createXPLedgerData();
    invalidData.reason = 'a'.repeat(501);

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot update ledger entry (immutable)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    // Create ledger entry first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await xpLedgerRef(context.firestore(), 'user1', 'event1').set(createXPLedgerData());
    });

    // Try to update
    await assertFails(ledgerRef.update({ delta: 100 }));
  });

  test('User cannot delete ledger entry', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'event1');

    // Create ledger entry first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await xpLedgerRef(context.firestore(), 'user1', 'event1').set(createXPLedgerData());
    });

    await assertFails(ledgerRef.delete());
  });
});

// ============================================================================
// STREAKS TESTS
// ============================================================================

describe('Streaks Rules', () => {
  test('User can create valid streak', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const streakRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('streaks')
      .doc('habit1');

    await assertSucceeds(streakRef.set(createStreakData()));
  });

  test('User can create streak without lastCompletionDate', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const streakRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('streaks')
      .doc('habit1');

    const validData = {
      current: 0,
      longest: 0,
      updatedAt: new Date(),
    };

    await assertSucceeds(streakRef.set(validData));
  });

  test('User cannot create streak with negative current', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const streakRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('streaks')
      .doc('habit1');

    const invalidData = createStreakData();
    invalidData.current = -1;

    await assertFails(streakRef.set(invalidData));
  });

  test('User cannot create streak with invalid date format', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const streakRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('streaks')
      .doc('habit1');

    const invalidData = createStreakData();
    invalidData.lastCompletionDate = '10/15/2025'; // Invalid format

    await assertFails(streakRef.set(invalidData));
  });

  test('User can update streak', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const streakRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('streaks')
      .doc('habit1');

    // Create streak first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('streaks')
        .doc('habit1')
        .set(createStreakData());
    });

    await assertSucceeds(
      streakRef.update({
        current: 6,
        longest: 10,
        lastCompletionDate: '2025-10-15',
        updatedAt: new Date(),
      })
    );
  });
});

// ============================================================================
// CROSS-USER ACCESS TESTS
// ============================================================================

describe('Cross-User Access Prevention', () => {
  test('User cannot read another users habits', async () => {
    const user1Db = testEnv.authenticatedContext('user1').firestore();

    // Create habit for user2
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user2')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData());
    });

    // User1 tries to read user2's habit
    await assertFails(
      user1Db
        .collection('users')
        .doc('user2')
        .collection('habits')
        .doc('habit1')
        .get()
    );
  });

  test('User cannot write to another users collections', async () => {
    const user1Db = testEnv.authenticatedContext('user1').firestore();

    await assertFails(
      user1Db
        .collection('users')
        .doc('user2')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData())
    );
  });

  test('User cannot delete another users data', async () => {
    const user1Db = testEnv.authenticatedContext('user1').firestore();

    // Create habit for user2
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user2')
        .collection('habits')
        .doc('habit1')
        .set(createHabitData());
    });

    // User1 tries to delete user2's habit
    await assertFails(
      user1Db
        .collection('users')
        .doc('user2')
        .collection('habits')
        .doc('habit1')
        .delete()
    );
  });
});

// ============================================================================
// WILDCARD PATH DENIAL TESTS
// ============================================================================

describe('Deny Unknown Paths', () => {
  test('User cannot access root collections', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertFails(authedDb.collection('unknown').doc('doc1').get());
  });

  test('User cannot write to root collections', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertFails(
      authedDb.collection('unknown').doc('doc1').set({ data: 'test' })
    );
  });
});

// ============================================================================
// SECURITY GAP REGRESSION
// These cases were previously allowed by the blanket
// match /users/{uid}/{document=**} { allow read, write: ... } rule.
// ============================================================================

describe('Security gap regression (blanket wildcard)', () => {
  test('Owner cannot update an existing goalVersions document', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'v-gap');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await goalVersionRef(context.firestore(), 'user1', 'habit1', 'v-gap').set(
        createGoalVersionData('habit1')
      );
    });

    await assertFails(goalRef.update({ goal: 99, effectiveLocalDate: '2025-12-01' }));
  });

  test('Owner cannot update an xp/ledger entry', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'gap-event');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await xpLedgerRef(context.firestore(), 'user1', 'gap-event').set(
        createXPLedgerData()
      );
    });

    await assertFails(ledgerRef.update({ reason: 'tampered' }));
  });

  test('Owner cannot delete an xp/ledger entry', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = xpLedgerRef(authedDb, 'user1', 'gap-event-del');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await xpLedgerRef(context.firestore(), 'user1', 'gap-event-del').set(
        createXPLedgerData()
      );
    });

    await assertFails(ledgerRef.delete());
  });

  test('Owner cannot create habit with invalid type', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('gap-habit-type');

    const invalidData = createHabitData();
    invalidData.type = 'neither';

    await assertFails(habitRef.set(invalidData));
  });

  test('Owner cannot create habit with out-of-range goal via goalVersions', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = goalVersionRef(authedDb, 'user1', 'habit1', 'v-neg');

    const invalidData = createGoalVersionData('habit1');
    invalidData.goal = -100;

    await assertFails(goalRef.set(invalidData));
  });

  test('Owner can append to xp_ledger collection used by FirestoreRepository', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp_ledger')
      .doc('repo-event');

    await assertSucceeds(
      ledgerRef.set({
        delta: 10,
        reason: 'Award',
        ts: new Date(),
      })
    );
  });

  test('Owner cannot update xp_ledger entry (append-only)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp_ledger')
      .doc('repo-event-upd');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('xp_ledger')
        .doc('repo-event-upd')
        .set({ delta: 10, reason: 'Award', ts: new Date() });
    });

    await assertFails(ledgerRef.update({ delta: 999 }));
  });
});

// ============================================================================
// DAILY AWARDS
// ============================================================================

const createDailyAwardSyncData = (userId, dateKey) => ({
  userId,
  dateKey,
  xpGranted: 50,
  allHabitsCompleted: true,
  createdAt: new Date(),
  userIdDateKey: `${userId}#${dateKey}`,
});

const createDailyAwardBackupData = (dateKey) => ({
  dateKey,
  xpGranted: 50,
  allHabitsCompleted: true,
  grantedAt: new Date(),
  syncedAt: new Date(),
});

const dailyAwardRef = (db, userId, docId) =>
  db.collection('users').doc(userId).collection('daily_awards').doc(docId);

describe('Daily Awards Rules', () => {
  test('User can create valid SyncEngine daily award', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', 'user1#2025-10-15');

    await assertSucceeds(ref.set(createDailyAwardSyncData('user1', '2025-10-15')));
  });

  test('User can create valid backup-schema daily award', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-10-15');

    await assertSucceeds(ref.set(createDailyAwardBackupData('2025-10-15')));
  });

  test('User cannot create daily award with non-positive xpGranted', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-10-16');

    const invalid = createDailyAwardBackupData('2025-10-16');
    invalid.xpGranted = 0;

    await assertFails(ref.set(invalid));
  });

  test('User cannot create daily award with invalid dateKey', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', 'bad-date');

    const invalid = createDailyAwardBackupData('10/15/2025');
    await assertFails(ref.set(invalid));
  });

  test('User cannot create daily award with non-bool allHabitsCompleted', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-10-17');

    const invalid = createDailyAwardBackupData('2025-10-17');
    invalid.allHabitsCompleted = 'yes';

    await assertFails(ref.set(invalid));
  });

  test('User cannot update daily award xpGranted (core fields locked)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', 'user1#2025-10-18');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await dailyAwardRef(context.firestore(), 'user1', 'user1#2025-10-18').set(
        createDailyAwardSyncData('user1', '2025-10-18')
      );
    });

    await assertFails(ref.update({ xpGranted: 999 }));
  });

  test('User can refresh daily award timestamps without changing award', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-10-21');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await dailyAwardRef(context.firestore(), 'user1', '2025-10-21').set(
        createDailyAwardBackupData('2025-10-21')
      );
    });

    // FirebaseBackupService setData(merge:true) rewrites timestamps only in practice
    await assertSucceeds(
      ref.set(
        {
          dateKey: '2025-10-21',
          xpGranted: 50,
          allHabitsCompleted: true,
          grantedAt: new Date(),
          syncedAt: new Date(),
        },
        { merge: true }
      )
    );
  });

  test('User can delete their own daily award', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', 'user1#2025-10-19');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await dailyAwardRef(context.firestore(), 'user1', 'user1#2025-10-19').set(
        createDailyAwardSyncData('user1', '2025-10-19')
      );
    });

    await assertSucceeds(ref.delete());
  });

  test('User cannot write another users daily award', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', 'user1#2025-10-20');

    await assertFails(ref.set(createDailyAwardSyncData('user1', '2025-10-20')));
  });
});

// ============================================================================
// DEVICES
// ============================================================================

const createDeviceData = (deviceId) => ({
  id: deviceId,
  deviceName: 'iPhone 15',
  deviceModel: 'iPhone 15',
  lastLogin: new Date(),
  createdAt: new Date(),
  appVersion: '1.2.3',
});

const deviceRef = (db, userId, deviceId) =>
  db.collection('users').doc(userId).collection('devices').doc(deviceId);

describe('Devices Rules', () => {
  test('User can create valid device', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertSucceeds(
      deviceRef(authedDb, 'user1', 'device-abc').set(createDeviceData('device-abc'))
    );
  });

  test('User cannot create device with mismatched id', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createDeviceData('other-id');
    await assertFails(deviceRef(authedDb, 'user1', 'device-abc').set(data));
  });

  test('User cannot create device with empty deviceName', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createDeviceData('device-abc');
    data.deviceName = '';
    await assertFails(deviceRef(authedDb, 'user1', 'device-abc').set(data));
  });

  test('User can update lastLogin and deviceName', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = deviceRef(authedDb, 'user1', 'device-upd');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deviceRef(context.firestore(), 'user1', 'device-upd').set(
        createDeviceData('device-upd')
      );
    });

    await assertSucceeds(
      ref.update({
        lastLogin: new Date(),
        deviceName: 'Chloe Phone',
        appVersion: '1.2.4',
      })
    );
  });

  test('User cannot change createdAt on device', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = deviceRef(authedDb, 'user1', 'device-immutable');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deviceRef(context.firestore(), 'user1', 'device-immutable').set(
        createDeviceData('device-immutable')
      );
    });

    await assertFails(ref.update({ createdAt: new Date() }));
  });

  test('User can delete their device', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = deviceRef(authedDb, 'user1', 'device-del');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deviceRef(context.firestore(), 'user1', 'device-del').set(
        createDeviceData('device-del')
      );
    });

    await assertSucceeds(ref.delete());
  });

  test('User cannot write another users device', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    await assertFails(
      deviceRef(authedDb, 'user1', 'device-x').set(createDeviceData('device-x'))
    );
  });
});

// ============================================================================
// META / MIGRATION
// ============================================================================

const createMigrationData = () => ({
  status: 'running',
  itemsProcessed: 0,
  version: '1.0.0',
  metadata: { started_by: 'system' },
  startedAt: new Date(),
});

const migrationRef = (db, userId) =>
  db.collection('users').doc(userId).collection('meta').doc('migration');

describe('Meta Migration Rules', () => {
  test('User can create valid migration state', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertSucceeds(migrationRef(authedDb, 'user1').set(createMigrationData()));
  });

  test('User can write BackfillJob partial migration status', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertSucceeds(
      migrationRef(authedDb, 'user1').set(
        { status: 'complete', finishedAt: new Date() },
        { merge: true }
      )
    );
  });

  test('User cannot write migration with invalid status', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertFails(
      migrationRef(authedDb, 'user1').set({ status: 'bogus', itemsProcessed: 0 })
    );
  });

  test('User cannot write migration with negative itemsProcessed', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createMigrationData();
    data.itemsProcessed = -1;
    await assertFails(migrationRef(authedDb, 'user1').set(data));
  });

  test('User can update migration progress', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = migrationRef(authedDb, 'user1');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await migrationRef(context.firestore(), 'user1').set(createMigrationData());
    });

    await assertSucceeds(
      ref.update({
        itemsProcessed: 10,
        lastItemKey: 'habit-1',
        status: 'running',
      })
    );
  });

  test('User can delete migration state', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = migrationRef(authedDb, 'user1');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await migrationRef(context.firestore(), 'user1').set(createMigrationData());
    });

    await assertSucceeds(ref.delete());
  });

  test('User cannot write another users migration state', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    await assertFails(migrationRef(authedDb, 'user1').set(createMigrationData()));
  });
});

// ============================================================================
// SYNCENGINE COMPLETION BUCKETS
// ============================================================================

const createSyncCompletionData = (userId, habitId, dateKey) => ({
  userId,
  habitId,
  dateKey,
  isCompleted: true,
  progress: 1,
  createdAt: new Date(),
  updatedAt: new Date(),
  completionId: `comp_${habitId}_${dateKey}`,
});

const syncCompletionRef = (db, userId, yearMonth, recordId, subcollection = 'completions') =>
  db
    .collection('users')
    .doc(userId)
    .collection('completions')
    .doc(yearMonth)
    .collection(subcollection)
    .doc(recordId);

describe('SyncEngine Completion Bucket Rules', () => {
  test('User can create valid completion in completions bucket', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(
      authedDb,
      'user1',
      '2025-10',
      'comp_habit1_2025-10-15'
    );

    await assertSucceeds(
      ref.set(createSyncCompletionData('user1', 'habit1', '2025-10-15'))
    );
  });

  test('User can create valid completion in legacy records bucket', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(
      authedDb,
      'user1',
      '2025-10',
      'comp_habit1_2025-10-15',
      'records'
    );

    await assertSucceeds(
      ref.set(createSyncCompletionData('user1', 'habit1', '2025-10-15'))
    );
  });

  test('User cannot create sync completion with negative progress', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'bad-progress');
    const data = createSyncCompletionData('user1', 'habit1', '2025-10-15');
    data.progress = -1;

    await assertFails(ref.set(data));
  });

  test('User cannot create sync completion with invalid dateKey', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'bad-date');
    const data = createSyncCompletionData('user1', 'habit1', '10-15-2025');

    await assertFails(ref.set(data));
  });

  test('User cannot create sync completion with invalid yearMonth path', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    // Must stay a single path segment (no '/'); use a non YYYY-MM value
    const ref = syncCompletionRef(authedDb, 'user1', '202510', 'bad-ym');

    await assertFails(
      ref.set(createSyncCompletionData('user1', 'habit1', '2025-10-15'))
    );
  });

  test('User cannot create sync completion missing required fields', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'incomplete');

    await assertFails(
      ref.set({
        habitId: 'habit1',
        progress: 1,
      })
    );
  });

  test('User can update sync completion progress', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'comp-upd');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await syncCompletionRef(context.firestore(), 'user1', '2025-10', 'comp-upd').set(
        createSyncCompletionData('user1', 'habit1', '2025-10-15')
      );
    });

    await assertSucceeds(
      ref.update({
        progress: 3,
        isCompleted: true,
        updatedAt: new Date(),
      })
    );
  });

  test('User can delete sync completion', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'comp-del');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await syncCompletionRef(context.firestore(), 'user1', '2025-10', 'comp-del').set(
        createSyncCompletionData('user1', 'habit1', '2025-10-15')
      );
    });

    await assertSucceeds(ref.delete());
  });

  test('User cannot write another users sync completion', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    const ref = syncCompletionRef(authedDb, 'user1', '2025-10', 'comp-x');

    await assertFails(
      ref.set(createSyncCompletionData('user1', 'habit1', '2025-10-15'))
    );
  });
});

// ============================================================================
// PROGRESS EVENTS — SyncEngine event path
// Path: /users/{uid}/events/{yearMonth}/events/{eventId}
// Mirrors ProgressEvent.toFirestore() + SyncEngine.syncBatch
// ============================================================================

/** Exact field set from ProgressEvent.toFirestore() */
const createProgressEventData = (userId, overrides = {}) => {
  const now = overrides.createdAt || new Date('2026-08-07T10:00:00.000Z');
  const dateKey = overrides.dateKey || '2026-08-07';
  const habitId = overrides.habitId || '9996D0CC-630C-4626-91E1-97EFF445E7BF';
  const deviceId = overrides.deviceId || 'iOS_iPhone_1FCCE3B4-4B25-4861-A708-D7F4A9D9B688';
  const id =
    overrides.id ||
    `evt_${habitId}_${dateKey}_${deviceId}_1`;
  return {
    id,
    habitId,
    dateKey,
    eventType: 'INCREMENT',
    progressDelta: 1,
    createdAt: now,
    occurredAt: now,
    utcDayStart: new Date('2026-08-07T00:00:00.000Z'),
    utcDayEnd: new Date('2026-08-07T23:59:59.999Z'),
    deviceId,
    userId,
    timezoneIdentifier: 'Asia/Seoul',
    operationId: `${deviceId}_${now.getTime()}_op`,
    syncVersion: 1,
    isRemote: false,
    ...overrides,
  };
};

const progressEventRef = (db, userId, yearMonth, eventId) =>
  db
    .collection('users')
    .doc(userId)
    .collection('events')
    .doc(yearMonth)
    .collection('events')
    .doc(eventId);

describe('SyncEngine Progress Event Rules', () => {
  test('Owner can create valid progress event', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user1');
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await assertSucceeds(ref.set(data));
  });

  test('Owner can create progress event with negative progressDelta (DECREMENT)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user1', {
      eventType: 'DECREMENT',
      progressDelta: -1,
      id: 'evt_dec_1',
    });
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await assertSucceeds(ref.set(data));
  });

  test('Non-owner cannot create progress event', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    const data = createProgressEventData('user1');
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await assertFails(ref.set(data));
  });

  test('Owner cannot create progress event with mismatched userId field', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user2'); // field claims other user
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await assertFails(ref.set(data));
  });

  test('Owner cannot create progress event with invalid yearMonth path', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user1');
    const ref = progressEventRef(authedDb, 'user1', '202608', data.id);

    await assertFails(ref.set(data));
  });

  test('Owner cannot create progress event missing required fields', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = progressEventRef(authedDb, 'user1', '2026-08', 'evt_incomplete');

    await assertFails(
      ref.set({
        id: 'evt_incomplete',
        habitId: 'habit1',
        progressDelta: 1,
      })
    );
  });

  test('Owner can update progress event (merge)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user1', { id: 'evt_upd' });
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await progressEventRef(context.firestore(), 'user1', '2026-08', data.id).set(
        data
      );
    });

    await assertSucceeds(
      ref.set(
        createProgressEventData('user1', {
          id: 'evt_upd',
          isRemote: true,
          syncVersion: 2,
        }),
        { merge: true }
      )
    );
  });

  test('Owner can delete progress event', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const data = createProgressEventData('user1', { id: 'evt_del' });
    const ref = progressEventRef(authedDb, 'user1', '2026-08', data.id);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await progressEventRef(context.firestore(), 'user1', '2026-08', data.id).set(
        data
      );
    });

    await assertSucceeds(ref.delete());
  });
});

// ============================================================================
// FIREBASE BACKUP SERVICE — real write shapes
// Mirrors Core/Services/FirebaseBackupService.swift + FirestoreHabit.toFirestoreData()
// ============================================================================

/** Exact field set from FirestoreHabit.toFirestoreData() + syncedAt (performHabitBackup) */
const createFirebaseBackupHabitPayload = (overrides = {}) => {
  const createdAt = overrides.createdAt || new Date('2025-01-15T10:00:00.000Z');
  return {
    name: 'Morning Run',
    description: 'Go for a run',
    icon: 'figure.run',
    color: '#34C759',
    habitType: 'Habit Building', // HabitType.formation.rawValue — NOT "formation"
    schedule: 'daily',
    goal: '1',
    reminder: 'none',
    startDate: new Date('2025-01-15T00:00:00.000Z'),
    createdAt,
    reminders: [],
    remindersJSON: '[]',
    baseline: 0,
    target: 1,
    completionHistory: {},
    completionStatus: {},
    completionTimestamps: {},
    difficultyHistory: {},
    actualUsage: {},
    skippedDaysJSON: '{}',
    isActive: true,
    syncStatus: 'pending',
    syncedAt: new Date(),
    ...overrides,
  };
};

describe('FirebaseBackupService real write shapes', () => {
  test('Habit backup create succeeds with Habit Building rawValue', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('11111111-1111-1111-1111-111111111111');

    await assertSucceeds(
      habitRef.set(createFirebaseBackupHabitPayload(), { merge: true })
    );
  });

  test('Habit backup create succeeds with Habit Breaking rawValue', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('22222222-2222-2222-2222-222222222222');

    await assertSucceeds(
      habitRef.set(
        createFirebaseBackupHabitPayload({
          name: 'No Soda',
          habitType: 'Habit Breaking',
        }),
        { merge: true }
      )
    );
  });

  test('Habit backup merge update succeeds (full payload + new syncedAt)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitId = '33333333-3333-3333-3333-333333333333';
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc(habitId);

    const createdAt = new Date('2025-01-15T10:00:00.000Z');
    const initial = createFirebaseBackupHabitPayload({ createdAt });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('habits')
        .doc(habitId)
        .set(initial);
    });

    // Second backup: same createdAt, refreshed syncedAt / mutable fields
    await assertSucceeds(
      habitRef.set(
        createFirebaseBackupHabitPayload({
          createdAt,
          name: 'Morning Run Updated',
          target: 2,
          syncedAt: new Date(),
          syncStatus: 'synced',
        }),
        { merge: true }
      )
    );
  });

  test('Habit backup create still rejects empty name', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('44444444-4444-4444-4444-444444444444');

    await assertFails(
      habitRef.set(createFirebaseBackupHabitPayload({ name: '' }), { merge: true })
    );
  });

  test('Habit backup create still rejects unknown habitType', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const habitRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('habits')
      .doc('55555555-5555-5555-5555-555555555555');

    await assertFails(
      habitRef.set(
        createFirebaseBackupHabitPayload({ habitType: 'neither' }),
        { merge: true }
      )
    );
  });

  test('Daily award backup create then merge refresh succeeds', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-11-01');

    const payload = {
      dateKey: '2025-11-01',
      xpGranted: 50,
      allHabitsCompleted: true,
      grantedAt: new Date(),
      syncedAt: new Date(),
    };

    await assertSucceeds(ref.set(payload, { merge: true }));
    await assertSucceeds(
      ref.set(
        {
          ...payload,
          grantedAt: new Date(),
          syncedAt: new Date(),
        },
        { merge: true }
      )
    );
  });

  test('Daily award backup merge cannot escalate xpGranted', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = dailyAwardRef(authedDb, 'user1', '2025-11-02');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await dailyAwardRef(context.firestore(), 'user1', '2025-11-02').set({
        dateKey: '2025-11-02',
        xpGranted: 50,
        allHabitsCompleted: true,
        grantedAt: new Date(),
        syncedAt: new Date(),
      });
    });

    await assertFails(
      ref.set(
        {
          dateKey: '2025-11-02',
          xpGranted: 500,
          allHabitsCompleted: true,
          grantedAt: new Date(),
          syncedAt: new Date(),
        },
        { merge: true }
      )
    );
  });
});

// ============================================================================
// META / XP MIGRATION
// ============================================================================

describe('Meta XP Migration Rules', () => {
  const xpMigrationRef = (db, userId) =>
    db.collection('users').doc(userId).collection('meta').doc('xp_migration');

  test('User can mark XP migration complete (FirestoreService shape)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertSucceeds(
      xpMigrationRef(authedDb, 'user1').set({
        status: 'complete',
        completedAt: new Date(),
        version: '1.0',
      })
    );
  });

  test('User cannot write xp_migration with invalid status', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    await assertFails(
      xpMigrationRef(authedDb, 'user1').set({
        status: 'pending',
        completedAt: new Date(),
        version: '1.0',
      })
    );
  });

  test('User can delete xp_migration marker', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ref = xpMigrationRef(authedDb, 'user1');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await xpMigrationRef(context.firestore(), 'user1').set({
        status: 'complete',
        completedAt: new Date(),
        version: '1.0',
      });
    });

    await assertSucceeds(ref.delete());
  });

  test('User cannot write another users xp_migration', async () => {
    const authedDb = testEnv.authenticatedContext('user2').firestore();
    await assertFails(
      xpMigrationRef(authedDb, 'user1').set({
        status: 'complete',
        completedAt: new Date(),
        version: '1.0',
      })
    );
  });
});

