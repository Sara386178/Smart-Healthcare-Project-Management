import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_healthcare_pm/main.dart';

void main() {
  testWidgets('full record form validates fields and returns typed values', (
    tester,
  ) async {
    Map<String, Object?>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                submitted = await showHealthForm(
                  context,
                  title: 'Add project item',
                  fields: const [
                    HealthFormField(name: 'title', label: 'Title'),
                    HealthFormField(
                      name: 'progress',
                      label: 'Progress',
                      input: HealthFormInput.integer,
                      initial: '101',
                      minimum: 0,
                      maximum: 100,
                    ),
                    HealthFormField(
                      name: 'priority',
                      label: 'Priority',
                      input: HealthFormInput.choice,
                      initial: 'Should have',
                      choices: ['Must have', 'Should have', 'Could have'],
                    ),
                    HealthFormField(
                      name: 'milestone',
                      label: 'Milestone',
                      input: HealthFormInput.toggle,
                    ),
                  ],
                  saveLabel: 'Save record',
                );
              },
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Milestone'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save record'));
    await tester.pumpAndSettle();
    expect(find.text('Title is required.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Cardiology module',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save record'));
    await tester.pumpAndSettle();
    expect(find.text('Enter no more than 100.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '75');
    await tester.tap(find.widgetWithText(FilledButton, 'Save record'));
    await tester.pumpAndSettle();

    expect(submitted, {
      'title': 'Cardiology module',
      'progress': 75,
      'priority': 'Should have',
      'milestone': false,
    });
  });
}
