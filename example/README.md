# Sileo example

A small, runnable demo of the [`sileo`](https://pub.dev/packages/sileo) toast
package. It mounts a single `Toaster` via `MaterialApp.builder` and lets you:

- fire every intent (`success`, `error`, `warning`, `info`, `action`, plus a
  bare "pill only" toast),
- drive a notification from a `Future` that resolves or rejects,
- switch the theme (light / dark / system) and the on-screen position live.

## Run

```sh
cd example
flutter run
```

Pick a device with `-d` (e.g. `flutter run -d chrome` for the web demo).
