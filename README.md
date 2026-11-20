# buildtrack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Connecting to the web app backend

The mobile app uses the same HTTP API as the web app; it does not connect
directly to MySQL. Set `API_BASE_URL` to the backend URL (including `/api`) when
running or building the app:

```shell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

For a physical phone on the same network as a local development server, use
the computer's LAN IP instead of `10.0.2.2`. For web or an iOS simulator,
`http://localhost:5000/api` works when the backend is running on that same
computer. Production builds should use the web app's HTTPS API URL.

The backend's `DB_TYPE` setting chooses the database, so use the same backend
instance as the web app if both apps must share data.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
