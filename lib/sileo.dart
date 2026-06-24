/// Sileo — an opinionated, physics-based toast notification for Flutter.
///
/// Mount one [Toaster] (typically via `MaterialApp.builder`) and drive it
/// imperatively from anywhere with the global [sileo] instance:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => Toaster(theme: SileoTheme.system, child: child),
///   home: const HomePage(),
/// );
///
/// // ...later, from anywhere:
/// sileo.success(const SileoOptions(
///   title: 'Saved',
///   description: 'Your changes are live.',
/// ));
/// ```
library;

export 'src/options.dart'
    show
        SileoState,
        SileoPosition,
        SileoTheme,
        SileoStyles,
        SileoButton,
        SileoAutopilot,
        SileoOptions,
        SileoFutureOptions;
export 'src/store.dart' show SileoController, sileo;
export 'src/toaster.dart' show Toaster;
