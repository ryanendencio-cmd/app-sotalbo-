import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/walkthrough_screen.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    DevicePreview(
      enabled: true,
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3EFEA),
        primaryColor: const Color(0xFFA63228),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA63228),
          primary: const Color(0xFFA63228),
          secondary: const Color(0xFFE8C547),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/walkthrough': (context) => const WalkthroughScreen(),
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

        // Attendance Staff / Timekeeper Routes
        '/timekeeper': (context) => const TimekeeperDashboard(),
        '/timekeeper_dashboard': (context) => const TimekeeperDashboard(),
        '/timekeeper_profile': (context) => const TimekeeperProfileScreen(),

        // Tools Custodian Routes
        '/tools_monitoring': (context) => const ToolsMonitoringScreen(),

        // Admin Dashboard Route
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/admin_profile': (context) => const AdminProfileScreen(),

        // API-connected screens
        '/projects': (context) => const ProjectsScreen(),
        '/schedules': (context) => const SchedulesScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/workers': (context) => const WorkersScreen(),
        '/cash_advance': (context) => const CashAdvanceScreen(),
      },
    );
  }
}