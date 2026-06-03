import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/providers/statistics_provider.dart';
import 'package:to_do_app/services/statistics_service.dart';
import 'package:to_do_app/services/focus_session_service.dart';

class StatsPage extends ConsumerStatefulWidget {
  final User user;

  const StatsPage({super.key, required this.user});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  Map<String, int> _focusStats = {};

  @override
  void initState() {
    super.initState();
    _loadFocusStats();
  }

  Future<void> _loadFocusStats() async {
    final stats = await FocusSessionService().getStats(widget.user.uid);
    if (mounted) setState(() => _focusStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statisticsProvider(widget.user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: statsAsync.when(
        data: (stats) => _buildContent(context, stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, StatisticsData stats) {
    final totalSessions = _focusStats['totalSessions'] ?? 0;
    final totalSeconds = _focusStats['totalSeconds'] ?? 0;
    final focusHours = (totalSeconds / 3600).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(stats),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Focus sessions', '$totalSessions', Colors.teal),
              const SizedBox(width: 12),
              _buildStatCard('Focus hours', focusHours, Colors.teal.shade700),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Last 7 Days'),
          const SizedBox(height: 12),
          _buildBarChart(stats.dailyCompletions),
          const SizedBox(height: 24),
          _buildSectionTitle('By Category'),
          const SizedBox(height: 12),
          _buildPieLegend(stats.byCategory),
          const SizedBox(height: 24),
          _buildSectionTitle('By Priority'),
          const SizedBox(height: 12),
          _buildPieLegend(stats.byPriority),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(StatisticsData stats) {
    return Row(
      children: [
        _buildStatCard('Completed', '${stats.totalCompleted}', Colors.green),
        const SizedBox(width: 12),
        _buildStatCard('Total', '${stats.totalTasks}', Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard('Streak', '${stats.currentStreak} days', Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard('Best', '${stats.bestStreak} days', Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBarChart(List<DailyStats> daily) {
    final maxVal = daily.fold<int>(1, (p, d) => d.completed > p ? d.completed : p);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: daily.map((d) {
          final ratio = maxVal > 0 ? d.completed / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${d.completed}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 120 * ratio,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.3 + 0.7 * ratio),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('E').format(d.date),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieLegend(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const Text('No data');
    }

    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.red,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    ];

    return Column(
      children: data.entries.toList().asMap().entries.map((entry) {
        final i = entry.key;
        final name = entry.value.key;
        final count = entry.value.value;
        final pct = (count / total * 100).toStringAsFixed(0);
        final color = colors[i % colors.length];
        final barRatio = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 80, child: Text(name, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barRatio,
                    backgroundColor: Colors.grey[300],
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text('$count ($pct%)', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
