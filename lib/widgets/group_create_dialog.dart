import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/services/group_service.dart';

class GroupCreateDialog extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const GroupCreateDialog({super.key, required this.userId, required this.username});

  @override
  ConsumerState<GroupCreateDialog> createState() => _GroupCreateDialogState();
}

class _GroupCreateDialogState extends ConsumerState<GroupCreateDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Create Group'),
      content: Column(
        children: [
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Group name',
            autofocus: true,
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _descriptionController,
            placeholder: 'Description (optional)',
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const CupertinoActivityIndicator(),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _loading ? null : _createGroup,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await ref.read(groupServiceProvider).createGroup(
        name,
        widget.userId,
        widget.username,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create group: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }
}
