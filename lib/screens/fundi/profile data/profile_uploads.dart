import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';

class ProfileUploads extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool uploading;
  final double uploadProgress;
  final String uploadingField;
  final Function(String field) onPick;
  final Future<void> Function(String field, String url) onDelete;
  final Future<void> Function() onLoad;

  const ProfileUploads({
    super.key,
    required this.data,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadingField,
    required this.onPick,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Divider(),
        _section('Resume / CV', 'resumes', Icons.description),
        _section('Certificates & Awards', 'certificates', Icons.emoji_events),
        _section('Past Work Photos', 'portfolio', Icons.photo_library),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'My Customer Feedbacks',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fundis')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const CircularProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return Text(
                'No feedbacks yet',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
              );
            }
            return Column(
              children: snap.data!.docs.map((d) {
                var r = d.data() as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text(
                    r['clientName'] ?? 'Client',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    r['comment'] ?? '',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  trailing: Text('${r['rating'] ?? 5}★'),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _section(String title, String field, IconData icon) {
    List urls = data?[field] ?? [];
    final isThis = uploading && uploadingField == field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (isThis)
              Text(
                '${(uploadProgress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: FundipapColors.primaryYellow,
                ),
              )
            else
              TextButton.icon(
                onPressed: () => onPick(field),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload'),
              ),
          ],
        ),
        if (isThis) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: uploadProgress,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(FundipapColors.primaryYellow),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 8),
        if (urls.isEmpty && !isThis)
          Text(
            'No $title yet',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: urls
                .map<Widget>(
                  (url) => Chip(
                    label: Text('File ${urls.indexOf(url) + 1}'),
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    onDeleted: () async {
                      await FirebaseFirestore.instance
                          .collection('fundis')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .update({
                            field: FieldValue.arrayRemove([url]),
                          });
                      onLoad();
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
