import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> fundi;
  const ChatScreen({super.key, required this.fundi});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  late String chatId;
  late String myId;

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
    String fundiId = widget.fundi['id'] ?? widget.fundi['uid'] ?? '';
    chatId = myId.compareTo(fundiId) < 0
        ? '${myId}_$fundiId'
        : '${fundiId}_$myId';
    _markRead();
  }

  void _markRead() {
    FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'unreadCounts': {myId: 0},
    }, SetOptions(merge: true));
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    if (!await _canFundiSend()) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    String fundiId = widget.fundi['id'] ?? widget.fundi['uid'] ?? '';

    var myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myId)
        .get();
    String myUsername =
        myDoc.data()?['username'] ?? myDoc.data()?['name'] ?? 'User';
    String otherUsername =
        widget.fundi['username'] ?? widget.fundi['name'] ?? 'User';

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [myId, fundiId],
      'participantNames': {myId: myUsername, fundiId: otherUsername},
      'lastMessage': text,
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': myId,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });

    // PASTE HERE - after adding message
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'unreadCounts.$fundiId': FieldValue.increment(1),
      'unreadCounts.$myId': 0,
    });
  }

  Future<bool> _canFundiSend() async {
    var chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    if (chatDoc.exists)
      return true; // customer already started, fundi can reply

    // check my role
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myId)
        .get();
    String role = userDoc.data()?['role'] ?? '';
    if (role == 'fundi') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wait for client to message first',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
      return false;
    }
    return true; // customer can always start
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: FundipapColors.primaryYellow,
              child: Text((widget.fundi['name'] ?? 'F')[0]),
            ),
            const SizedBox(width: 8),
            Text(
              widget.fundi['name'] ?? 'Fundi',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var msgs = snap.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    var m = msgs[i].data() as Map<String, dynamic>;
                    bool isMe = m['senderId'] == myId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? FundipapColors.blackGray : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          m['text'] ?? '',
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.fundi['name'] ?? ''}...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: FundipapColors.primaryYellow,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
