import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo/sileo.dart';

Widget _app() => MaterialApp(
  builder: (context, child) => Toaster(child: child),
  home: const Scaffold(body: SizedBox.expand()),
);

void main() {
  tearDown(() => sileo.clear());

  testWidgets('shows a toast with its title', (tester) async {
    await tester.pumpWidget(_app());
    sileo.success(const SileoOptions(title: 'Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('defaults the title to the capitalised state name', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    sileo.error(const SileoOptions());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('a new default toast replaces the previous one', (tester) async {
    await tester.pumpWidget(_app());
    sileo.success(const SileoOptions(title: 'First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('First'), findsOneWidget);

    sileo.info(const SileoOptions(title: 'Second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('dismiss removes the toast', (tester) async {
    await tester.pumpWidget(_app());
    final id = sileo.success(const SileoOptions(title: 'Bye', duration: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Bye'), findsOneWidget);

    sileo.dismiss(id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Bye'), findsNothing);
  });

  testWidgets('distinct ids stack multiple toasts', (tester) async {
    await tester.pumpWidget(_app());
    sileo.success(const SileoOptions(id: 'a', title: 'Alpha'));
    sileo.error(const SileoOptions(id: 'b', title: 'Bravo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets('a new toast uses the changed position; the existing one stays',
      (tester) async {
    final position = ValueNotifier<SileoPosition>(SileoPosition.topCenter);
    addTearDown(position.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<SileoPosition>(
        valueListenable: position,
        builder: (context, pos, _) => MaterialApp(
          builder: (context, child) => Toaster(position: pos, child: child),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    sileo.success(const SileoOptions(title: 'First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final firstY = tester.getTopLeft(find.text('First')).dy;

    // Change the Toaster's position, then show another toast.
    position.value = SileoPosition.bottomRight;
    await tester.pump();
    sileo.error(const SileoOptions(title: 'Second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // The existing toast stays near the top (it did not jump to the bottom);
    // the new toast appears at the bottom-right.
    expect(tester.getTopLeft(find.text('First')).dy, closeTo(firstY, 1));
    expect(
      tester.getTopLeft(find.text('Second')).dy,
      greaterThan(tester.getTopLeft(find.text('First')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Second')).dx,
      greaterThan(tester.getTopLeft(find.text('First')).dx),
    );

    // Drain the old toast's exit-removal timer.
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('rapid reposition keeps the newest toast visible', (tester) async {
    final position = ValueNotifier<SileoPosition>(SileoPosition.topLeft);
    addTearDown(position.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<SileoPosition>(
        valueListenable: position,
        builder: (context, pos, _) => MaterialApp(
          builder: (context, child) => Toaster(position: pos, child: child),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    Future<void> showAt(SileoPosition pos, String title) async {
      position.value = pos;
      await tester.pump();
      sileo.success(SileoOptions(title: title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Toggle A -> B -> A; the last create reuses the exiting A element by key.
    await showAt(SileoPosition.topLeft, 'One');
    await showAt(SileoPosition.bottomRight, 'Two');
    await showAt(SileoPosition.topLeft, 'Three');

    // Let entry + cross-fade settle, then the newest toast must be visible.
    await tester.pump(const Duration(milliseconds: 700));
    final opacities = tester
        .widgetList<Opacity>(
          find.ancestor(of: find.text('Three'), matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity)
        .toList();
    expect(opacities, isNotEmpty);
    expect(
      opacities.every((o) => o > 0.5),
      isTrue,
      reason: 'newest toast should be visible, opacities: $opacities',
    );

    await tester.pump(const Duration(milliseconds: 700)); // drain exit timers
  });
}
