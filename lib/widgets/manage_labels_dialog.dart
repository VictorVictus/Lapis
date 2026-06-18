import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/label_providers.dart';
import 'package:to_do_app/services/label_service.dart';
import 'package:to_do_app/models/subclasses/label.dart';

class ManageLabelsDialog extends ConsumerWidget {
  final String userId;

  const ManageLabelsDialog({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(userLabelsProvider(userId));

    return AlertDialog(
      title: const Text('Manage Labels'),
      content: SizedBox(
        width: double.maxFinite,
        child: labelsAsync.when(
          data: (labels) {
            if (labels.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No labels yet. Create one below.'),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  leading: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: Color(label.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(label.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Label'),
                          content: Text('Delete "${label.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(labelServiceProvider).deleteLabel(userId, label.id);
                        ref.invalidate(userLabelsProvider(userId));
                      }
                    },
                  ),
                  onTap: () {
                    _showEditLabelDialog(context, ref, label);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            _showLabelCreateDialog(context, ref, userId);
          },
          child: const Text('+ Add'),
        ),
      ],
    );
  }

  void _showEditLabelDialog(BuildContext context, WidgetRef ref, Label label) {
    final nameController = TextEditingController(text: label.name);
    Color selectedColor = Color(label.color);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Label name',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.red, Colors.orange, Colors.amber, Colors.yellow,
                  Colors.green, Colors.teal, Colors.cyan, Colors.blue,
                  Colors.indigo, Colors.purple, Colors.pink, Colors.brown,
                ].map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selectedColor == c
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await ref.read(labelServiceProvider).updateLabel(label.copyWith(
                  name: nameController.text.trim(),
                  color: selectedColor.toARGB32(),
                ));
                ref.invalidate(userLabelsProvider(userId));
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelCreateDialog(BuildContext context, WidgetRef ref, String userId) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Label name',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.red, Colors.orange, Colors.amber, Colors.yellow,
                  Colors.green, Colors.teal, Colors.cyan, Colors.blue,
                  Colors.indigo, Colors.purple, Colors.pink, Colors.brown,
                ].map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selectedColor == c
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final id = ref.read(labelServiceProvider).generateId(userId);
                await ref.read(labelServiceProvider).createLabel(Label(
                  id: id,
                  name: nameController.text.trim(),
                  color: selectedColor.toARGB32(),
                  userId: userId,
                ));
                ref.invalidate(userLabelsProvider(userId));
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
