import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/providers/dashboard_provider.dart';
import 'package:to_do_app/models/focus_session.dart';
import 'package:to_do_app/services/focus_mode_service.dart';
import 'package:to_do_app/services/focus_session_service.dart';
import 'package:to_do_app/services/task_service.dart';

enum _FocusPhase { setup, active, complete }

class FocusModeScreen extends ConsumerStatefulWidget {
  final Task task;

  const FocusModeScreen({super.key, required this.task});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen>
    with SingleTickerProviderStateMixin {
  final _focusService = FocusModeService();
  _FocusPhase _phase = _FocusPhase.setup;
  Duration _selectedDuration = const Duration(minutes: 25);
  Duration _remaining = Duration.zero;
  Timer? _timer;
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  Future<void> _startFocus() async {
    try {
      await _focusService.startLockTask();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _phase = _FocusPhase.active;
      _remaining = _selectedDuration;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        _onTimerComplete();
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  Future<void> _saveSession(Duration duration) async {
    final session = FocusSession(
      id: FirebaseFirestore.instance.collection('focus_sessions').doc().id,
      userId: widget.task.userId,
      taskId: widget.task.id,
      taskTitle: widget.task.title,
      durationSeconds: duration.inSeconds,
      createdAt: DateTime.now(),
    );
    try {
      await FocusSessionService().saveSession(session);
    } catch (_) {}
  }

  Future<void> _onTimerComplete() async {
    unawaited(HapticFeedback.heavyImpact());
    await _saveSession(_selectedDuration);
    try {
      await _focusService.stopLockTask();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _phase = _FocusPhase.complete);
  }

  Future<void> _endFocusEarly() async {
    _timer?.cancel();
    final elapsed = _selectedDuration - _remaining;
    await _saveSession(elapsed);
    try {
      await _focusService.stopLockTask();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _markDone() async {
    try {
      await _focusService.stopLockTask();
    } catch (_) {}
    final updated = widget.task.copyWith(
      status: TaskStatus.fulfilled,
      completedAt: DateTime.now(),
    );
    try {
      await ref.read(taskServiceProvider).updateTask(updated);
      ref.read(dashboardProvider.notifier).triggerCelebration();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _restart() {
    setState(() {
      _phase = _FocusPhase.setup;
      _remaining = Duration.zero;
    });
  }

  Future<void> _exit() async {
    await _focusService.stopLockTask();
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showConfirmDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Lock screen?'),
        content: Text(
          'Focus mode will lock Lapis to your screen for ${_formatDuration(_selectedDuration)}. '
          'You won\'t be able to open other apps until the timer ends.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Start Focus'),
            onPressed: () {
              Navigator.pop(ctx);
              _startFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPhase() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(widget.task.category.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Set duration',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: _selectedDuration,
                  onTimerDurationChanged: (d) {
                    setState(() => _selectedDuration = d);
                  },
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _showConfirmDialog,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Start Focus'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(widget.task.category.color),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePhase() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(widget.task.category.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.task.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                final scale = 1.0 + _breatheController.value * 0.05;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Text(
                _formatDuration(_remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _endFocusEarly,
              icon: const Icon(Icons.close, color: Colors.white54),
              label: const Text(
                'End focus',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletePhase() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Color(widget.task.category.color),
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'Session complete!',
                  style: TextStyle(
                    color: Color(widget.task.category.color),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.task.title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _markDone,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(widget.task.category.color),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _exit,
                  child: const Text(
                    'Not now — leave focus',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _FocusPhase.setup:
        return _buildSetupPhase();
      case _FocusPhase.active:
        return _buildActivePhase();
      case _FocusPhase.complete:
        return _buildCompletePhase();
    }
  }
}
