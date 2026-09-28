import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_guard.dart';

class JobChatSection extends StatefulWidget {
  final String jobId;
  final bool isClient; // true if client view
  const JobChatSection({
    super.key,
    required this.jobId,
    required this.isClient,
  });

  @override
  State<JobChatSection> createState() => _JobChatSectionState();
}

class _JobChatSectionState extends State<JobChatSection> {
  final ctrl = TextEditingController();
  bool sending = false;

  Future<void> send() async {
    String text = ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (ChatGuard.containsPhone(text)) {
      await ChatGuard.flagAttempt(
        jobId: widget.jobId,
        senderId: uid,
        text: text,
        senderRole: widget.isClient ? 'client' : 'fundi',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Phone numbers not allowed. Keep chat in app for safety. Your attempt was flagged.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      // optional: show masked version? block completely:
      return;
    }

    setState(() => sending = true);
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': uid,
          'senderRole': widget.isClient ? 'client' : 'fundi',
          'createdAt': FieldValue.serverTimestamp(),
          'flagged': false,
        });
    ctrl.clear();
    setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.jobId)
              .collection('messages')
              .orderBy('createdAt')
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            var docs = snap.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                var m = docs[i].data() as Map<String, dynamic>;
                bool isMe =
                    m['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                bool isFlagged =
                    m['flagged'] == true ||
                    ChatGuard.containsPhone(m['text'] ?? '');
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFlagged
                          ? Colors.red.shade50
                          : (isMe ? Colors.black : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      border: isFlagged ? Border.all(color: Colors.red) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFlagged)
                          Row(
                            children: [
                              Icon(
                                Icons.flag,
                                size: 12,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Flagged - contains phone',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          isFlagged
                              ? ChatGuard.maskPhone(m['text'] ?? '')
                              : (m['text'] ?? ''),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isMe && !isFlagged
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Type message... No phone numbers',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: sending ? null : send,
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
