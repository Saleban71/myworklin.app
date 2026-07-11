import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase.dart';
import 'core/theme.dart';
import 'screens/home_router.dart';
import 'screens/phone_auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  // Firebase (push notifications) is initialised lazily in Phase 1;
  // add `await Firebase.initializeApp();` once google-services.json is in place.
  runApp(const WorkLinkApp());
}

class WorkLinkApp extends StatelessWidget {
  const WorkLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkLink',
      debugShowCheckedModeBanner: false,
      theme: worklinkTheme(),
      home: StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = db.auth.currentSession;
          if (session == null) return const PhoneAuthScreen();
          return const HomeRouter();
        },
      ),
    );
  }
}
