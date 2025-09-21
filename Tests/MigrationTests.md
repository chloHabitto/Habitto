# Migration Test Suite

This directory contains comprehensive tests for the Habitto migration system, ensuring crash-safe data migrations and storage integrity.

## Overview

The migration test suite validates:
- ✅ **Crash Safety**: Recovery from mid-migration failures
- ✅ **Data Integrity**: Preservation of user data during migrations
- ✅ **Idempotence**: Multiple migration runs don't cause issues
- ✅ **Edge Cases**: Empty datasets, large datasets, corrupted data
- ✅ **Kill Switch**: Remote migration control and failure rate monitoring
- ✅ **Performance**: Memory usage and execution time monitoring

## Test Files

### Core Test Files
- **`MigrationTestSuite.swift`** - Main test implementation with all test scenarios
- **`MigrationTestConfig.swift`** - Test configurations and execution plans
- **`MigrationTestRunner.swift`** - Test execution engine and UI components
- **`RunMigrationTests.swift`** - Command-line test runner script

### Test Categories

#### 🚨 Critical Tests (Must Pass)
1. **Successful Migration** - Normal migration flow
2. **Crash Recovery** - Mid-migration failure recovery
3. **Data Corruption** - Corrupted file recovery
4. **Kill Switch** - Remote migration control

#### 🔧 Standard Tests
5. **Idempotent Migration** - Multiple migration runs
6. **Version Skipping** - Direct migration from v1→v3
7. **Empty Dataset** - Migration with no data
8. **Failure Rate Detection** - High failure rate monitoring

#### 🧪 Comprehensive Tests
9. **Large Dataset** - Migration with 1000+ habits
10. **Low Disk Space** - Migration under resource constraints
11. **Concurrent Migrations** - Multiple simultaneous attempts

## Test Execution Plans

### Quick Validation (2 tests, ~60s)
```bash
swift Tests/RunMigrationTests.swift quick
```
- Successful Migration
- Crash Recovery

### Standard Validation (8 tests, ~5min)
```bash
swift Tests/RunMigrationTests.swift standard
```
- All critical tests
- Basic edge case coverage

### Comprehensive Suite (11 tests, ~15min)
```bash
swift Tests/RunMigrationTests.swift comprehensive
```
- Full test coverage
- All scenarios and edge cases

### Stress Testing (3 tests, ~30min)
```bash
swift Tests/RunMigrationTests.swift stress
```
- Large dataset handling
- Resource constraint testing
- Concurrent execution testing

## Test Scenarios

### 1. Successful Migration
**Purpose**: Validate normal migration flow
**Data**: 10 standard habits
**Duration**: ~2s
**Critical**: ✅ Yes

### 2. Idempotent Migration
**Purpose**: Ensure multiple migration runs are safe
**Data**: 10 standard habits
**Duration**: ~3s
**Critical**: ❌ No

### 3. Version Skipping
**Purpose**: Test migration from v1.0.0 directly to v2.0.0
**Data**: 10 standard habits
**Duration**: ~2s
**Critical**: ❌ No

### 4. Crash Recovery
**Purpose**: Test recovery from mid-migration failure
**Data**: 10 standard habits
**Duration**: ~4s
**Critical**: ✅ Yes

### 5. Data Corruption
**Purpose**: Test recovery from corrupted files
**Data**: 10 standard habits
**Duration**: ~3s
**Critical**: ✅ Yes

### 6. Empty Dataset
**Purpose**: Test migration with no habits
**Data**: 0 habits
**Duration**: ~1s
**Critical**: ❌ No

### 7. Large Dataset
**Purpose**: Test migration with 1000+ habits
**Data**: 1000 habits
**Duration**: ~10s
**Critical**: ❌ No

### 8. Low Disk Space
**Purpose**: Test migration under resource constraints
**Data**: 10 standard habits
**Duration**: ~5s
**Critical**: ❌ No

### 9. Concurrent Migrations
**Purpose**: Test multiple simultaneous migration attempts
**Data**: 10 standard habits
**Duration**: ~6s
**Critical**: ❌ No

### 10. Kill Switch
**Purpose**: Test remote migration control
**Data**: 1 minimal habit
**Duration**: ~1s
**Critical**: ✅ Yes

### 11. Failure Rate Detection
**Purpose**: Test high failure rate monitoring
**Data**: 1 minimal habit
**Duration**: ~2s
**Critical**: ❌ No

