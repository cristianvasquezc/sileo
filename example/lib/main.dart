import 'package:flutter/material.dart';
import 'package:sileo/sileo.dart';

void main() => runApp(const SileoDemo());

class SileoDemo extends StatefulWidget {
  const SileoDemo({super.key});

  @override
  State<SileoDemo> createState() => _SileoDemoState();
}

class _SileoDemoState extends State<SileoDemo> {
  SileoTheme _theme = SileoTheme.system;
  SileoPosition _position = SileoPosition.topCenter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sileo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2B7FFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2B7FFF),
        brightness: Brightness.dark,
      ),
      // Mount the Toaster once, above all routes.
      builder: (context, child) =>
          Toaster(position: _position, theme: _theme, child: child),
      home: _HomePage(
        theme: _theme,
        position: _position,
        onThemeChanged: (t) => setState(() => _theme = t),
        onPositionChanged: (p) => setState(() => _position = p),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.theme,
    required this.position,
    required this.onThemeChanged,
    required this.onPositionChanged,
  });

  final SileoTheme theme;
  final SileoPosition position;
  final ValueChanged<SileoTheme> onThemeChanged;
  final ValueChanged<SileoPosition> onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Sileo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'An opinionated, physics-based toast for Flutter.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                _Section(
                  title: 'Theme',
                  child: SegmentedButton<SileoTheme>(
                    segments: const <ButtonSegment<SileoTheme>>[
                      ButtonSegment(
                        value: SileoTheme.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: SileoTheme.dark,
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: SileoTheme.system,
                        label: Text('System'),
                      ),
                    ],
                    selected: <SileoTheme>{theme},
                    onSelectionChanged: (s) => onThemeChanged(s.first),
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Position',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final p in SileoPosition.values)
                        ChoiceChip(
                          label: Text(_positionLabel(p)),
                          selected: position == p,
                          onSelected: (_) => onPositionChanged(p),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _Section(
                  title: 'Intents',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _Btn('Success', _success),
                      _Btn('Error', _error),
                      _Btn('Warning', _warning),
                      _Btn('Info', _info),
                      _Btn('Action', _action),
                      _Btn('Pill only', _pill),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Future',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _Btn('Resolves', _futureOK),
                      _Btn('Rejects', _futureFail),
                      _Btn('Clear all', () => sileo.clear(), tonal: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _success() => sileo.success(
        const SileoOptions(
          title: 'Changes Saved',
          description:
              'Changes saved successfully to the database. Please refresh the page to see the changes.',
        ),
      );

  void _error() => sileo.error(
        const SileoOptions(
          title: 'Something Went Wrong',
          description:
              'We\'re having trouble saving your changes to the server. Please try again in a few minutes.',
        ),
      );

  void _warning() => sileo.warning(
        const SileoOptions(
          title: 'Storage Almost Full',
          description:
              'You\'ve used 95% of your available storage. Please upgrade your plan to continue.',
        ),
      );

  void _info() => sileo.info(
        const SileoOptions(
          title: 'New Update Available',
          description:
              'Version 2.0 is now available. Please update your app to continue using the latest features.',
        ),
      );

  void _action() => sileo.action(
        SileoOptions(
          title: 'File Uploaded',
          description: 'Your file has been uploaded. Share it with your team?',
          button: SileoButton(
            title: 'Share Now',
            onPressed: () =>
                sileo.success(const SileoOptions(title: 'Link Copied')),
          ),
        ),
      );

  void _pill() => sileo.success(const SileoOptions(title: 'Copied'));

  void _futureOK() => sileo.future<String>(
        Future<String>.delayed(const Duration(seconds: 2), () => 'v2.1.0'),
        SileoFutureOptions<String>(
          loading: const SileoOptions(title: 'Deploying'),
          success: (v) => SileoOptions(
            title: 'Deployed',
            description: 'Your site is live at $v.',
          ),
          error: (e) => SileoOptions(title: 'Failed', description: '$e'),
        ),
      );

  void _futureFail() => sileo.future<void>(
        Future<void>.delayed(
          const Duration(seconds: 2),
          () => throw Exception('network timeout'),
        ),
        SileoFutureOptions<void>(
          loading: const SileoOptions(title: 'Uploading'),
          success: (_) => const SileoOptions(title: 'Uploaded'),
          error: (e) => const SileoOptions(
            title: 'Upload failed',
            description: 'Check your connection and try again.',
          ),
        ),
      );

  static String _positionLabel(SileoPosition p) => switch (p) {
        SileoPosition.topLeft => 'Top Left',
        SileoPosition.topCenter => 'Top Center',
        SileoPosition.topRight => 'Top Right',
        SileoPosition.bottomLeft => 'Bottom Left',
        SileoPosition.bottomCenter => 'Bottom Center',
        SileoPosition.bottomRight => 'Bottom Right',
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onPressed, {this.tonal = false});

  final String label;
  final VoidCallback onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    return tonal
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }
}
