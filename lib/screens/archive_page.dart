import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/services/task_service.dart';
import 'package:intl/intl.dart';

class ArchivePage extends ConsumerWidget {
  final User user;
  const ArchivePage({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(archivedTasksProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No archived tasks'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final completedDate = task.completedAt != null
                  ? DateFormat('MMM d, yyyy').format(task.completedAt!)
                  : 'Unknown';
              return Dismissible(
                key: ValueKey(task.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await ref.read(taskServiceProvider).deleteTask(task.id, task.userId);
                  return false;
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  title: Text(task.title,
                    style: TextStyle(
                      decoration: task.completedAt != null ? TextDecoration.lineThrough : null,
                      color: Colors.grey,
                    ),
                  ),
                  subtitle: Text('Completed $completedDate'),
                  trailing: IconButton(
                    icon: const Icon(Icons.unarchive_outlined),
                    onPressed: () async {
                      await ref.read(taskServiceProvider).updateTask(
                        task.copyWith(archivedAt: null, isArchived: false),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
