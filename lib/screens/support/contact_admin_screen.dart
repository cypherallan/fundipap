import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';

class ContactAdminScreen extends StatefulWidget {
  final String jobId;
  final String b2cId;
  final String c2bId;
  final int finalAmount;
  final String clientName;
  final String jobTitle;
  const ContactAdminScreen({
    super.key,
    required this.jobId,
    required this.b2cId,
    required this.c2bId,
    required this.finalAmount,
    required this.clientName,
    required this.jobTitle,
  });
  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final _descCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  double _progress = 0;
  String _uploadingField = '';
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var snap = await FirebaseFirestore.instance
        .collection('supportEscalations')
        .doc(widget.jobId)
        .get();
    if (snap.exists) setState(() => _data = snap.data()!);
  }

  IconData _iconForExt(String ext) {
    ext = ext.toLowerCase();
    if (ext.contains('pdf')) return Icons.picture_as_pdf;
    if (ext.contains('jpg') || ext.contains('jpeg') || ext.contains('png'))
      return Icons.image;
    return Icons.attach_file;
  }

  Future<void> _openFile(String url, String fileName) async {
    if (url.isEmpty) return;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening $fileName...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final localFile = File(filePath);
      if (!await localFile.exists()) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.writeToFile(localFile);
      }
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Open failed: $e')));
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _pick(String field) async {
    try {
      setState(() {
        _uploading = true;
        _uploadingField = field;
        _progress = 0;
      });
      final uid = FirebaseAuth.instance.currentUser!.uid;
      List<Map<String, dynamic>> uploaded = [];

      if (field == 'screenshots') {
        // screenshots stay multi-image like before
        var imgs = await _picker.pickMultiImage(imageQuality: 80);
        if (imgs.isEmpty) {
          setState(() {
            _uploading = false;
            _uploadingField = '';
          });
          return;
        }
        for (var f in imgs) {
          String name = f.name;
          String ext = name.split('.').last;
          String storageName =
              '${field}_${DateTime.now().millisecondsSinceEpoch}_$name';
          final ref = FirebaseStorage.instance.ref().child(
            'supportEscalations/${widget.jobId}/$uid/$storageName',
          );
          UploadTask task = ref.putFile(File(f.path));
          task.snapshotEvents.listen((s) {
            if (mounted)
              setState(
                () => _progress =
                    s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes),
              );
          });
          await task;
          String url = await ref.getDownloadURL();
          uploaded.add({'url': url, 'name': name, 'ext': ext});
        }
      } else {
        // EXACT same line as FundiProfile _pickAndUpload - shows PDF/DOCX/JPG
        final List<PlatformFile> picked = await FilePickerPlatform.instance
            .pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
            );
        if (picked.isEmpty) {
          setState(() {
            _uploading = false;
            _uploadingField = '';
          });
          return;
        }
        for (var pf in picked) {
          if (pf.path == null) continue;
          String name = pf.name;
          String ext = name.split('.').last;
          String storageName =
              '${field}_${DateTime.now().millisecondsSinceEpoch}_$name';
          final ref = FirebaseStorage.instance.ref().child(
            'supportEscalations/${widget.jobId}/$uid/$storageName',
          );
          UploadTask task = ref.putFile(File(pf.path!));
          task.snapshotEvents.listen((s) {
            if (mounted)
              setState(
                () => _progress =
                    s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes),
              );
          });
          await task;
          String url = await ref.getDownloadURL();
          uploaded.add({'url': url, 'name': name, 'ext': ext});
        }
      }

      var docRef = FirebaseFirestore.instance
          .collection('supportEscalations')
          .doc(widget.jobId);
      if (field == 'screenshots') {
        await docRef.set({
          field: FieldValue.arrayUnion(uploaded),
          'hasScreenshot': true,
          'jobId': widget.jobId,
          'fundiId': uid,
        }, SetOptions(merge: true));
      } else if (field == 'mpesa_statement') {
        await docRef.set({
          field: uploaded,
          'hasMpesaStatement': true,
          'jobId': widget.jobId,
          'fundiId': uid,
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          field: uploaded,
          'jobId': widget.jobId,
          'fundiId': uid,
        }, SetOptions(merge: true));
      }
      await _load();
      setState(() {
        _uploading = false;
        _uploadingField = '';
        _progress = 0;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadingField = '';
      });
    }
  }

  Future<void> _submit() async {
    if (_receivedCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enter amount received')));
      return;
    }
    var mpesa = (_data['mpesa_statement'] as List?) ?? [];
    var shots = (_data['screenshots'] as List?) ?? [];
    if (mpesa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload M-Pesa statement (pdf) is mandatory')),
      );
      return;
    }
    if (shots.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload at least 1 screenshot')));
      return;
    }
    if (_descCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add more details')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    final fundiEmail = user.email ?? '';
    if (fundiEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No email on account - update profile')),
      );
      return;
    }

    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('supportEscalations')
        .doc(widget.jobId)
        .set({
          'fundiEmail': fundiEmail,
          'fundiId': user.uid,
          'fundiPhone': user.phoneNumber ?? '',
          'amountFundiSaysReceived':
              int.tryParse(
                _receivedCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0,
          'description': _descCtrl.text.trim(),
          'status': 'open',
          'escalatedAt': now,
          'createdAt': now,
          'clientName': widget.clientName,
          'jobTitle': widget.jobTitle,
          'b2cId': widget.b2cId,
          'c2bId': widget.c2bId,
          'finalAmount': widget.finalAmount,
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'lastDisputeStatus': 'escalated_to_support',
          'lastDisputeMessage': _descCtrl.text.trim(),
          'escalatedAt': now,
          'hasSupportDocs': true,
        });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Escalated with ${mpesa.length + shots.length} files'),
      ),
    );
    Navigator.pop(context);
  }

  Widget _section(String title, String field, IconData icon) {
    List<dynamic> items = _data[field] ?? [];
    final isThis = _uploading && _uploadingField == field;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Spacer(),
              if (isThis)
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: FundipapColors.primaryYellow,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _pick(field),
                  icon: Icon(Icons.upload, size: 16),
                  label: Text('Upload'),
                ),
            ],
          ),
          if (isThis) ...[
            SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: _progress, minHeight: 6),
            ),
            SizedBox(height: 4),
            Text(
              'Uploading $title... ${(_progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
          SizedBox(height: 8),
          if (items.isEmpty && !isThis)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.black38),
                  SizedBox(width: 6),
                  Text(
                    'No $title yet',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ...items.map((entry) {
            String url = entry['url'] ?? '';
            String name = entry['name'] ?? 'File';
            String ext = entry['ext'] ?? '';
            if (name.length > 28) name = '${name.substring(0, 28)}...';
            return Container(
              margin: EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(_iconForExt(ext)),
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
                      icon: Icon(Icons.open_in_new, size: 18),
                      onPressed: () => _openFile(url, name),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('supportEscalations')
                            .doc(widget.jobId)
                            .update({
                              field: FieldValue.arrayRemove([entry]),
                            });
                        _load();
                      },
                    ),
                  ],
                ),
                onTap: () => _openFile(url, name),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contact Support - Upload Proof',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job ${widget.jobId} • ${widget.jobTitle}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'System says: KES ${widget.finalAmount}\nB2C: ${widget.b2cId}\nC2B: ${widget.c2bId}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _receivedCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount you actually received',
              prefixText: 'KES ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 16),
          _section(
            'M-Pesa Statement (pdf) *',
            'mpesa_statement',
            Icons.receipt_long,
          ),
          _section('M-Pesa SMS Screenshots *', 'screenshots', Icons.screenshot),
          _section('National ID (optional)', 'id_docs', Icons.badge),
          SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Explain issue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _submit,
              child: Text(
                'SUBMIT TO SUPPORT',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
