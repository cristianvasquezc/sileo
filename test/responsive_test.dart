import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo/sileo.dart';
import 'package:sileo/src/constants.dart';
import 'package:sileo/src/sileo_toast.dart';

/// Mirrors the private `_kViewportPadding` in `toaster.dart` (per side).
const double _kViewportPadding = 12;

Widget _app({SileoPosition position = SileoPosition.topRight}) => MaterialApp(
  builder: (context, child) => Toaster(position: position, child: child),
  home: const Scaffold(body: SizedBox.expand()),
);

Future<void> _show(
  WidgetTester tester,
  SileoOptions options, {
  SileoPosition position = SileoPosition.topRight,
}) async {
  await tester.pumpWidget(_app(position: position));
  sileo.success(options);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

double _toastWidth(WidgetTester tester) =>
    tester.getSize(find.byType(SileoToast)).width;

void main() {
  tearDown(() => sileo.clear());

  testWidgets('canvas shrinks to fit a screen narrower than kSileoWidth', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(300, 800);
    addTearDown(tester.view.reset);

    await _show(
      tester,
      const SileoOptions(
        title: 'Saved',
        description:
            'A description long enough that a fixed 350px body would overflow '
            'a 300px-wide device.',
      ),
    );

    expect(tester.takeException(), isNull);
    // screen (300) - _kViewportPadding * 2 (24) = 276, below the 350 cap.
    expect(_toastWidth(tester), closeTo(300 - _kViewportPadding * 2, 0.5));
  });

  testWidgets('canvas keeps the kSileoWidth cap on a wide screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await _show(
      tester,
      const SileoOptions(title: 'Saved', description: 'Short.'),
    );

    expect(tester.takeException(), isNull);
    expect(_toastWidth(tester), closeTo(kSileoWidth, 0.5));
  });

  testWidgets('a long title cannot push the pill past a narrow canvas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(300, 800);
    addTearDown(tester.view.reset);

    await _show(
      tester,
      const SileoOptions(
        title:
            'A very long toast title that on its own is far wider than a narrow '
            'phone screen',
      ),
      position:
          SileoPosition.topLeft, // pillX == 0, so the pill grows rightward
    );

    expect(tester.takeException(), isNull);

    // The collapsed pill is the header's ClipRect (height == kSileoHeight); with
    // the clamp its width can never exceed the canvas (it crops the title).
    final pillWidths = find
        .descendant(
          of: find.byType(SileoToast),
          matching: find.byType(ClipRect),
        )
        .evaluate()
        .map((e) => (e.renderObject! as RenderBox).size)
        .where((s) => (s.height - kSileoHeight).abs() < 0.5)
        .map((s) => s.width);

    expect(pillWidths, isNotEmpty);
    expect(pillWidths.first, lessThanOrEqualTo(_toastWidth(tester) + 0.5));
  });
}
