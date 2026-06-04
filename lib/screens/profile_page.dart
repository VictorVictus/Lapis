import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/providers/accent_color_provider.dart';
import 'package:to_do_app/providers/demo_statistics_provider.dart';
import 'package:to_do_app/providers/statistics_provider.dart';
import 'package:to_do_app/services/demo_statistics_service.dart';
import 'package:to_do_app/services/statistics_service.dart';
import 'package:to_do_app/services/focus_session_service.dart';
import 'package:to_do_app/theme/app_theme.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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

  Future<void> _refresh() async {
    ref.invalidate(statisticsProvider(widget.user.uid));
    await _loadFocusStats();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statisticsProvider(widget.user.uid));
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
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: statsAsync.when(
              data: (stats) => _buildContent(context, stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, StatisticsData stats) {
    final totalSessions = _focusStats['totalSessions'] ?? 0;
    final totalSeconds = _focusStats['totalSeconds'] ?? 0;
    final focusHours = (totalSeconds / 3600).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
            ],
          ),
          _buildUserHeader(),
          const SizedBox(height: 24),
          _buildSectionTitle('Overview'),
          const SizedBox(height: 12),
          _buildSummaryGrid(stats),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Overdue rate', '${(stats.overdueRate * 100).toStringAsFixed(0)}%', _accentVariant(0.15), 'of tasks with deadlines')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Avg time', _formatHours(stats.avgCompletionHours), _accentVariant(0.3), 'from created to done')),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Focus sessions', '$totalSessions', _accentVariant(-0.1), 'total')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Focus hours', focusHours, _accentVariant(-0.2), 'total')),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Last 7 Days'),
          const SizedBox(height: 12),
          _buildBarChart(stats.dailyCompletions),
          const SizedBox(height: 24),
          _buildSectionTitle('Productivity by Weekday'),
          const SizedBox(height: 12),
          _buildWeekdayHeatmap(stats.weekdayDistribution),
          const SizedBox(height: 24),
          if (stats.monthlyTrend.length > 1) ...[
            _buildSectionTitle('Monthly Trend'),
            const SizedBox(height: 12),
            _buildMonthlyTrend(stats.monthlyTrend),
            const SizedBox(height: 24),
          ],
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

  void _cycleDemoData(WidgetRef ref) {
    if (!kDebugMode) return;
    final isDemo = ref.read(useDemoStatsProvider);
    if (!isDemo) {
      ref.read(useDemoStatsProvider.notifier).enable();
      ref.read(demoPresetProvider.notifier).set(DemoPreset.normal);
      ref.invalidate(statisticsProvider(widget.user.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo ON — tap again to cycle presets'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final current = ref.read(demoPresetProvider);
      final next = DemoPreset.values[(current.index + 1) % DemoPreset.values.length];
      if (next == DemoPreset.normal) {
        ref.read(useDemoStatsProvider.notifier).disable();
        ref.invalidate(statisticsProvider(widget.user.uid));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo OFF'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ref.read(demoPresetProvider.notifier).set(next);
        ref.invalidate(statisticsProvider(widget.user.uid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preset: ${next.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Widget _buildUserHeader() {
    final color = Theme.of(context).colorScheme.primary;
    return _buildFrostedCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: kDebugMode ? () => _cycleDemoData(ref) : null,
            onLongPress: kDebugMode ? () => _cycleDemoData(ref) : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.user.initial,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.email,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) {
                      final isDemo = ref.watch(useDemoStatsProvider);
                      if (!isDemo) return const SizedBox.shrink();
                      final preset = ref.watch(demoPresetProvider);
                      final demoAccent = ref.watch(accentColorProvider);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: demoAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: demoAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'DEMO · ${preset.name}',
                          style: TextStyle(
                            color: demoAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSummaryGrid(StatisticsData stats) {
    final palette = _accentPalette(count: 4);
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          _buildStatCard('Completed', '${stats.totalCompleted}', palette[0], 'tasks'),
          _buildStatCard('Total', '${stats.totalTasks}', palette[1], 'tasks created'),
          _buildStatCard('Streak', '${stats.currentStreak}d', palette[2], 'current'),
          _buildStatCard('Best', '${stats.bestStreak}d', palette[3], 'best streak'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, [String? subtitle]) {
    return _buildFrostedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFrostedCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBarChart(List<DailyStats> daily) {
    final maxVal = daily.fold<int>(1, (p, d) => d.completed > p ? d.completed : p);
    return _buildFrostedCard(
      child: SizedBox(
        height: 140,
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
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 100 * ratio,
                      decoration: BoxDecoration(
                        color: _accentVariant(0.1).withValues(alpha: 0.3 + 0.7 * ratio),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('E').format(d.date),
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeatmap(Map<int, int> weekdayData) {
    final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = weekdayData.values.fold<int>(1, (p, c) => c > p ? c : p);
    return _buildFrostedCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final wd = i + 1;
          final count = weekdayData[wd] ?? 0;
          final ratio = count / maxVal;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentVariant(0.0).withValues(alpha: 0.15 + 0.6 * ratio),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.5 + 0.5 * ratio),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                days[wd].substring(0, 1),
                      style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyTrend(List<MonthlyStats> trend) {
    final maxVal = trend.fold<int>(1, (p, m) => m.count > p ? m.count : p);
    return _buildFrostedCard(
      child: Column(
        children: trend.map((m) {
          final ratio = m.count / maxVal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    m.label,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: _accentVariant(0.1),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${m.count}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieLegend(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return _buildFrostedCard(
        child: const Text('No data', style: TextStyle(color: Colors.white60)),
      );
    }

    final colors = _accentPalette();

    return _buildFrostedCard(
      child: Column(
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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barRatio,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 55,
                  child: Text(
                    '$count ($pct%)',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours < 1) {
      final mins = (hours * 60).round();
      return '${mins}m';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  List<Color> _accentPalette({int count = 8}) {
    final accent = ref.watch(accentColorProvider);
    final hsl = HSLColor.fromColor(accent);
    return List.generate(count, (i) {
      return hsl.withHue((hsl.hue + i * (360.0 / count)) % 360.0).toColor();
    });
  }

  Color _accentVariant(double lightnessOffset) {
    final accent = ref.watch(accentColorProvider);
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness + lightnessOffset).clamp(0.0, 1.0)).toColor();
  }
}
