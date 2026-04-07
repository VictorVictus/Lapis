import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/widgets/task_list_view.dart';
import 'package:to_do_app/widgets/add_task_sheet.dart';
import 'package:to_do_app/widgets/dashboard_header.dart';
import 'package:to_do_app/widgets/task_status_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/providers/user_provider.dart';
import 'package:to_do_app/providers/sync_provider.dart';
import 'package:to_do_app/providers/task_provider.dart';
import 'package:to_do_app/models/task.dart';

class Dashboard extends ConsumerStatefulWidget {
  final User user;
  const Dashboard({super.key, required this.user});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Celebration Listener
    ref.listen(celebrationProvider, (previous, next) {
      if (next > 0) {
        _confettiController.play();
      }
    });

    // Global Sync Error Listener
    ref.listen(lastSyncErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            content: Text(next as String),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(lastSyncErrorProvider.notifier).setError(null);
              },
            ),
          ),
        );
      }
    });

    final selectedIndex = ref.watch(dashboardTabIndexProvider);
    final isUploading = ref.watch(isUploadingProfilePicProvider);
    final userAsync = ref.watch(userStreamProvider(widget.user.uid));
    
    final displayUser = userAsync.value ?? widget.user;
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  
                  DashboardHeader(
                    displayUser: displayUser,
                    isUploading: isUploading,
                    onAvatarTap: () => controller.pickAndUploadImage(widget.user.uid),
                  ),

                  const SizedBox(height: 20),
                  
                  CupertinoSearchTextField(
                    placeholder: 'Search tasks',
                    onChanged: controller.onSearchChanged,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    itemColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Theme.of(context).colorScheme.primary,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    placeholderStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    suffixIcon: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final counts = ref.watch(taskCountsProvider(displayUser.uid));
                      return TaskStatusFilter(
                        selectedIndex: selectedIndex,
                        undoneCount: counts[TaskStatus.undone] ?? 0,
                        inProgressCount: counts[TaskStatus.inProgress] ?? 0,
                        onTabSelected: (index) {
                          ref.read(dashboardTabIndexProvider.notifier).setIndex(index);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  
                  Expanded(
                    child: TaskListView(
                      userId: displayUser.uid,
                      selectedIndex: selectedIndex,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SizedBox(
          height: 70,
          width: 400,
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddTaskSheet(),
              );
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(35),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).brightness == Brightness.dark 
                           ? Colors.white 
                           : Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  'Add a New Task',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                             ? Colors.white 
                             : CupertinoColors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
