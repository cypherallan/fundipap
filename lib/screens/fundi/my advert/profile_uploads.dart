import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';

class ProfileUploads extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool uploading;
  final double uploadProgress;
  final String uploadingField;
  final Function(String field) onPick;
  final Future<void> Function() onLoad;

  const ProfileUploads({
    super.key,
    required this.data,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadingField,
    required this.onPick,
    required this.onLoad,
  });

  int _totalCount() {
    int c = 0;
    c += (data?['resumes'] as List?)?.length ?? 0;
    c += (data?['certificates'] as List?)?.length ?? 0;
    c += (data?['portfolio'] as List?)?.length ?? 0;
    return c;
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _iconForExt(String ext) {
    ext = ext.toLowerCase();
    if (ext.contains('pdf')) return Icons.picture_as_pdf;
    if (ext.contains('doc')) return Icons.description;
    if (ext.contains('jpg') || ext.contains('jpeg') || ext.contains('png'))
      return Icons.image;
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        // NEW ATTACHMENTS CARD - TAP TO EXPAND
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black12),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_shared, size: 20),
            ),
            title: Text(
              'My Attachments',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${_totalCount()} files • Tap to manage',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
            children: [
              _section('Resume / CV', 'resumes', Icons.description, context),
              _section(
                'Certificates & Awards',
                'certificates',
                Icons.emoji_events,
                context,
              ),
              _section(
                'Past Work Photos',
                'portfolio',
                Icons.photo_library,
                context,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
            if (snap.data!.docs.isEmpty)
              return Text(
                'No feedbacks yet',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
              );
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

  Widget _section(
    String title,
    String field,
    IconData icon,
    BuildContext context,
  ) {
    List<dynamic> items = data?[field] ?? [];
    final isThis = uploading && uploadingField == field;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: uploadProgress,
                minHeight: 6,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation(
                  FundipapColors.primaryYellow,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Uploading ${title}... ${(uploadProgress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 8),
          if (items.isEmpty && !isThis)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    'No $title yet - tap Upload',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ...items.map((entry) {
            String url, name, ext;
            if (entry is String) {
              url = entry;
              name = entry.split('/').last.split('?').first;
              if (name.length > 25) name = name.substring(0, 25) + '...';
              if (name.isEmpty) name = 'File ${items.indexOf(entry) + 1}';
              ext = name.split('.').last;
            } else {
              url = entry['url'] ?? '';
              name = entry['name'] ?? 'File';
              ext = entry['ext'] ?? '';
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(
                  _iconForExt(ext),
                  color: FundipapColors.blackGray,
                ),
                title: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  ext.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.black45),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => _openFile(url),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('fundis')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .update({
                              field: FieldValue.arrayRemove([entry]),
                            });
                        onLoad();
                      },
                    ),
                  ],
                ),
                onTap: () => _openFile(url),
              ),
            );
          }),
        ],
      ),
    );
  }
}
