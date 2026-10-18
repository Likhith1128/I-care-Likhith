import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icare_app/app.dart';
import 'package:icare_app/models.dart';
import 'package:icare_app/prompts.dart';
import 'package:icare_app/study_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StudyController> startApp(
  WidgetTester tester, {
  bool welcomed = false,
  bool authenticated = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    StudyController.storageKey:
        '{"welcomed":$welcomed,"authenticated":$authenticated}',
  });
  final preferences = await SharedPreferences.getInstance();
  final controller = StudyController(preferences);
  await tester.pumpWidget(ICareApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> holdTap(WidgetTester tester, Finder finder) async {
  final scrollable = find.ancestor(
    of: finder,
    matching: find.byType(Scrollable),
  );
  if (scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable.first);
  }
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  test('legacy demo name is replaced with the enter-name prompt', () async {
    SharedPreferences.setMockInitialValues({
      StudyController.storageKey:
          '{"name":"Jane Smith","welcomed":true,"authenticated":true}',
    });
    final controller = StudyController(await SharedPreferences.getInstance());

    expect(controller.name, isEmpty);
    expect(controller.displayName, 'Enter your name');
    controller.dispose();
  });

  testWidgets('sign-up form validates details and opens the study welcome', (
    tester,
  ) async {
    final controller = await startApp(tester, authenticated: false);

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byKey(const Key('auth-name')), findsOneWidget);
    expect(find.byKey(const Key('auth-age')), findsOneWidget);
    expect(find.byKey(const Key('auth-email')), findsNothing);
    expect(find.byKey(const Key('auth-phone')), findsNothing);
    expect(find.textContaining('Demo only'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid age'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-name')), 'Alex Morgan');
    await tester.enterText(find.byKey(const Key('auth-age')), '35');
    await tester.enterText(find.byKey(const Key('auth-password')), 'study1234');
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'study1234',
    );
    await holdTap(tester, find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(controller.authenticated, isTrue);
    expect(controller.displayName, 'Alex Morgan');
    expect(controller.age, 35);
    expect(find.text('Welcome to the study'), findsOneWidget);
  });

  testWidgets('sign-in mode shows name and password fields', (tester) async {
    await startApp(tester, authenticated: false);

    await holdTap(tester, find.byKey(const Key('auth-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  expect(find.byKey(const Key('auth-name')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
  expect(find.byKey(const Key('auth-age')), findsNothing);
  expect(find.byKey(const Key('auth-email')), findsNothing);
    expect(find.byKey(const Key('auth-phone')), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('welcome explains the study and opens home', (tester) async {
    await startApp(tester);

    expect(find.text(welcomeMessage), findsOneWidget);
    expect(find.text('Welcome to the study'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('welcome-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Activity history'), findsOneWidget);
    expect(find.textContaining('Morning'), findsWidgets);
    expect(find.textContaining('Evening'), findsWidgets);

    final begin = tester.getRect(find.byKey(const Key('home-begin')));
    expect(begin.left, greaterThanOrEqualTo(24));
    expect(begin.right, lessThanOrEqualTo(390 - 24));
    expect(begin.height, greaterThanOrEqualTo(72));
  });

  testWidgets('home logout returns to account screen', (tester) async {
    final controller = await startApp(tester, welcomed: true);

    expect(find.text('Home'), findsOneWidget);
    await holdTap(tester, find.byKey(const Key('home-logout')));
    await tester.pumpAndSettle();

    expect(controller.authenticated, isFalse);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('each study group shows its own morning prompt', (tester) async {
    final controller = await startApp(tester, welcomed: true);

    Future<void> expectMorning(StudyGroup group, String snippet) async {
      controller.setGroup(group);
      await holdTap(tester, find.byKey(const Key('home-morning')));
      await tester.pumpAndSettle();
      expect(find.textContaining(snippet), findsOneWidget);
      await holdTap(tester, find.byKey(const Key('prompt-got-it')));
      await tester.pumpAndSettle();
      expect(find.text('Morning message opened today'), findsOneWidget);
    }

    await expectMorning(StudyGroup.exerciseGoals, 'good health');
    await expectMorning(
      StudyGroup.awareness,
      'positive feelings during the physical activity',
    );
    await expectMorning(StudyGroup.distraction, 'enjoyable topic');
  });

  testWidgets('activity history lists completed activities for today', (
    tester,
  ) async {
    final controller = await startApp(tester, welcomed: true);
    final bout = controller.startBout();
    controller.finishBout();
    controller.saveActivityReport(
      activity: ActivityKind.running,
      otherDetail: '',
      rating: Frequency.often,
    );

    await holdTap(tester, find.byKey(const Key('home-activity-history')));
    await tester.pumpAndSettle();

    expect(find.text('Activity history'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Frequency: Often'), findsOneWidget);
    expect(find.text('Under 1 min'), findsOneWidget);
    expect(find.byKey(const Key('activity-history-item-0')), findsOneWidget);
    expect(bout.reportComplete, isTrue);
  });

  testWidgets('activity history shows an empty state when there are no logs', (
    tester,
  ) async {
    await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-activity-history')));
    await tester.pumpAndSettle();

    expect(find.text('No activities logged today'), findsOneWidget);
    expect(find.text('Completed activities will appear here.'), findsOneWidget);
  });

  testWidgets('activity flow records the bout and the group question', (
    tester,
  ) async {
    final controller = await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-begin')));
    await tester.pumpAndSettle();
    expect(find.text('Are you beginning physical activity?'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('begin-yes')));
    await tester.pumpAndSettle();
    expect(find.text(watchCue), findsOneWidget);
    expect(find.textContaining('good health'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('during-got-it')));
    await tester.pump();
    expect(find.text('End'), findsOneWidget);
    expect(find.byKey(const Key('elapsed-time')), findsOneWidget);
    expect(find.text('Heart rate'), findsOneWidget);
    expect(find.text('BPM'), findsOneWidget);
    expect(find.textContaining('Demo data'), findsOneWidget);
    final initialHeartRate = tester.widget<Text>(
      find.byKey(const Key('heart-rate-value')),
    );
    final initialBpm = int.parse(initialHeartRate.data!);
    expect(initialBpm, inInclusiveRange(60, 110));
    await tester.pump(const Duration(seconds: 8));
    final updatedHeartRate = tester.widget<Text>(
      find.byKey(const Key('heart-rate-value')),
    );
    expect(int.parse(updatedHeartRate.data!), isNot(initialBpm));

    await holdTap(tester, find.byKey(const Key('end-bout')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Would you like to end your exercise?'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('end-yes')));
    await tester.pumpAndSettle();
    expect(find.text(activityQuestion), findsOneWidget);
    expect(find.textContaining('🚴'), findsOneWidget);
    expect(find.textContaining('🏃'), findsOneWidget);
    expect(find.textContaining('💭'), findsOneWidget);
    expect(
      find.textContaining('think about your exercise goal'),
      findsOneWidget,
    );

    await holdTap(tester, find.byKey(const Key('activity-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('other-detail')), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('activity-running')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('other-detail')), findsNothing);

    await holdTap(tester, find.byKey(const Key('rating-often')));
    await tester.pumpAndSettle();
    await holdTap(tester, find.byKey(const Key('save-report')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(controller.completedToday, hasLength(1));
    expect(controller.completedToday.single.activity, ActivityKind.running);
    expect(controller.completedToday.single.rating, Frequency.often);
    expect(controller.completedToday.single.reportComplete, isTrue);
  });

  testWidgets('evening report uses the selected activity name', (
    tester,
  ) async {
    final controller = await startApp(tester, welcomed: true);
    controller.bouts.add(
      ActivityBout(
        id: 'running-bout',
        startedAt: DateTime.now().subtract(const Duration(minutes: 35)),
        endedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        activity: ActivityKind.running,
      ),
    );

    await holdTap(tester, find.byKey(const Key('home-evening')));
    await tester.pumpAndSettle();
    expect(find.text(eveningCountQuestion), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('1 session recorded'), findsOneWidget);
  });

  testWidgets('evening report edits logged activities without duplicating', (
    tester,
  ) async {
    final controller = await startApp(tester, welcomed: true);
    final startedAt = DateTime.now().subtract(const Duration(minutes: 40));
    final bout = ActivityBout(
      id: 'logged-bout',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 30)),
      activity: ActivityKind.running,
    );
    controller.bouts.add(bout);

    await holdTap(tester, find.byKey(const Key('home-evening')));
    await tester.pumpAndSettle();
    expect(find.text('1 session recorded'), findsOneWidget);
    expect(find.byKey(const Key('activity-row-0')), findsOneWidget);
    expect(controller.completedToday, hasLength(1));

    await holdTap(tester, find.byKey(const Key('activity-type-0')));
    await tester.pumpAndSettle();
    await holdTap(tester, find.text('Biking').last);
    await tester.pumpAndSettle();
    await holdTap(tester, find.byKey(const Key('minutes-plus-0')));
    await tester.pumpAndSettle();
    expect(find.text('35 min'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('activity-time-0')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await holdTap(tester, find.text('Cancel'));
    await tester.pumpAndSettle();

    await holdTap(tester, find.byKey(const Key('save-evening')));
    await tester.pumpAndSettle();
    expect(controller.bouts, hasLength(1));
    expect(controller.todayReport?.count, 1);
    expect(controller.todayReport?.minutes, [35]);
    expect(bout.activity, ActivityKind.biking);
    expect(bout.endedAt?.difference(bout.startedAt).inMinutes, 35);
  });

  testWidgets('evening report asks for count and duration', (tester) async {
    final controller = await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-evening')));
    await tester.pumpAndSettle();
    expect(find.text(eveningCountQuestion), findsOneWidget);
    expect(find.text('0 sessions recorded'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('count-plus')));
    await tester.pumpAndSettle();
    expect(find.text('1 session recorded'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('minutes-plus-0')));
    await tester.pumpAndSettle();
    expect(find.text('35 min'), findsOneWidget);

    await holdTap(tester, find.byKey(const Key('save-evening')));
    await tester.pumpAndSettle();
    expect(find.text('Evening report saved'), findsOneWidget);
    expect(controller.todayReport?.count, 1);
    expect(controller.todayReport?.minutes, [35]);
  });

  testWidgets('font size setting scales text and is remembered', (
    tester,
  ) async {
    await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-settings')));
    await tester.pumpAndSettle();
    await holdTap(tester, find.byKey(const Key('font-extraLarge')));
    await tester.pumpAndSettle();

    final scale = MediaQuery.textScalerOf(
      tester.element(find.text('Font size')),
    ).scale(1);
    expect(scale, closeTo(1.35, 0.01));

    final restored = StudyController(await SharedPreferences.getInstance());
    expect(restored.fontChoice, FontChoice.extraLarge);
    expect(restored.welcomed, isTrue);
  });

  testWidgets('time picker opens in compact numeric entry mode', (
    tester,
  ) async {
    await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    await holdTap(tester, find.byKey(const Key('morning-time')));
    await tester.pumpAndSettle();

    expect(find.text('Enter time'), findsOneWidget);
    expect(find.text('Hour'), findsOneWidget);
    expect(find.text('Minute'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('home leaves a prompt without marking it read', (tester) async {
    final controller = await startApp(tester, welcomed: true);

    await holdTap(tester, find.byKey(const Key('home-morning')));
    await tester.pumpAndSettle();
    await holdTap(tester, find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Morning message not opened yet'), findsOneWidget);
    expect(controller.morningSeenToday, isFalse);
  });
}
