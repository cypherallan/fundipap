import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../app.dart';
import 'role_select_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // User still logged in - get role and go home
          return FutureBuilder<String?>(
            future: AuthService().getUserRole(snapshot.data!.uid),
            builder: (context, roleSnap) {
              if (roleSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              String role = roleSnap.data ?? 'client';
              // Safety: only your email can be admin
              if (role == 'admin' &&
                  snapshot.data!.email != 'agwonamallan@gmail.com') {
                role = 'client';
              }
              return HomeNavigator(
                role: role,
                email: snapshot.data!.email ?? '',
              );
            },
          );
        }
        // Not logged in
        return const RoleSelectScreen();
      },
    );
  }
}
