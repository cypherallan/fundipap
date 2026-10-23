import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class UploadEvidenceScreen extends StatefulWidget {
  final String disputeId;
  const UploadEvidenceScreen({super.key, required this.disputeId});
  @override
  State<UploadEvidenceScreen> createState() => _UploadEvidenceScreenState();
}

class _UploadEvidenceScreenState extends State<UploadEvidenceScreen> {
  final statementCtrl = TextEditingController();
  final picker = ImagePicker();
  List<String> photoUrls = [];
  List<String> videoUrls = [];
  List<String> docUrls = [];
  bool loading = false;
  bool uploading = false;

  Future<String> _uploadFile(File file, String folder) async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    var ref = FirebaseStorage.instance.ref().child(
      'disputes/${widget.disputeId}/$uid/$folder/$fileName',
    );
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> pickPhotos() async {
    var images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isEmpty) return;
    setState(() => uploading = true);
    for (var img in images) {
      try {
        var url = await _uploadFile(File(img.path), 'photos');
        setState(() => photoUrls.add(url));
      } catch (e) {}
    }
    setState(() => uploading = false);
  }

  Future<void> pickVideo() async {
    var video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    setState(() => uploading = true);
    try {
      var url = await _uploadFile(File(video.path), 'videos');
      setState(() => videoUrls.add(url));
    } catch (e) {}
    setState(() => uploading = false);
  }

  Future<void> pickDocAsImage() async {
    // M-Pesa screenshot is image - using image picker for now
    var img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;
    setState(() => uploading = true);
    try {
      var url = await _uploadFile(File(img.path), 'docs');
      setState(() => docUrls.add(url));
    } catch (e) {}
    setState(() => uploading = false);
  }

  Future<void> submit(Map<String, dynamic> dispute) async {
    if (statementCtrl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Write at least 5 chars statement')),
      );
      return;
    }
    var uid = FirebaseAuth.instance.currentUser!.uid;
    bool isReporter = dispute['reportedBy'] == uid;
    setState(() => loading = true);
    String fieldPrefix = isReporter ? 'reporter' : 'reported';

    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          '${fieldPrefix}Evidence': {
            'statement': statementCtrl.text.trim(),
            'photos': photoUrls,
            'videos': videoUrls,
            'docs': docUrls,
            'submittedAt': FieldValue.serverTimestamp(),
            'submittedBy': uid,
            'acceptedRedo': false,
          },
          '${fieldPrefix}EvidenceSubmitted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Evidence submitted ✓ ${photoUrls.length} photos'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context);
    }
    setState(() => loading = false);
  }

  Future<void> acceptRedo() async {
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          'reportedEvidence': {
            'statement': 'I accept to redo work for free - no strike.',
            'acceptedRedo': true,
            'submittedAt': FieldValue.serverTimestamp(),
          },
          'reportedEvidenceSubmitted': true,
          'fundiAcceptedRedo': true,
          'status': 'accepted_redo',
          'evidenceStatus': 'evidence_complete',
        });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .doc(widget.disputeId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        var d = snap.data!.data() as Map<String, dynamic>;
        var cfg = d['evidenceConfig'] as Map? ?? {};
        String hint = cfg['hint'] ?? 'Describe what happened';
        bool isRepeat = d['type'] == 'repeat_job';
        bool isFundi = d['fundiId'] == FirebaseAuth.instance.currentUser!.uid;
        bool isReported =
            d['reportedBy'] != FirebaseAuth.instance.currentUser!.uid;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Submit Evidence - ${d['jobTitle']}',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(hint, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Your statement *',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: statementCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Explain your side...',
                  ),
                ),
                SizedBox(height: 16),

                if (uploading) LinearProgressIndicator(),

                if (cfg['requiresPhoto'] == true || cfg.isEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Photos (Optional - but helps you win)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      if (photoUrls.isNotEmpty)
                        Text(
                          '${photoUrls.length} uploaded ✓',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: photoUrls
                        .map(
                          (u) => Chip(
                            label: Text('Photo ${photoUrls.indexOf(u) + 1}'),
                            avatar: Icon(Icons.check, color: Colors.green),
                          ),
                        )
                        .toList(),
                  ),
                  ElevatedButton.icon(
                    onPressed: uploading ? null : pickPhotos,
                    icon: Icon(Icons.photo_library),
                    label: Text(
                      photoUrls.isEmpty
                          ? 'Add Photos (Optional)'
                          : 'Add More Photos',
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                if (cfg['requiresVideo'] == true) ...[
                  Text(
                    'Video test - e.g. socket not working (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (videoUrls.isNotEmpty)
                    Text(
                      '${videoUrls.length} video(s) uploaded ✓',
                      style: TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  ElevatedButton.icon(
                    onPressed: uploading ? null : pickVideo,
                    icon: Icon(Icons.videocam),
                    label: Text('Add Video (Optional)'),
                  ),
                  SizedBox(height: 12),
                ],
                if (cfg['requiresDoc'] == true) ...[
                  Text(
                    'M-Pesa / Receipt (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (docUrls.isNotEmpty)
                    Text(
                      '${docUrls.length} doc(s) uploaded ✓',
                      style: TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  ElevatedButton.icon(
                    onPressed: uploading ? null : pickDocAsImage,
                    icon: Icon(Icons.receipt),
                    label: Text('Add Screenshot (Optional)'),
                  ),
                  SizedBox(height: 12),
                ],

                if (isRepeat && isFundi && isReported) ...[
                  Divider(),
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Repeat job? Accept free redo now = NO STRIKE. Deny and lose = strike + 50% cut.',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                              onPressed: () => acceptRedo(),
                              child: Text(
                                'Accept Redo Free - No Strike',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    onPressed: (loading || uploading) ? null : () => submit(d),
                    child: loading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Submit Evidence (Optional photos okay)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You can submit without photos for testing. Before publishing we make it mandatory for damaged_property / incomplete_work / repeat_job.',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
