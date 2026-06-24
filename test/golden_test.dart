import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo/sileo.dart';

Widget _harness({
  required SileoPosition position,
  SileoTheme? theme,
  Color background = const Color(0xFFEDEDED),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: background),
    builder: (context, child) =>
        Toaster(position: position, theme: theme, child: child),
    home: const Scaffold(),
  );
}

Future<void> _settle(WidgetTester tester, {int frames = 130}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() => sileo.clear());

  testWidgets('golden: expanded success (light theme)', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(sileo.clear);

    await tester.pumpWidget(
      _harness(position: SileoPosition.topCenter, theme: SileoTheme.light),
    );
    sileo.success(const SileoOptions(
      title: 'Saved',
      description: 'Your changes are live and synced across all devices.',
    ));
    await _settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/expanded_success_light.png'),
    );
  });

  testWidgets('golden: expanded with action button (dark theme)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(sileo.clear);

    await tester.pumpWidget(
      _harness(
        position: SileoPosition.topCenter,
        theme: SileoTheme.dark,
        background: const Color(0xFF0B0B0B),
      ),
    );
    sileo.action(SileoOptions(
      title: 'Update available',
      description: 'A new version is ready to install.',
      button: SileoButton(title: 'Restart', onPressed: () {}),
    ));
    await _settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/expanded_action_dark.png'),
    );
  });

  testWidgets('golden: all six states as pills', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(sileo.clear);

    await tester.pumpWidget(
      _harness(position: SileoPosition.topLeft, theme: SileoTheme.light),
    );
    sileo.success(const SileoOptions(id: '1', title: 'Success'));
    sileo.error(const SileoOptions(id: '2', title: 'Error'));
    sileo.warning(const SileoOptions(id: '3', title: 'Warning'));
    sileo.info(const SileoOptions(id: '4', title: 'Info'));
    sileo.action(const SileoOptions(id: '5', title: 'Action'));
    sileo.show(const SileoOptions(
      id: '6',
      title: 'Loading',
      type: SileoState.loading,
      duration: null,
    ));
    await _settle(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/states_pills.png'),
    );
  });
}
