import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback? onStartInteractive;
  const TutorialScreen({
    super.key,
    required this.onDone,
    this.onStartInteractive,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  final List<({String title, String body, IconData icon})> _items = const [
    (
      title: 'Track Attendance Fast',
      body:
          'Use Today\'s Lectures to mark Present/Absent quickly. Swipe actions can be enabled in Settings.',
      icon: Icons.check_circle_outline,
    ),
    (
      title: 'Rich Subject Profiles',
      body:
          'Each subject can store subject code, teacher/professor name, reminders, goals, and forecast. Edit details anytime from the subject card.',
      icon: Icons.badge_outlined,
    ),
    (
      title: 'Timetable & Week Grid',
      body:
          'Use calendar or weekly table view. Week table fills free slots up to the latest class slot so planning is easy.',
      icon: Icons.calendar_month_outlined,
    ),
    (
      title: 'Semesters, Cloud & Profile',
      body:
          'Rename semester profiles, keep data synced across devices, and manage profile + theme from Settings.',
      icon: Icons.cloud_done_outlined,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _items.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Tutorial'),
        actions: [
          TextButton(
            onPressed: widget.onDone,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (v) => setState(() => _page = v),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 88),
                      const SizedBox(height: 18),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.body,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                ...List.generate(
                  _items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    width: _page == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: _page == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (isLast && widget.onStartInteractive != null)
                  OutlinedButton(
                    onPressed: widget.onStartInteractive,
                    child: const Text('Interactive Guide'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (isLast) {
                      widget.onDone();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
