import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/widgets/web_image_loader.dart';
import 'package:to_do_app/screens/schedule_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/sync_provider.dart';
import 'package:intl/intl.dart';

class DashboardHeader extends ConsumerWidget {
  final User displayUser;
  final bool isUploading;
  final VoidCallback onAvatarTap;

  const DashboardHeader({
    Key? key,
    required this.displayUser,
    required this.isUploading,
    required this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final showSuccess = ref.watch(showSuccessIndicatorProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(color: Colors.white, fontSize: 40),
                  ),
                  const SizedBox(width: 12),
                  _buildSyncIndicator(syncStatus, showSuccess),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  DateFormat('dd MMM yyyy, EEEE').format(DateTime.now()),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 199, 199, 199),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: isUploading ? null : onAvatarTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color.fromARGB(64, 243, 243, 243),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: isUploading
                  ? const CupertinoActivityIndicator(radius: 10)
                  : (displayUser.profilePictureUrl != null
                      ? WebImageLoader(
                          url: displayUser.profilePictureUrl!,
                          size: 48,
                          showShadow: true,
                        )
                      : const Icon(
                          Icons.person,
                          size: 20,
                          color: CupertinoColors.white,
                        )),
            ),
          ),
        ),
        const SizedBox(width: 18),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SchedulePage(user: displayUser),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.calendar,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncIndicator(SyncStatus status, bool showSuccess) {
    if (status == SyncStatus.syncing) {
      return const _RotatingSyncIcon();
    }

    if (status == SyncStatus.error) {
      return const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.redAccent, size: 20);
    }

    if (showSuccess) {
      return const Icon(CupertinoIcons.check_mark_circled, color: Colors.greenAccent, size: 20);
    }

    return const SizedBox.shrink();
  }
}

class _RotatingSyncIcon extends StatefulWidget {
  const _RotatingSyncIcon();

  @override
  State<_RotatingSyncIcon> createState() => _RotatingSyncIconState();
}

class _RotatingSyncIconState extends State<_RotatingSyncIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white70, size: 20),
    );
  }
}
