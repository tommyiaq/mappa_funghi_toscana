import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/archivio_page.dart';
import '../services/engagement_tracker.dart';
import 'interview_prompt.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const ArchivioPage(),
  ];
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    // Resuming counts too, not just a cold start: on Android the process
    // often survives for days, so counting launches alone would badly
    // under-report how often the app is really used.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recordSession();
  }

  Future<void> _recordSession() async {
    final due = await EngagementTracker.recordSessionAndCheck();
    if (!due || !mounted) return;
    await showInterviewPrompt(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.archive),
            label: 'Archivio',
          ),
        ],
      ),
    );
  }
}
