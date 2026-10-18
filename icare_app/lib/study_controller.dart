import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StudyController extends ChangeNotifier {
  StudyController(this._prefs) {
    _restore();
  }

  static const storageKey = 'icare_state_v1';

  final SharedPreferences _prefs;

  bool welcomed = false;
  bool authenticated = false;
  String name = '';
  int? age;
  StudyGroup group = StudyGroup.exerciseGoals;
  String exerciseGoal = 'good health';
  int morningMinutes = 7 * 60;
  int bedMinutes = 21 * 60 + 30;
  FontChoice fontChoice = FontChoice.large;
  final List<ActivityBout> bouts = [];
  final Map<String, DayReport> reports = {};
  String? morningSeenOn;

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Enter your name' : trimmed;
  }

  String get goalPhrase {
    var phrase = exerciseGoal.trim();
    if (phrase.isEmpty) return 'good health';
    while (phrase.endsWith('.') || phrase.endsWith('!')) {
      phrase = phrase.substring(0, phrase.length - 1).trim();
    }
    return phrase.isEmpty ? 'good health' : phrase;
  }

  ActivityBout? get activeBout {
    for (final bout in bouts.reversed) {
      if (bout.isOpen) return bout;
    }
    return null;
  }

  ActivityBout? get latestEndedBout {
    for (final bout in bouts.reversed) {
      if (!bout.isOpen) return bout;
    }
    return null;
  }

  List<ActivityBout> get completedToday {
    final today = dayKey(DateTime.now());
    return [
      for (final bout in bouts)
        if (!bout.isOpen && dayKey(bout.startedAt) == today) bout,
    ];
  }

  bool get morningSeenToday => morningSeenOn == dayKey(DateTime.now());

  DayReport? get todayReport => reports[dayKey(DateTime.now())];

  void completeWelcome() {
    welcomed = true;
    _persist();
  }

  void completeAuthentication({
    required String name,
    int? age,
  }) {
    authenticated = true;
    if (name.trim().isNotEmpty) this.name = name.trim();
    if (age != null) this.age = age;
    _persist();
  }

  void logout() {
    authenticated = false;
    _persist();
  }

  void setName(String value) {
    name = value;
    _persist();
  }

  void setGroup(StudyGroup value) {
    group = value;
    _persist();
  }

  void setExerciseGoal(String value) {
    exerciseGoal = value;
    _persist();
  }

  void setMorningMinutes(int value) {
    morningMinutes = value.clamp(0, (24 * 60) - 1);
    _persist();
  }

  void setBedMinutes(int value) {
    bedMinutes = value.clamp(0, (24 * 60) - 1);
    _persist();
  }

  void setFont(FontChoice value) {
    fontChoice = value;
    _persist();
  }

  void acknowledgeMorning() {
    morningSeenOn = dayKey(DateTime.now());
    _persist();
  }

  ActivityBout startBout() {
    final existing = activeBout;
    if (existing != null) return existing;
    final bout = ActivityBout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
    );
    bouts.add(bout);
    _persist();
    return bout;
  }

  void finishBout() {
    final bout = activeBout;
    if (bout == null) return;
    bout.endedAt = DateTime.now();
    _persist();
  }

  void saveActivityReport({
    required ActivityKind activity,
    required String otherDetail,
    required Frequency rating,
  }) {
    final bout = latestEndedBout;
    if (bout == null) return;
    bout.activity = activity;
    bout.otherDetail = otherDetail.trim();
    bout.rating = rating;
    _persist();
  }

  void saveDayReport({
    required List<ReportActivity> activities,
    required Set<String> syncedBoutIds,
  }) {
    final savedActivities = activities.take(12).toList();
    final synced = {...syncedBoutIds};
    for (final activity in savedActivities) {
      activity.minutes = activity.minutes.clamp(5, 300);
      final id = activity.sourceBoutId ?? activity.id;
      final boutIndex = bouts.indexWhere((bout) => bout.id == id);
      final endedAt = activity.startedAt.add(
        Duration(minutes: activity.minutes),
      );
      if (boutIndex >= 0) {
        final bout = bouts[boutIndex];
        bout.startedAt = activity.startedAt;
        bout.endedAt = endedAt;
        bout.activity = activity.activity;
        bout.otherDetail = activity.otherDetail.trim();
      } else {
        bouts.add(
          ActivityBout(
            id: id,
            startedAt: activity.startedAt,
            endedAt: endedAt,
            activity: activity.activity,
            otherDetail: activity.otherDetail.trim(),
          ),
        );
      }
      activity.sourceBoutId = id;
      synced.add(id);
    }
    reports[dayKey(DateTime.now())] = DayReport(
      activities: savedActivities,
      syncedBoutIds: synced,
    );
    _persist();
  }

  void _restore() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      welcomed = decoded['welcomed'] == true;
      authenticated = decoded['authenticated'] == true;
        final storedAge = decoded['age'];
        if (storedAge is num) age = storedAge.toInt();
        final legacyEmail = decoded['email'];
        final legacyPhone = decoded['phoneNumber'];
        final hasLegacyContact =
          (legacyEmail is String && legacyEmail.isNotEmpty) ||
          (legacyPhone is String && legacyPhone.isNotEmpty);
      final storedName = decoded['name'];
      if (storedName is String &&
          !(storedName == 'Jane Smith' && !hasLegacyContact)) {
        name = storedName;
      }
      group = StudyGroup.byName(decoded['group'] as String?);
      final storedGoal = decoded['exerciseGoal'];
      if (storedGoal is String) exerciseGoal = storedGoal;
      morningMinutes = _asInt(decoded['morningMinutes']) ?? morningMinutes;
      bedMinutes = _asInt(decoded['bedMinutes']) ?? bedMinutes;
      fontChoice = FontChoice.byName(decoded['fontChoice'] as String?);
      final seen = decoded['morningSeenOn'];
      morningSeenOn = seen is String ? seen : null;

      bouts
        ..clear()
        ..addAll([
          for (final item in _asList(decoded['bouts']))
            ?ActivityBout.fromJson(item),
        ]);

      reports.clear();
      final storedReports = decoded['reports'];
      if (storedReports is Map) {
        for (final entry in storedReports.entries) {
          final report = DayReport.fromJson(entry.value);
          if (report != null) reports[entry.key.toString()] = report;
        }
      }
    } on FormatException {
      // Keep the defaults when the saved blob is not valid JSON.
    }
  }

  void _persist() {
    _prefs.setString(
      storageKey,
      jsonEncode({
        'welcomed': welcomed,
        'authenticated': authenticated,
        'name': name,
        'age': age,
        'group': group.name,
        'exerciseGoal': exerciseGoal,
        'morningMinutes': morningMinutes,
        'bedMinutes': bedMinutes,
        'fontChoice': fontChoice.name,
        'morningSeenOn': morningSeenOn,
        'bouts': [for (final bout in bouts) bout.toJson()],
        'reports': {
          for (final entry in reports.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
    notifyListeners();
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;

  static List<Object?> _asList(Object? value) {
    if (value is! List) return const [];
    return value;
  }
}
