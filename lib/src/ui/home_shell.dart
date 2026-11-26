import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../state/diary_controller.dart';
import 'add_food_flow.dart';
import 'history_screen.dart';
import 'plan_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

/// Top-level navigation: today's diary, the day plan, and history, with a
/// single prominent "add food" action shared by all three.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [TodayScreen(), PlanScreen(), HistoryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Lens'),
        actions: [
          IconButton(
            tooltip: 'Innstillinger',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFood(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(_index == 1 ? 'Planlegg' : 'Legg til'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'I dag',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Historikk',
          ),
        ],
      ),
    );
  }

  Future<void> _addFood(BuildContext context) async {
    // The plan tab adds planned items; everywhere else adds eaten ones.
    final status = _index == 1 ? EntryStatus.planned : EntryStatus.eaten;
    final controller = context.read<DiaryController>();
    await showAddFoodFlow(context, controller: controller, status: status);
  }
}
