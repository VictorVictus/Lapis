import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/widgets/kanban_view.dart';
import 'package:to_do_app/theme/app_theme.dart';

class GroupKanbanScreen extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String userId;
  final String userInitial;

  const GroupKanbanScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.userId,
    this.userInitial = '?',
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.gradientColors(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientColors.primary, gradientColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20, right: 20, top: 50, bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(Icons.arrow_back_ios, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 28),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: KanbanView(
                      userId: userId,
                      groupId: groupId,
                      userInitial: userInitial,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
