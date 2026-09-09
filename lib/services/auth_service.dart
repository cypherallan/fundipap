import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<User?> signUp({
    required String email,
    required String password,
    required String role,
    required String phone,
  }) async {
    var cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'role': role, // customer, fundi, admin
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'location':
          null, // will be set from device GPS on profile creation - global
    });
    return cred.user;
  }

  Future<User?> login({required String email, required String password}) async {
    var cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<String?> getUserRole(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'];
  }

  Future<void> logout() => _auth.signOut();
}
