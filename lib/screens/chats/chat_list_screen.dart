import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: myId)
            .orderBy('lastAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            // First time this query runs, Firestore will throw missing index
            // Check debug console for link to create it
            debugPrint('Chat list error: ${snap.error}');
            return Center(
              child: Text(
                'You have no messages from customers',
                style: GoogleFonts.inter(color: Colors.black54),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'You have no messages from customers',
                style: GoogleFonts.inter(color: Colors.black54),
              ),
            );
          }
          var chats = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: chats.length,
            itemBuilder: (_, i) {
              var c = chats[i].data() as Map<String, dynamic>;
              String otherId = (c['participants'] as List).firstWhere(
                (id) => id != myId,
                orElse: () => '',
              );
              String otherName = c['participantNames']?[otherId] ?? 'User';
              if (otherName.toLowerCase() == 'you') {
                otherName = 'Customer';
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: FundipapColors.primaryYellow,
                    child: Text(
                      otherName[0],
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    otherName,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    c['lastMessage'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(fundi: {'id': otherId, 'name': otherName}),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
