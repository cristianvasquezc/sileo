import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo/sileo.dart';

Widget _app() => MaterialApp(
  builder: (context, child) => Toaster(child: child),
  home: const Scaffold(body: SizedBox.expand()),
);

Future<void> _settle(WidgetTester tester, {int frames = 120}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

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

  testWidgets('tapping a toast reveals then hides its description', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    // A zero duration persists the toast and disables autopilot, so it stays
    // collapsed until the user interacts — isolating the tap behaviour.
    sileo.info(
      const SileoOptions(
        title: 'Update',
        description: 'Version 2.0 is now available.',
        duration: Duration.zero,
      ),
    );
    await _settle(tester);

    final desc = find.text('Version 2.0 is now available.');
    // The body is always in the tree; collapsed just means faded out.
    expect(desc, findsOneWidget);

    // Combined opacity of the body along its ancestor chain — the entry fade
    // times the open fade. Near 0 while collapsed, near 1 while open.
    double bodyOpacity() => tester
        .widgetList<Opacity>(
          find.ancestor(of: desc, matching: find.byType(Opacity)),
        )
        .fold<double>(1, (acc, o) => acc * o.opacity);

    expect(bodyOpacity(), lessThan(0.5), reason: 'starts collapsed');

    // Tap the visible pill (its title) to open it.
    await tester.tap(find.text('Update'), warnIfMissed: false);
    await _settle(tester);
    expect(bodyOpacity(), greaterThan(0.5), reason: 'tap reveals the body');

    // Tap again to collapse.
    await tester.tap(find.text('Update'), warnIfMissed: false);
    await _settle(tester);
    expect(bodyOpacity(), lessThan(0.5), reason: 'a second tap hides it');
  });

  testWidgets('tapping restarts the dismiss timer but never pauses it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    // Autopilot off so nothing auto-expands; a 2s duration gives a live dismiss
    // timer. Title matches the per-word capitalisation the toast renders.
    sileo.info(
      const SileoOptions(
        title: 'Heads Up',
        description: 'Something you should read.',
        duration: Duration(seconds: 2),
        autopilot: SileoAutopilot.disabled(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Let 1.5s pass (the original 2s timer has not fired), then tap — this
    // cancels it and starts a fresh 2s countdown from now.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('Heads Up'), warnIfMissed: false);
    await tester.pump();

    // 1.5s past the tap: within the fresh window, still on screen — where the
    // ORIGINAL timer would already have dismissed it (3.0s elapsed > 2s).
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      find.text('Heads Up'),
      findsOneWidget,
      reason: 'the tap restarted the countdown',
    );

    // Past the fresh window: it dismisses on its own — the tap did not pause it.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 700)); // exit animation
    expect(
      find.text('Heads Up'),
      findsNothing,
      reason: 'tapping does not pause auto-dismiss',
    );
  });

  testWidgets('tapping the action button fires it without collapsing', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    var pressed = false;
    sileo.action(
      SileoOptions(
        title: 'File Uploaded',
        description: 'Share it with your team?',
        duration: Duration.zero,
        button: SileoButton(
          title: 'Share Now',
          onPressed: () => pressed = true,
        ),
      ),
    );
    await _settle(tester);

    // Open the toast so the button is on screen.
    await tester.tap(find.text('File Uploaded'), warnIfMissed: false);
    await _settle(tester);

    final desc = find.text('Share it with your team?');
    double bodyOpacity() => tester
        .widgetList<Opacity>(
          find.ancestor(of: desc, matching: find.byType(Opacity)),
        )
        .fold<double>(1, (acc, o) => acc * o.opacity);
    expect(bodyOpacity(), greaterThan(0.5), reason: 'opened');

    // Tapping the button fires it — the inner gesture wins the arena, so the
    // tap does not bubble up and collapse the toast.
    await tester.tap(find.text('Share Now'), warnIfMissed: false);
    await _settle(tester);
    expect(pressed, isTrue, reason: 'button pressed');
    expect(bodyOpacity(), greaterThan(0.5), reason: 'toast stayed open');
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

  testWidgets('a new toast uses the changed position; the existing one stays', (
    tester,
  ) async {
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

  testWidgets('rapid reposition keeps the newest toast visible', (
    tester,
  ) async {
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
