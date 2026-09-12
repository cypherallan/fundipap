import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<User?> login({required String email, required String password}) async {
    var cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String role,
    required String phone,
    String? name,
    String? username,
    String? profession,
    String? searchKeyword,
    List<String>? otherSkills, // NEW
  }) async {
    var cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    var uid = cred.user!.uid;

    await _db.collection('users').doc(uid).set({
      'name': name ?? '',
      'username': username ?? '',
      'email': email,
      'role': role,
      'phone': phone,
      'skill': profession ?? 'General',
      'profession': profession ?? 'General',
      'searchKeyword': searchKeyword ?? profession?.toLowerCase() ?? 'general',
      'otherSkills': otherSkills ?? [], // NEW - your other skills
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (role == 'fundi') {
      await _db.collection('fundis').doc(uid).set({
        'name': name ?? '',
        'username': username ?? '',
        'email': email,
        'phone': phone,
        'skill': profession ?? 'General',
        'profession': profession ?? 'General',
        'searchKeyword':
            searchKeyword ?? profession?.toLowerCase() ?? 'general',
        'otherSkills': otherSkills ?? [], // NEW
        'specialization':
            profession ?? 'General', // for badge "Specializes in..."
        'bio': '',
        'price': 0,
        'rating': 5.0,
        'jobs': 0,
        'photoUrl': null,
        'resumes': [],
        'certificates': [],
        'portfolio': [],
        'location': 'Kisumu',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return cred.user;
  }

  Future<String?> getUserRole(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
