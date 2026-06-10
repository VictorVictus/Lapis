import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/theme/app_theme.dart';

const _prefsKey = 'onboarding_completed';

class OnboardingScreen extends StatefulWidget {
  final Widget next;

  const OnboardingScreen({super.key, required this.next});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _StepData(
      icon: Icons.add_circle_outline,
      title: 'Add your first task',
      description: 'Tap the + button to create a task.\nSet a deadline, priority, or make it recurring.',
    ),
    _StepData(
      icon: Icons.category_outlined,
      title: 'Organize with categories',
      description: 'Group tasks by category — Work, Personal, Shopping, or create your own.',
    ),
    _StepData(
      icon: Icons.bar_chart_rounded,
      title: 'Track your progress',
      description: 'Use Kanban columns, focus mode, and statistics to stay on top of everything.',
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.next),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.gradientColors(context).primary,
      AppTheme.gradientColors(context).secondary,
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_page < _pages.length - 1)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _complete,
                    child: const Text('Skip', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                const SizedBox(height: 48),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: _pages.map((p) => _StepView(data: p)).toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _page < _pages.length - 1
                      ? ElevatedButton(
                          onPressed: () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: colors[0],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                      : ElevatedButton(
                          onPressed: _complete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: colors[0],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text('Get started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String description;

  const _StepData({required this.icon, required this.title, required this.description});
}

class _StepView extends StatelessWidget {
  final _StepData data;

  const _StepView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Future<bool> hasOnboardingBeenCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_prefsKey) == true;
}
