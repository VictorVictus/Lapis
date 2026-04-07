import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/add_task_provider.dart';
import 'package:to_do_app/services/TaskService.dart';
import 'package:to_do_app/models/task.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// Mocks
class MockTaskService extends Mock implements TaskService {}
class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}
class MockUser extends Mock implements firebase_auth.User {}

class FakeTask extends Fake implements Task {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTask());
  });

  group('AddTaskNotifier Tests', () {
    late MockTaskService mockTaskService;
    late ProviderContainer container;

    setUp(() {
      mockTaskService = MockTaskService();
      
      // Setup the container with the mock
      container = ProviderContainer(
        overrides: [
          taskServiceProvider.overrideWithValue(mockTaskService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have a scheduledAt date', () {
      final state = container.read(addTaskProvider);
      expect(state.scheduledAt, isA<DateTime>());
      expect(state.isSaving, isFalse);
    });

    test('updateTitle should update title in state', () {
      final notifier = container.read(addTaskProvider.notifier);
      notifier.updateTitle('New Title');
      
      final state = container.read(addTaskProvider);
      expect(state.title, 'New Title');
    });

    test('updateHasDeadline should set a default deadline', () {
      final notifier = container.read(addTaskProvider.notifier);
      notifier.updateHasDeadline(true);
      
      final state = container.read(addTaskProvider);
      expect(state.hasDeadline, isTrue);
      expect(state.deadline, isNotNull);
    });

    test('saveTask should return false if title is empty', () async {
      final notifier = container.read(addTaskProvider.notifier);
      final result = await notifier.saveTask();
      
      expect(result, isFalse);
      verifyNever(() => mockTaskService.createTask(any()));
    });
  });
}
