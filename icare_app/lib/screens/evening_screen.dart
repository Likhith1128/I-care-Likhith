import 'package:flutter/material.dart';

import '../models.dart';
import '../navigation.dart';
import '../prompts.dart';
import '../study_scope.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';
import '../widgets/study_scaffold.dart';

class EveningScreen extends StatefulWidget {
  const EveningScreen({super.key});

  @override
  State<EveningScreen> createState() => _EveningScreenState();
}

class _EveningScreenState extends State<EveningScreen> {
  final List<ReportActivity> _activities = [];
  final Set<String> _syncedBoutIds = {};
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final controller = StudyScope.watch(context).controller;
    final saved = controller.todayReport;
    if (saved != null) {
      _activities.addAll(saved.activities.map(_copyActivity));
      _syncedBoutIds.addAll(saved.syncedBoutIds);
      if (saved.syncedBoutIds.isEmpty) {
        final completed = controller.completedToday;
        final matched = _activities.length < completed.length
            ? _activities.length
            : completed.length;
        for (var index = 0; index < matched; index++) {
          final activity = _activities[index];
          final bout = completed[index];
          activity
            ..sourceBoutId = bout.id
            ..startedAt = bout.startedAt
            ..activity = bout.activity
            ..otherDetail = bout.otherDetail ?? '';
          _syncedBoutIds.add(bout.id);
        }
      }
    }
    for (final bout in controller.completedToday) {
      if (_syncedBoutIds.add(bout.id)) {
        _activities.add(_fromBout(bout));
      }
    }
  }

  ReportActivity _copyActivity(ReportActivity activity) {
    return ReportActivity(
      id: activity.id,
      sourceBoutId: activity.sourceBoutId,
      startedAt: activity.startedAt,
      minutes: activity.minutes,
      activity: activity.activity,
      otherDetail: activity.otherDetail,
    );
  }

  ReportActivity _fromBout(ActivityBout bout) {
    final duration = bout.endedAt?.difference(bout.startedAt).inMinutes ?? 30;
    return ReportActivity(
      id: bout.id,
      sourceBoutId: bout.id,
      startedAt: bout.startedAt,
      minutes: duration.clamp(5, 300),
      activity: bout.activity,
      otherDetail: bout.otherDetail ?? '',
    );
  }

  void _addActivity() {
    if (_activities.length == 12) return;
    setState(() {
      _activities.add(
        ReportActivity(
          id: 'added-${DateTime.now().microsecondsSinceEpoch}',
          startedAt: DateTime.now(),
          minutes: 30,
        ),
      );
    });
  }

  void _removeActivity(int index) {
    setState(() => _activities.removeAt(index));
  }

  void _changeMinutes(int index, int delta) {
    setState(() {
      final activity = _activities[index];
      activity.minutes = (activity.minutes + delta).clamp(5, 300);
    });
  }

  void _changeActivity(int index, ActivityKind? kind) {
    setState(() {
      final activity = _activities[index];
      activity.activity = kind;
      if (kind != ActivityKind.other) activity.otherDetail = '';
    });
  }

  Future<void> _changeStartTime(int index) async {
    final activity = _activities[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(activity.startedAt),
    );
    if (!mounted || picked == null) return;
    setState(() {
      activity.startedAt = DateTime(
        activity.startedAt.year,
        activity.startedAt.month,
        activity.startedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = StudyScope.watch(context).controller;
    final theme = Theme.of(context);

    return StudyScaffold(
      title: 'Evening report',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Around ${formatClock(controller.bedMinutes)}, based on your bedtime.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StudyColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(eveningCountQuestion, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${_activities.length} session${_activities.length == 1 ? '' : 's'} recorded',
                    key: const Key('exercise-count'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  HoldButton(
                    key: const Key('count-plus'),
                    label: 'Add session',
                    icon: Icons.add,
                    style: HoldStyle.secondary,
                    onPressed: _activities.length == 12 ? null : _addActivity,
                  ),
                  HoldButton(
                    key: const Key('count-minus'),
                    label: 'Remove last session',
                    icon: Icons.remove,
                    style: HoldStyle.secondary,
                    onPressed: _activities.isEmpty
                        ? null
                        : () => _removeActivity(_activities.length - 1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total duration: ${_activities.fold<int>(0, (total, activity) => total + activity.minutes)} min',
                    key: const Key('total-duration'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_activities.isEmpty)
                    Text(
                      'No activities recorded today.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: StudyColors.muted,
                      ),
                    ),
                  for (var index = 0; index < _activities.length; index++)
                    _activityEditor(context, index),
                  const SizedBox(height: 8),
                  HoldButton(
                    key: const Key('add-activity'),
                    label: 'Add another activity',
                    icon: Icons.add,
                    style: HoldStyle.secondary,
                    onPressed: _activities.length == 12 ? null : _addActivity,
                  ),
                ],
              ),
            ),
          ),
          HoldButton(
            key: const Key('save-evening'),
            label: 'Save',
            icon: Icons.check,
            waitToRead: true,
            onPressed: () {
              controller.saveDayReport(
                activities: _activities,
                syncedBoutIds: _syncedBoutIds,
              );
              openHome(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _activityEditor(BuildContext context, int index) {
    final activity = _activities[index];
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Container(
      key: Key('activity-row-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Session ${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: Key('remove-activity-$index'),
                tooltip: 'Remove session ${index + 1}',
                onPressed: () => _removeActivity(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          DropdownButtonFormField<ActivityKind>(
            key: Key('activity-type-$index'),
            isExpanded: true,
            initialValue: activity.activity,
            decoration: const InputDecoration(labelText: 'Activity type'),
            items: [
              for (final kind in ActivityKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (kind) => _changeActivity(index, kind),
          ),
          if (activity.activity == ActivityKind.other) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: Key('activity-other-$index'),
              initialValue: activity.otherDetail,
              decoration: const InputDecoration(labelText: 'Activity name'),
              onChanged: (value) => activity.otherDetail = value,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.formatMediumDate(activity.startedAt),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton.icon(
                key: Key('activity-time-$index'),
                onPressed: () => _changeStartTime(index),
                icon: const Icon(Icons.schedule),
                label: Text(
                  formatClock(
                    activity.startedAt.hour * 60 + activity.startedAt.minute,
                  ),
                ),
              ),
            ],
          ),
          Text('Duration', style: theme.textTheme.bodyMedium),
          Text(
            '${activity.minutes} min',
            key: Key('minutes-$index'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          HoldButton(
            key: Key('minutes-plus-$index'),
            label: 'More time',
            icon: Icons.add,
            style: HoldStyle.secondary,
            onPressed: () => _changeMinutes(index, 5),
          ),
          HoldButton(
            key: Key('minutes-minus-$index'),
            label: 'Less time',
            icon: Icons.remove,
            style: HoldStyle.secondary,
            onPressed: () => _changeMinutes(index, -5),
          ),
        ],
      ),
    );
  }
}
