# buildtrack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Connecting to the web app backend

The mobile app uses the same HTTP API as the web app; it does not connect
directly to MySQL or choose the database itself. The backend's `DB_TYPE`
chooses the database: use `mysql` for the local backend and `firebase` for the
production backend. The mobile app must point at the matching backend.

```shell
# Physical Android phone on the same Wi-Fi as the local backend:
flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:5000/api

# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api

# Production build: use the same public HTTPS API URL as the web app:
flutter build apk --release --dart-define=API_BASE_URL=https://<production-api-host>/api
```

For local development, set `DB_TYPE=mysql` on the local backend and replace
`<PC-LAN-IP>` with the computer's LAN IPv4 address. The phone and computer must
be on the same network, and the backend port must be reachable from the phone.
For production, set `DB_TYPE=firebase` on the deployed backend and build with
its public HTTPS API URL. Release builds require `API_BASE_URL` to be provided;
they will not silently fall back to localhost.

Workers sign in through the worker login and use their assigned worker profile.
Attendance Monitoring/Timekeeper and Tools Monitoring/Custodian access is
enabled from the role or position saved on that profile. Admins sign in through
the Admin login; backend authorization enforces these role-specific permissions.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