## Test Data Sets

### Minimal (1 habit)
- Single habit for basic functionality testing
- Fast execution
- Low resource usage

### Standard (10 habits)
- Typical user dataset
- Balanced test coverage
- Standard execution time

### Large (1000 habits)
- Power user dataset
- Performance testing
- Resource usage validation

### Edge Case (5000 habits)
- Stress testing
- Memory usage validation
- Long execution time

## Environment Requirements

### Minimum Requirements
- **Disk Space**: 100MB available
- **Memory**: 50MB available
- **iOS Version**: 15.0+
- **Swift Version**: 5.5+

### Recommended Requirements
- **Disk Space**: 500MB available
- **Memory**: 200MB available
- **iOS Version**: 16.0+
- **Swift Version**: 5.7+

## Running Tests

### From Command Line
```bash
# Quick validation
swift Tests/RunMigrationTests.swift quick

# Standard validation
swift Tests/RunMigrationTests.swift standard

# Comprehensive suite
swift Tests/RunMigrationTests.swift comprehensive

# Stress testing
swift Tests/RunMigrationTests.swift stress
```

### From Xcode
1. Open the project in Xcode
2. Select the test target
3. Run tests with Cmd+U
4. View results in test navigator

### From Test UI
1. Launch the app
2. Navigate to Settings > Developer > Migration Tests
3. Select test plan
4. Tap "Run Tests"
5. View results in real-time

## Test Results

### Success Criteria
- ✅ All critical tests must pass
- ✅ Success rate ≥ 95%
- ✅ No data loss during migration
- ✅ Recovery from all failure scenarios

### Failure Handling
- ❌ Failed tests are logged with error details
- ❌ Partial failures are reported
- ❌ Environment issues are flagged
- ❌ Performance regressions are detected

### Reporting
- 📊 Detailed test reports with timing
- 📈 Performance metrics and memory usage
- 📋 Failure analysis and recommendations
- 📝 Test execution logs

## Troubleshooting

### Common Issues

#### Test Environment Issues
```
⚠️ Low disk space: 50MB available
```
**Solution**: Free up disk space or use smaller test datasets

#### Memory Issues
```
⚠️ Low memory: 30MB available
```
**Solution**: Close other applications or reduce test dataset size

#### Permission Issues
```
❌ Cannot access test directory
```
**Solution**: Check file system permissions and app sandbox

### Debug Mode
Enable debug logging for detailed test execution:
```swift
MigrationTestRunner.shared.enableDebugLogging = true
```

### Test Isolation
Each test runs in isolation with:
- Clean test directory
- Fresh data store
- Reset migration state
- Cleanup after completion

## Continuous Integration

### GitHub Actions
```yaml
- name: Run Migration Tests
  run: |
    swift Tests/RunMigrationTests.swift standard
```

### Local CI
```bash
#!/bin/bash
# Run tests before deployment
swift Tests/RunMigrationTests.swift comprehensive
if [ $? -eq 0 ]; then
    echo "✅ All tests passed"
else
    echo "❌ Tests failed"
    exit 1
fi
```

## Performance Benchmarks

### Expected Performance
- **Quick Tests**: < 60 seconds
- **Standard Tests**: < 5 minutes
- **Comprehensive Tests**: < 15 minutes
- **Stress Tests**: < 30 minutes

### Memory Usage
- **Minimal Dataset**: < 10MB
- **Standard Dataset**: < 50MB
- **Large Dataset**: < 200MB
- **Edge Case Dataset**: < 500MB

### Disk Usage
- **Test Data**: ~1MB per 1000 habits
- **Backups**: ~2MB per 1000 habits
- **Logs**: ~100KB per test run
- **Temporary Files**: ~10MB during execution

## Contributing

### Adding New Tests
1. Add test method to `MigrationTestSuite`
2. Add configuration to `MigrationTestConfig`
3. Update test plans as needed
4. Add documentation to this README

### Test Guidelines
- Each test should be independent
- Use descriptive test names
- Include performance assertions
- Clean up resources after tests
- Handle edge cases gracefully

### Code Review Checklist
- [ ] Test covers intended scenario
- [ ] Test is deterministic
- [ ] Test cleans up resources
- [ ] Test has appropriate assertions
- [ ] Test documentation is updated
