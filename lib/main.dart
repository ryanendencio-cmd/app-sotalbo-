import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/worker_dashboard.dart';
import 'screens/history_screen.dart';
import 'screens/timekeeper_dashboard.dart';
import 'screens/tools_monitoring_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/payslip_screen.dart';
import 'screens/timesheet_screen.dart';
import 'screens/worker_profile_screen.dart';
import 'screens/timekeeper_profile_screen.dart';
import 'screens/admin_profile_screen.dart';
import 'screens/workers_screen.dart';
import 'screens/cash_advance_screen.dart';
import 'screens/worker_attendance_screen.dart';
import 'screens/worker_tools_screen.dart';
import 'screens/worker_salary_screen.dart';
import 'screens/attendance_management_screen.dart';
import 'services/api_service.dart';
import 'theme/buildtrack_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    DevicePreview(
      enabled: kIsWeb && !kReleaseMode,
      builder: (context) => const BuildTrackApp(),
    ),
  );
}

class BuildTrackApp extends StatelessWidget {
  const BuildTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S-CON BuildTrack',
      debugShowCheckedModeBanner: false,
      theme: BuildTrackTheme.light,
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/register': (context) => const RegisterScreen(),

        // Worker Routes
        '/dashboard': (context) => const WorkerDashboard(),
        '/worker_dashboard': (context) => const WorkerDashboard(),
        '/history': (context) => const HistoryScreen(),
        '/payslip': (context) => const PayslipScreen(),
        '/timesheet': (context) => const TimesheetScreen(),
        '/worker_profile': (context) => const WorkerProfileScreen(),
        '/worker_attendance': (context) => const WorkerAttendanceScreen(),
        '/worker_tools': (context) => const WorkerToolsScreen(),
        '/worker_salary': (context) => const WorkerSalaryScreen(),

        // Attendance Staff / Timekeeper Routes
        '/timekeeper': (context) =>
            _adminRestrictedScreen(const TimekeeperDashboard()),
        '/timekeeper_dashboard': (context) =>
            _adminRestrictedScreen(const TimekeeperDashboard()),
        '/timekeeper_profile': (context) =>
            _adminRestrictedScreen(const TimekeeperProfileScreen()),
        '/attendance_management': (context) =>
            const AttendanceManagementScreen(),

        // Tools Custodian Routes
        '/tools_monitoring': (context) => const ToolsMonitoringScreen(),

        // Admin Dashboard Route
        '/admin_dashboard': (context) {
          final initialIndex = ModalRoute.of(context)?.settings.arguments;
          return AdminDashboardScreen(
            initialIndex: initialIndex is int ? initialIndex : 0,
          );
        },
        '/admin_profile': (context) =>
            _adminRestrictedScreen(const AdminProfileScreen()),

        // API-connected screens
        '/projects': (context) => const ProjectsScreen(),
        '/schedules': (context) =>
            _adminRestrictedScreen(const SchedulesScreen()),
        '/reports': (context) => _adminRestrictedScreen(const ReportsScreen()),
        '/workers': (context) => _adminRestrictedScreen(const WorkersScreen()),
        '/cash_advance': (context) => const CashAdvanceScreen(),
      },
    );
  }
}

Widget _adminRestrictedScreen(Widget screen) {
  if (ApiService.currentUserRole?.toLowerCase() != 'admin') return screen;
  return const _AdminMobileAccessRestrictedScreen();
}

class _AdminMobileAccessRestrictedScreen extends StatelessWidget {
  const _AdminMobileAccessRestrictedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unavailable on mobile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 44,
                color: Color(0xFFA63228),
              ),
              const SizedBox(height: 12),
              const Text(
                'This administrative function is available in the web app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/admin_dashboard',
                  (route) => false,
                ),
                child: const Text('Back to Admin Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
