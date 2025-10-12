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
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    await assertSucceeds(goalRef.set(createGoalVersionData('habit1')));
  });

  test('User cannot create goal with invalid date format', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    const invalidData = createGoalVersionData('habit1');
    invalidData.effectiveLocalDate = '2025/10/15'; // Wrong format

    await assertFails(goalRef.set(invalidData));
  });

  test('User cannot create goal with negative goal value', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    const invalidData = createGoalVersionData('habit1');
    invalidData.goal = -1;

    await assertFails(goalRef.set(invalidData));
  });

  test('User can create goal with zero value', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    const validData = createGoalVersionData('habit1');
    validData.goal = 0;

    await assertSucceeds(goalRef.set(validData));
  });

  test('User cannot update goal version (immutable)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    // Create goal first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('goalVersions')
        .doc('habit1')
        .collection('habit1')
        .doc('version1')
        .set(createGoalVersionData('habit1'));
    });

    // Try to update
    await assertFails(goalRef.update({ goal: 5 }));
  });

  test('User can delete goal version', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const goalRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('goalVersions')
      .doc('habit1')
      .collection('habit1')
      .doc('version1');

    // Create goal first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('goalVersions')
        .doc('habit1')
        .collection('habit1')
        .doc('version1')
        .set(createGoalVersionData('habit1'));
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
    const completionRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('completions')
      .doc('2025-10-15')
      .collection('2025-10-15')
      .doc('habit1');

    await assertSucceeds(completionRef.set(createCompletionData()));
  });

  test('User cannot create completion with invalid date format', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('completions')
      .doc('10-15-2025') // Invalid format
      .collection('10-15-2025')
      .doc('habit1');

    await assertFails(completionRef.set(createCompletionData()));
  });

  test('User cannot create completion with negative count', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('completions')
      .doc('2025-10-15')
      .collection('2025-10-15')
      .doc('habit1');

    const invalidData = createCompletionData();
    invalidData.count = -1;

    await assertFails(completionRef.set(invalidData));
  });

  test('User can update completion count', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const completionRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('completions')
      .doc('2025-10-15')
      .collection('2025-10-15')
      .doc('habit1');

    // Create completion first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('completions')
        .doc('2025-10-15')
        .collection('2025-10-15')
        .doc('habit1')
        .set(createCompletionData());
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
    const completionRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('completions')
      .doc('2025-10-15')
      .collection('2025-10-15')
      .doc('habit1');

    // Create completion first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('completions')
        .doc('2025-10-15')
        .collection('2025-10-15')
        .doc('habit1')
        .set(createCompletionData());
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
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    await assertSucceeds(ledgerRef.set(createXPLedgerData()));
  });

  test('User can create ledger entry with negative delta', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    const validData = createXPLedgerData();
    validData.delta = -25;

    await assertSucceeds(ledgerRef.set(validData));
  });

  test('User cannot create ledger entry with empty reason', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    const invalidData = createXPLedgerData();
    invalidData.reason = '';

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot create ledger entry with reason > 500 chars', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    const invalidData = createXPLedgerData();
    invalidData.reason = 'a'.repeat(501);

    await assertFails(ledgerRef.set(invalidData));
  });

  test('User cannot update ledger entry (immutable)', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    // Create ledger entry first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('xp')
        .doc('ledger')
        .collection('ledger')
        .doc('event1')
        .set(createXPLedgerData());
    });

    // Try to update
    await assertFails(ledgerRef.update({ delta: 100 }));
  });

  test('User cannot delete ledger entry', async () => {
    const authedDb = testEnv.authenticatedContext('user1').firestore();
    const ledgerRef = authedDb
      .collection('users')
      .doc('user1')
      .collection('xp')
      .doc('ledger')
      .collection('ledger')
      .doc('event1');

    // Create ledger entry first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc('user1')
        .collection('xp')
        .doc('ledger')
        .collection('ledger')
        .doc('event1')
        .set(createXPLedgerData());
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

