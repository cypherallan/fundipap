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
          final user = snapshot.data!;
          // HARD ADMIN CHECK - don't wait for Firestore
          if (user.email == 'agwonamallan@gmail.com') {
            return HomeNavigator(role: 'admin', email: user.email ?? '');
          }
          return FutureBuilder<String?>(
            future: AuthService().getUserRole(user.uid),
            builder: (context, roleSnap) {
              if (roleSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              String role = roleSnap.data ?? 'client';
              if (role == 'admin') {
                role =
                    'client'; // only your email can be admin, already handled above
              }
              return HomeNavigator(role: role, email: user.email ?? '');
            },
          );
        }
        return const RoleSelectScreen();
      },
    );
  }
}
