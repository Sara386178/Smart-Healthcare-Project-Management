import 'package:flutter_test/flutter_test.dart';
import 'package:smart_healthcare_pm/database.dart';
import 'package:smart_healthcare_pm/project_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectDatabase database;

  setUp(() async {
    database = await ProjectDatabase.openInMemoryForTest();
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds the five-hospital case with baseline records', () async {
    final project = await database.project();
    expect(project['budget'], 5000000);
    expect(project['deadline'], '2026-11-23');
    expect((await database.rows('requirements')).length, 8);
    expect((await database.rows('activities')).length, 8);
    expect((await database.rows('changes')).length, 1);
    expect((await database.rows('defects')).length, 3);
    expect((await database.rows('risks')).length, 3);
    expect((await database.rows('checklist')).length, 5);
  });

  test(
    'computes the case-study PV, EV, AC, CPI, and SPI from saved activities',
    () async {
      final activities = await database.rows('activities');
      final metrics = EarnedValueMetrics.calculate(
        activities,
        asOf: DateTime(2026, 10, 25),
      );

      expect(metrics.plannedValue, closeTo(4080175.4385964912, 0.01));
      expect(metrics.earnedValue, closeTo(3063400, 0.01));
      expect(metrics.actualCost, closeTo(3600000, 0.01));
      expect(metrics.cpi, closeTo(0.850944, 0.000001));
      expect(metrics.spi, closeTo(0.750801049146493, 0.000001));
    },
  );

  test('propagates forecast delay through predecessor relationships', () async {
    final activities = await database.rows('activities');
    final forecast = forecastActivities(
      activities,
      asOf: DateTime(2026, 10, 25),
    );
    final handover = activities.singleWhere((row) => row['code'] == '3.2');
    final plannedFinish = DateTime.parse(
      handover['start_date'] as String,
    ).add(Duration(days: handover['duration'] as int));

    expect(forecast['3.1']!.finish.isAfter(DateTime(2026, 11, 8)), isTrue);
    expect(forecast['3.2']!.start.isAfter(plannedFinish), isTrue);
    expect(forecast['3.2']!.finish.isAfter(plannedFinish), isTrue);
  });

  test(
    'schedule forecasts ignore row order and schedule rows are editable',
    () async {
      final activities = await database.rows('activities');
      final forecast = forecastActivities(
        activities.reversed.toList(),
        asOf: DateTime(2026, 10, 25),
      );
      expect(forecast['3.2']!.finish, DateTime.utc(2026, 12, 16));
      final localDateForecast = forecastActivities(
        activities,
        asOf: DateTime(2026, 10, 25),
      );
      expect(localDateForecast['3.2']!.finish, forecast['3.2']!.finish);

      final architecture = activities.singleWhere(
        (row) => row['code'] == '1.2',
      );
      await database.updateActivityPlan(
        id: architecture['id'] as int,
        name: 'Architecture and database design',
        owner: 'Database developer',
        startDate: '2026-08-13',
        duration: 14,
        cost: 540000,
        dependency: '1.1',
        milestone: true,
      );
      final updated = (await database.rows(
        'activities',
      )).singleWhere((row) => row['code'] == '1.2');
      expect(updated['name'], 'Architecture and database design');
      expect(updated['duration'], 14);
      expect(updated['cost'], 540000);
      expect(updated['milestone'], 1);

      await expectLater(
        database.updateActivityPlan(
          id: architecture['id'] as int,
          name: 'Architecture and database design',
          owner: 'Database developer',
          startDate: '2026-08-13',
          duration: 14,
          cost: 540000,
          dependency: '3.2',
          milestone: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'blocks linked requirements until CR-001 is approved, then rebaselines atomically',
    () async {
      final requirements = await database.rows('requirements');
      final ai = requirements.firstWhere(
        (row) => row['title'] == 'AI preliminary diagnosis',
      );

      await expectLater(
        database.setRequirement(ai['id'] as int, 'Approved'),
        throwsA(isA<StateError>()),
      );
      expect(
        (await database.rows(
          'requirements',
        )).firstWhere((row) => row['id'] == ai['id'])['status'],
        'Pending',
      );

      final change = (await database.rows('changes')).single;
      await database.decideChange(change['id'] as int, true);

      final project = await database.project();
      expect(project['budget'], 5800000);
      expect(project['deadline'], '2026-12-14');
      expect(
        (await database.rows('requirements'))
            .where((row) => row['source'] == 'Change request CR-001')
            .every((row) => row['status'] == 'Approved'),
        isTrue,
      );
      final changeWork = (await database.rows(
        'activities',
      )).singleWhere((row) => row['code'] == '4.1');
      expect(changeWork['duration'], 21);
      expect(changeWork['cost'], 800000);
      expect(changeWork['dependency'], '3.1');
    },
  );

  test('rejecting a change leaves the approved baseline unchanged', () async {
    final before = await database.project();
    final change = (await database.rows('changes')).single;
    await database.decideChange(change['id'] as int, false);

    final after = await database.project();
    expect(after['budget'], before['budget']);
    expect(after['deadline'], before['deadline']);
    expect((await database.rows('activities')).length, 8);
    expect(
      (await database.rows('requirements'))
          .where((row) => row['source'] == 'Change request CR-001')
          .every((row) => row['status'] == 'Pending'),
      isTrue,
    );
  });

  test(
    'approving a later request creates its own WBS package and rebaseline',
    () async {
      await database.addChange(
        'Integration monitoring',
        'Sponsor request',
        100000,
        5,
      );
      final changes = await database.rows('changes');
      final added = changes.last;
      expect(added['title'], 'CR-002 · Integration monitoring');

      await database.decideChange(added['id'] as int, true);
      final project = await database.project();
      expect(project['budget'], 5100000);
      expect(project['deadline'], '2026-11-28');
      final package = (await database.rows(
        'activities',
      )).singleWhere((row) => row['code'] == '4.1');
      expect(package['name'], 'Integration monitoring');
      expect(package['cost'], 100000);
      expect(package['duration'], 5);
    },
  );

  test(
    'requirements remain pending until approved and can be updated',
    () async {
      await database.addRequirement(
        'Audit export',
        'Download project audit log.',
        'Must have',
      );
      var requirements = await database.rows('requirements');
      var added = requirements.last;
      expect(added['status'], 'Pending');
      await database.updateRequirement(
        added['id'] as int,
        'Audit export and review',
        'Export and review project audit log.',
        'Should have',
      );
      await database.setRequirement(added['id'] as int, 'Approved');
      requirements = await database.rows('requirements');
      added = requirements.last;
      expect(added['title'], 'Audit export and review');
      expect(added['priority'], 'Should have');
      expect(added['status'], 'Approved');
      await expectLater(
        database.addRequirement(' ', 'Description', 'Must have'),
        throwsArgumentError,
      );
    },
  );

  test(
    'rejects invalid progress, cost, dates, and unknown predecessors',
    () async {
      final activity = (await database.rows('activities')).first;
      await expectLater(
        database.updateActivity(activity['id'] as int, 1.01, 100),
        throwsArgumentError,
      );
      await expectLater(
        database.updateActivity(activity['id'] as int, 0.5, -1),
        throwsArgumentError,
      );
      await expectLater(
        database.addActivity(
          name: 'Invalid predecessor task',
          owner: 'QA engineer',
          startDate: '2026-10-25',
          duration: 5,
          cost: 1000,
          dependency: 'MISSING-99',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('MISSING-99'),
          ),
        ),
      );
      await expectLater(
        database.addActivity(
          name: 'Invalid date task',
          owner: 'QA engineer',
          startDate: 'not-a-date',
          duration: 5,
          cost: 1000,
        ),
        throwsArgumentError,
      );
      expect((await database.rows('activities')).length, 8);

      await database.addActivity(
        name: 'Sponsor sign-off checkpoint',
        owner: 'Project manager',
        startDate: '2026-11-24',
        duration: 1,
        cost: 0,
        dependency: '3.2',
        milestone: true,
      );
      final added = (await database.rows('activities')).last;
      expect(added['dependency'], '3.2');
      expect(added['milestone'], 1);
      expect((await database.rows('activities')).length, 9);
    },
  );

  test(
    'updates charter status and rejects blank or unknown status values',
    () async {
      final initial = await database.project();
      await database.updateCharter(
        objective: initial['objective'] as String,
        stakeholders: initial['stakeholders'] as String,
        scope: initial['scope'] as String,
        status: 'On track',
      );
      expect((await database.project())['status'], 'On track');

      await expectLater(
        database.updateCharter(
          objective: '',
          stakeholders: initial['stakeholders'] as String,
          scope: initial['scope'] as String,
          status: 'On track',
        ),
        throwsArgumentError,
      );
      await expectLater(
        database.updateCharter(
          objective: initial['objective'] as String,
          stakeholders: initial['stakeholders'] as String,
          scope: initial['scope'] as String,
          status: 'Unknown status',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'validates risk scores, defect severity, and checklist inspection results',
    () async {
      await database.addRisk(
        'Delayed pilot sign-off',
        3,
        4,
        'Book early stakeholder reviews.',
        'Project manager',
      );
      expect((await database.rows('risks')).last['likelihood'], 3);
      await expectLater(
        database.addRisk('Invalid', 6, 2, 'Response', 'Owner'),
        throwsArgumentError,
      );
      await expectLater(
        database.addDefect('Invalid severity', 'Severe', 'QA engineer'),
        throwsArgumentError,
      );

      final check = (await database.rows('checklist')).first;
      await database.updateChecklist(check['id'] as int, 'In progress');
      expect((await database.rows('checklist')).first['result'], 'In progress');
      await expectLater(
        database.updateChecklist(check['id'] as int, 'Unknown result'),
        throwsArgumentError,
      );
    },
  );

  test('risk, defect, and checklist records are fully editable', () async {
    final risk = (await database.rows('risks')).first;
    await database.updateRisk(
      id: risk['id'] as int,
      title: 'Updated risk description',
      likelihood: 4,
      impact: 5,
      response: 'Mitigate with a tested fallback workflow.',
      owner: 'Clinical operations lead',
      status: 'Monitoring',
    );
    await database.setRiskStatus(risk['id'] as int, 'Closed');

    final defect = (await database.rows('defects')).first;
    await database.updateDefectDetails(
      id: defect['id'] as int,
      title: 'Updated defect description',
      severity: 'Medium',
      assignee: 'Integration engineer',
      status: 'Resolved',
      reported: '2026-10-20',
    );

    final checklist = (await database.rows('checklist')).first;
    await database.updateChecklistDetails(
      id: checklist['id'] as int,
      item: 'Updated inspection item',
      deliverable: 'Updated deliverable',
      result: 'Pass',
      inspector: 'Quality lead',
    );

    final updatedRisk = (await database.rows(
      'risks',
    )).firstWhere((row) => row['id'] == risk['id']);
    expect(updatedRisk['title'], 'Updated risk description');
    expect(updatedRisk['likelihood'], 4);
    expect(updatedRisk['impact'], 5);
    expect(
      updatedRisk['response'],
      'Mitigate with a tested fallback workflow.',
    );
    expect(updatedRisk['owner'], 'Clinical operations lead');
    expect(updatedRisk['status'], 'Closed');

    final updatedDefect = (await database.rows(
      'defects',
    )).firstWhere((row) => row['id'] == defect['id']);
    expect(updatedDefect['title'], 'Updated defect description');
    expect(updatedDefect['severity'], 'Medium');
    expect(updatedDefect['assignee'], 'Integration engineer');
    expect(updatedDefect['status'], 'Resolved');
    expect(updatedDefect['reported'], '2026-10-20');

    final updatedChecklist = (await database.rows(
      'checklist',
    )).firstWhere((row) => row['id'] == checklist['id']);
    expect(updatedChecklist['item'], 'Updated inspection item');
    expect(updatedChecklist['deliverable'], 'Updated deliverable');
    expect(updatedChecklist['result'], 'Pass');
    expect(updatedChecklist['inspector'], 'Quality lead');
  });

  test(
    'closeout is blocked until pending changes and critical defects are cleared',
    () async {
      await expectLater(
        database.recordClosure('Project complete', 'Sponsor'),
        throwsA(isA<StateError>()),
      );
      expect((await database.rows('closure_records')), isEmpty);
      expect((await database.project())['status'], 'At risk');

      final change = (await database.rows('changes')).single;
      await database.decideChange(change['id'] as int, false);
      final defects = await database.rows('defects');
      for (final defect in defects.where(
        (row) => row['severity'] == 'Critical',
      )) {
        await database.updateDefect(defect['id'] as int, 'Resolved');
      }
      await database.recordClosure('Project complete', 'Sponsor');

      expect((await database.project())['status'], 'Closed');
      expect(
        (await database.rows('closure_records')).single['approved_by'],
        'Sponsor',
      );
    },
  );
}
