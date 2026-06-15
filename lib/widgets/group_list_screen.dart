import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/subclasses/group.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/providers/group_providers.dart';
import 'package:to_do_app/services/group_service.dart';
import 'package:to_do_app/theme/app_theme.dart';
import 'package:to_do_app/widgets/group_create_dialog.dart';
import 'package:to_do_app/widgets/join_group_sheet.dart';
import 'package:to_do_app/screens/group_kanban_screen.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return _GroupListBody(userId: user.uid, username: user.username);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _GroupListBody extends ConsumerWidget {
  final String userId;
  final String username;

  const _GroupListBody({required this.userId, required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupListProvider(userId));
    final gradientColors = AppTheme.gradientColors(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientColors.primary, gradientColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(Icons.arrow_back_ios, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      'My Groups',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(Icons.add_circle_outline, size: 28),
                      onPressed: () => _showCreateOrJoin(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: groupsAsync.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_outlined, size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text('No groups yet',
                                style: TextStyle(fontSize: 18,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                            const SizedBox(height: 8),
                            CupertinoButton.filled(
                              child: const Text('Create or Join a Group'),
                              onPressed: () => _showCreateOrJoin(context),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) => _GroupCard(
                        group: groups[index],
                        userId: userId,
                        username: username,
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateOrJoin(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Groups'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => GroupCreateDialog(userId: userId, username: username),
              );
            },
            child: const Text('Create Group'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => JoinGroupSheet(userId: userId, username: username),
              );
            },
            child: const Text('Join Group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerStatefulWidget {
  final Group group;
  final String userId;
  final String username;

  const _GroupCard({required this.group, required this.userId, required this.username});

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.group.id));
    final isAdmin = widget.group.createdBy == widget.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      widget.group.name.isNotEmpty ? widget.group.name[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.group.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.group.memberCount} member${widget.group.memberCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Icon(Icons.star, size: 16,
                        color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
              if (_expanded) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.code, size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text('Code: ${widget.group.inviteCode}',
                        style: TextStyle(fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: const Icon(Icons.copy, size: 16),
                      onPressed: _copyCode,
                    ),
                    if (isAdmin)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: const Text('Renew', style: TextStyle(fontSize: 12)),
                        onPressed: _renewCode,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Members',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                membersAsync.when(
                  data: (members) => Column(
                    children: members.map((m) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          m.username.isNotEmpty ? m.username[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 10,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      title: Text(m.username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: m.uid == widget.userId ? FontWeight.bold : FontWeight.normal,
                          )),
                      trailing: m.role == 'admin'
                          ? Icon(Icons.star, size: 14,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    )).toList(),
                  ),
                  loading: () => const SizedBox(height: 20),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      child: Text('Kanban Board',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          )),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupKanbanScreen(
                            groupId: widget.group.id,
                            groupName: widget.group.name,
                            userId: widget.userId,
                            userInitial: widget.username.isNotEmpty
                                ? widget.username[0].toUpperCase()
                                : '?',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.group.createdBy == widget.userId)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        child: const Text('Leave Group',
                            style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                        onPressed: _leaveGroup,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code copied')),
      );
    }
  }

  Future<void> _renewCode() async {
    try {
      final newCode = await ref.read(groupServiceProvider)
          .regenerateInviteCode(widget.group.id, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New code: $newCode')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    try {
      await ref.read(groupServiceProvider)
          .leaveGroup(widget.group.id, widget.userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave: $e')),
        );
      }
    }
  }
}
