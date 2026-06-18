import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/user.dart' as app_user;
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/unified_task_provider.dart';
import 'package:to_do_app/theme/app_theme.dart';

enum CalendarViewMode { month, week, day }

class SchedulePage extends ConsumerStatefulWidget {
  final app_user.User user;
  const SchedulePage({super.key, required this.user});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gradientColors(context).primary,
              AppTheme.gradientColors(context).secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Back', style: TextStyle(color: Colors.white, fontSize: 18)),
                    const Spacer(),
                    _ViewToggle(
                      current: _viewMode,
                      onChanged: (v) => setState(() => _viewMode = v),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Schedule',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return _buildMonthView();
      case CalendarViewMode.week:
        return _buildWeekView();
      case CalendarViewMode.day:
        return _buildDayView();
    }
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFBEF3FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                _buildCalendarHeader(),
                const SizedBox(height: 10),
                _buildDaysOfWeek(),
                _buildCalendarGrid(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            _isToday(_selectedDay) ? "Today's Tasks" : "${DateFormat('MMMM d').format(_selectedDay)} Tasks",
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTasksForSelectedDay()),
      ],
    );
  }

  Widget _buildWeekView() {
    final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFBEF3FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _focusedDay = _focusedDay.subtract(const Duration(days: 7))),
                    ),
                    Text(
                      '${DateFormat('MMM d').format(days.first)} - ${DateFormat('MMM d, yyyy').format(days.last)}',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF003D9E),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _focusedDay = _focusedDay.add(const Duration(days: 7))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDaysOfWeek(),
                _buildWeekGrid(days),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            DateFormat('EEEE, MMMM d').format(_selectedDay),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTasksForSelectedDay()),
      ],
    );
  }

  Widget _buildWeekGrid(List<DateTime> days) {
    final tasksAsync = ref.watch(unifiedTasksProvider(widget.user.uid));
    return tasksAsync.when(
      data: (allTasks) {
        return SizedBox(
          height: 100,
          child: Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final dayTasks = allTasks.where((t) =>
                t.scheduledAt != null && _isSameDay(t.scheduledAt!, day) && !t.isArchived
              ).toList();
              final isSelected = _isSameDay(day, _selectedDay);
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFACE9FF))
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF003D9E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ...dayTasks.take(3).map((t) => Container(
                          width: 4, height: 4, margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: Color(t.category.color),
                            shape: BoxShape.circle,
                          ),
                        )),
                        if (dayTasks.length > 3)
                          Text('+${dayTasks.length - 3}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CupertinoActivityIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDayView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFBEF3FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 1))),
                ),
                Column(
                  children: [
                    Text(
                      DateFormat('EEEE').format(_selectedDay),
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF003D9E),
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDay),
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF003D9E),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDay = _selectedDay.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildTasksForSelectedDay()),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.white : const Color(0xFF003D9E);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(_focusedDay),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: headerColor),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: headerColor),
              onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: headerColor),
              onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaysOfWeek() {
    final List<String> days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((day) => Text(
        day, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1).weekday % 7;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(unifiedTasksProvider(widget.user.uid));

    return tasksAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (allTasks) {
        final Map<String, List<int>> tasksByDate = {};
        for (var task in allTasks) {
          if (task.scheduledAt != null) {
            final dateKey = DateFormat('yyyy-MM-dd').format(task.scheduledAt!);
            final dotColor = task.status == TaskStatus.fulfilled ? 0xFF9E9E9E : task.category.color;
            tasksByDate.putIfAbsent(dateKey, () => []).add(dotColor);
          }
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, mainAxisSpacing: 10,
          ),
          itemCount: daysInMonth + firstDayOfMonth,
          itemBuilder: (context, index) {
            if (index < firstDayOfMonth) return const SizedBox.shrink();
            final day = index - firstDayOfMonth + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, day);
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final bool isSelected = _isSameDay(date, _selectedDay);
            final colors = tasksByDate[dateKey] ?? [];

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35) : const Color(0xFFACE9FF))
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF1E58FF))
                            : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF003D9E)),
                        fontWeight: FontWeight.bold, fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: colors.take(3).map((c) => Container(
                      width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                    )).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTasksForSelectedDay() {
    final tasksAsync = ref.watch(unifiedTasksProvider(widget.user.uid));

    return tasksAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (allTasks) {
        final filteredTasks = allTasks
            .where((task) => task.scheduledAt != null && _isSameDay(task.scheduledAt!, _selectedDay))
            .toList()
          ..sort((a, b) {
            final aTime = a.scheduledAt;
            final bTime = b.scheduledAt;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return aTime.compareTo(bTime);
          });

        if (filteredTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 40, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                const Text('No tasks for this day', style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return TaskListItem(
                key: ValueKey(task.id),
                task: task,
                selectedIndex: task.status == TaskStatus.fulfilled ? 2 : 0,
              );
            },
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }
}

class _ViewToggle extends StatelessWidget {
  final CalendarViewMode current;
  final ValueChanged<CalendarViewMode> onChanged;

  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(label: 'M', mode: CalendarViewMode.month),
          _toggleButton(label: 'W', mode: CalendarViewMode.week),
          _toggleButton(label: 'D', mode: CalendarViewMode.day),
        ],
      ),
    );
  }

  Widget _toggleButton({required String label, required CalendarViewMode mode}) {
    final isActive = current == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
