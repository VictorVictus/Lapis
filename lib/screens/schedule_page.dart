import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/user.dart' as app_user;
import 'package:to_do_app/widgets/task_list_item.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/task_provider.dart';

class SchedulePage extends ConsumerStatefulWidget {
  final app_user.User user;
  const SchedulePage({super.key, required this.user});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Back',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Calendar Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                      const SizedBox(height: 10),
                      _buildTimePickerPlaceholder(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Tasks List Title
              Center(
                child: Text(
                  _isToday(_selectedDay) 
                      ? "Today's Tasks" 
                      : "${DateFormat('MMMM d').format(_selectedDay)} Tasks",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Dynamic Task List
              Expanded(
                child: _buildTasksForSelectedDay(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.white : const Color(0xFF003D9E);
    final iconColor = isDark ? Colors.white70 : Colors.blue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: headerColor,
              ),
            ),
            Icon(Icons.chevron_right, color: headerColor),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: iconColor),
              onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: iconColor),
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
        day,
        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1).weekday % 7;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(tasksStreamProvider(widget.user.uid));
    
    return tasksAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      data: (tasks) {
        // Group tasks by date for dots
        final Map<String, List<int>> tasksByDate = {};
        for (var task in tasks) {
          if (task.scheduledAt != null) {
            final dateKey = DateFormat('yyyy-MM-dd').format(task.scheduledAt!);
            final status = task.status;
            final categoryColor = task.category.color;
            
            // If task is fulfilled, we use a grey color for the dot
            final dotColor = (status == TaskStatus.fulfilled) ? 0xFF9E9E9E : categoryColor;
            
            tasksByDate.putIfAbsent(dateKey, () => []).add(dotColor);
          }
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 10,
          ),
          itemCount: daysInMonth + firstDayOfMonth,
          itemBuilder: (context, index) {
            if (index < firstDayOfMonth) return const SizedBox.shrink();
            
            final day = index - firstDayOfMonth + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, day);
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final bool isSelected = _isSameDay(date, _selectedDay);
            final colors = tasksByDate[dateKey] ?? [];

            Color containerColor = Colors.transparent;
            if (isSelected) {
              containerColor = isDark ? Theme.of(context).colorScheme.primary : const Color(0xFFACE9FF);
            }

            Color textColor;
            if (isSelected) {
              textColor = isDark ? Colors.white : const Color(0xFF1E58FF);
            } else {
              textColor = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF003D9E);
            }

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: containerColor,
                      shape: BoxShape.circle,
                      border: isSelected && !isDark ? Border.all(color: Colors.white, width: 1.5) : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Dots Logic: Show categories, max 3
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: colors.take(3).map((color) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                      ),
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

  Widget _buildTimePickerPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : Colors.white24,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Time', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF003D9E), fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).colorScheme.primary : const Color(0xFFACE9FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('hh:mm a').format(DateTime.now()),
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF003D9E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksForSelectedDay() {
    final tasksAsync = ref.watch(tasksStreamProvider(widget.user.uid));
    
    return tasksAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white70))),
      data: (tasks) {
        final filteredTasks = tasks
            .where((task) => task.scheduledAt != null && _isSameDay(task.scheduledAt!, _selectedDay))
            .toList();

        if (filteredTasks.isEmpty) {
          return const Center(
            child: Text(
              'No tasks for this day',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              final bool isFulfilled = task.status == TaskStatus.fulfilled;
              
              return Opacity(
                opacity: isFulfilled ? 0.6 : 1.0,
                child: TaskListItem(
                  task: task,
                  onComplete: () {},
                  selectedIndex: isFulfilled ? 2 : 0, // Pass state to trigger the right UI
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }
}
