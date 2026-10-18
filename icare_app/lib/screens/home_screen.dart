import 'package:flutter/material.dart';

import '../models.dart';
import '../study_scope.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.watch(context).controller;
    final inProgress = controller.activeBout != null;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Home', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      key: const Key('home-logout'),
                      tooltip: 'Log out',
                      onPressed: () {
                        controller.logout();
                        Navigator.of(context).pushReplacementNamed('/auth');
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  controller.displayName,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.morningSeenToday
                      ? 'Morning message opened today'
                      : 'Morning message not opened yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: StudyColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.todayReport == null
                      ? 'Evening report not saved yet'
                      : 'Evening report saved',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: StudyColors.muted,
                  ),
                ),
                if (controller.completedToday.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Completed today: ${controller.completedToday.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StudyColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (inProgress) ...[
                  const _ProgressCard(),
                  const SizedBox(height: 20),
                ],
                _HomeTile(
                  key: const Key('home-begin'),
                  label: inProgress ? 'Resume' : 'Begin',
                  icon: inProgress ? Icons.replay : Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(inProgress ? '/active' : '/begin');
                  },
                ),
                const SizedBox(height: 20),
                _HomeTile(
                  key: const Key('home-settings'),
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                ),
                const SizedBox(height: 20),
                _HomeTile(
                  key: const Key('home-activity-history'),
                  label: 'Activity history',
                  icon: Icons.history,
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/activity-history'),
                ),
                const SizedBox(height: 20),
                _HomeTile(
                  key: const Key('home-morning'),
                  label: 'Morning',
                  detail: formatClock(controller.morningMinutes),
                  icon: Icons.wb_sunny_outlined,
                  onPressed: () => Navigator.of(context).pushNamed('/morning'),
                ),
                const SizedBox(height: 20),
                _HomeTile(
                  key: const Key('home-evening'),
                  label: 'Evening',
                  detail: formatClock(controller.bedMinutes),
                  icon: Icons.nightlight_outlined,
                  onPressed: () => Navigator.of(context).pushNamed('/evening'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE5F2EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudyColors.green, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Exercise in progress',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.detail,
  });

  final String label;
  final String? detail;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoldButton(
      label: detail == null ? label : '$label · $detail',
      icon: icon,
      style: label == 'Begin' || label == 'Resume'
          ? HoldStyle.primary
          : HoldStyle.secondary,
      onPressed: onPressed,
    );
  }
}
