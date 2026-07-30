# dony

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase

This app depends on Firebase (`firebase_core`, `firebase_auth`,
`firebase_messaging`, `cloud_firestore`) and on **Firebase Remote Config**
(`firebase_remote_config`) to drive the community help center (video
tutorials + social links) via the remote parameter
**`help_center_config_v1`**. See
[`docs/help-center-remote-config.md`](docs/help-center-remote-config.md) for
the JSON schema, publishing steps, dev testing, staged rollout and
rollback.
