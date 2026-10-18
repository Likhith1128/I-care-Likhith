enum StudyGroup {
  exerciseGoals('Exercise goals'),
  awareness('Awareness'),
  distraction('Distraction');

  const StudyGroup(this.label);

  final String label;

  static StudyGroup byName(String? name) {
    for (final group in StudyGroup.values) {
      if (group.name == name) return group;
    }
    return StudyGroup.exerciseGoals;
  }
}

enum FontChoice {
  medium('Medium', 1),
  large('Large', 1.15),
  extraLarge('Extra large', 1.35);

  const FontChoice(this.label, this.scale);

  final String label;
  final double scale;

  static FontChoice byName(String? name) {
    for (final choice in FontChoice.values) {
      if (choice.name == name) return choice;
    }
    return FontChoice.large;
  }
}

enum ActivityKind {
  biking('Biking'),
  running('Running'),
  weightTraining('Weight training'),
  swimming('Swimming'),
  other('Other');

  const ActivityKind(this.label);

  final String label;

  static ActivityKind? byName(String? name) {
    for (final kind in ActivityKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

enum Frequency {
  never('Never'),
  seldom('Seldom'),
  sometimes('Sometimes'),
  often('Often'),
  almostAlways('Almost Always');

  const Frequency(this.label);

  final String label;

  static Frequency? byName(String? name) {
    for (final frequency in Frequency.values) {
      if (frequency.name == name) return frequency;
    }
    return null;
  }
}

class ActivityBout {
  ActivityBout({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.activity,
    this.otherDetail,
    this.rating,
  });

  final String id;
  DateTime startedAt;
  DateTime? endedAt;
  ActivityKind? activity;
  String? otherDetail;
  Frequency? rating;

  bool get isOpen => endedAt == null;

  bool get reportComplete {
    if (endedAt == null || activity == null || rating == null) return false;
    if (activity == ActivityKind.other) {
      return otherDetail != null && otherDetail!.trim().isNotEmpty;
    }
    return true;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'activity': activity?.name,
      'otherDetail': otherDetail,
      'rating': rating?.name,
    };
  }

  static ActivityBout? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final started = value['startedAt'];
    if (id is! String || started is! String) return null;
    final startedAt = DateTime.tryParse(started);
    if (startedAt == null) return null;
    final endedRaw = value['endedAt'];
    return ActivityBout(
      id: id,
      startedAt: startedAt,
      endedAt: endedRaw is String ? DateTime.tryParse(endedRaw) : null,
      activity: ActivityKind.byName(value['activity'] as String?),
      otherDetail: value['otherDetail'] as String?,
      rating: Frequency.byName(value['rating'] as String?),
    );
  }
}

class ReportActivity {
  ReportActivity({
    required this.id,
    required this.startedAt,
    required this.minutes,
    this.sourceBoutId,
    this.activity,
    this.otherDetail = '',
  });

  final String id;
  String? sourceBoutId;
  DateTime startedAt;
  int minutes;
  ActivityKind? activity;
  String otherDetail;

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceBoutId': sourceBoutId,
    'startedAt': startedAt.toIso8601String(),
    'minutes': minutes,
    'activity': activity?.name,
    'otherDetail': otherDetail,
  };

  static ReportActivity? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final startedAt = value['startedAt'];
    final minutes = value['minutes'];
    if (id is! String || startedAt is! String || minutes is! num) return null;
    final parsedTime = DateTime.tryParse(startedAt);
    if (parsedTime == null) return null;
    return ReportActivity(
      id: id,
      sourceBoutId: value['sourceBoutId'] as String?,
      startedAt: parsedTime,
      minutes: minutes.toInt(),
      activity: ActivityKind.byName(value['activity'] as String?),
      otherDetail: value['otherDetail'] as String? ?? '',
    );
  }
}

class DayReport {
  const DayReport({required this.activities, required this.syncedBoutIds});

  final List<ReportActivity> activities;
  final Set<String> syncedBoutIds;

  int get count => activities.length;
  List<int> get minutes => [for (final activity in activities) activity.minutes];

  Map<String, Object?> toJson() => {
    'count': count,
    'minutes': minutes,
    'activities': [for (final activity in activities) activity.toJson()],
    'syncedBoutIds': syncedBoutIds.toList(),
  };

  static DayReport? fromJson(Object? value) {
    if (value is! Map) return null;
    final rawActivities = value['activities'];
    final synced = value['syncedBoutIds'];
    final syncedBoutIds = <String>{
      if (synced is List)
        for (final id in synced)
          if (id is String) id,
    };
    if (rawActivities is List) {
      return DayReport(
        activities: [
          for (final item in rawActivities)
            ?ReportActivity.fromJson(item),
        ],
        syncedBoutIds: syncedBoutIds,
      );
    }

    final count = value['count'];
    final minutes = value['minutes'];
    if (count is! num || minutes is! List) return null;
    return DayReport(
      activities: [
        for (var index = 0; index < count.toInt(); index++)
          ReportActivity(
            id: 'legacy-$index',
            startedAt: DateTime.now(),
            minutes: index < minutes.length && minutes[index] is num
                ? (minutes[index] as num).toInt()
                : 30,
          ),
      ],
      syncedBoutIds: syncedBoutIds,
    );
  }
}

String dayKey(DateTime time) {
  final local = time.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String formatClock(int minutesFromMidnight) {
  final bounded = minutesFromMidnight.clamp(0, (24 * 60) - 1);
  final hour24 = bounded ~/ 60;
  final minute = bounded % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}

String formatElapsed(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}
