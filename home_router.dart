import 'package:flutter/material.dart';

import '../core/supabase.dart';
import 'employer_screens.dart';
import 'phone_auth_screen.dart';
import 'worker_screens.dart';

/// Routes to the worker or employer experience based on the profile role.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: db
          .from('profiles')
          .select('role')
          .eq('id', db.auth.currentUser!.id)
          .maybeSingle(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final role = snap.data?['role'];
        if (role == null) return const OnboardingScreen();
        return role == 'employer'
            ? const EmployerHomeScreen()
            : const WorkerDashboardScreen();
      },
    );
  }
}
