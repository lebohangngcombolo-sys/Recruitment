import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import 'assessments_results_screen.dart';

class CVUploadScreen extends StatefulWidget {
  final int applicationId;
  const CVUploadScreen({super.key, required this.applicationId});

  @override
  State<CVUploadScreen> createState() => _CVUploadScreenState();
}

class _CVUploadScreenState extends State<CVUploadScreen> {
  // CV (required)
  Uint8List? selectedFileBytes;
  String? selectedFileName;

  // ID document (required)
  Uint8List? idFileBytes;
  String? idFileName;

  // Qualifications: at least one required; can add more
  final List<Uint8List?> _qualificationBytes = [];
  final List<String?> _qualificationNames = [];

  bool uploading = false;
  String? token;

  static const String _apiBase = 'http://127.0.0.1:5000/api/candidate';

  // Theme
  final Color _primaryDark = Colors.transparent;
  final Color _cardDark = Colors.black.withOpacity(0.55);
  final Color _accentRed = const Color(0xFFC10D00);
  final Color _textSecondary = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _loadToken();
    if (_qualificationBytes.isEmpty) {
      _qualificationBytes.add(null);
      _qualificationNames.add(null);
    }
  }

  Future<void> _loadToken() async {
    final t = await AuthService.getAccessToken();
    if (!mounted) return;
    setState(() {
      token = t;
    });
  }

  Widget _buildBackground(Widget child) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/dark.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          color: Colors.black.withOpacity(0.4),
        ),
        child,
      ],
    );
  }

  Future<void> _pickFile() async {
    await _pickSingleFile(
      onPicked: (bytes, name) => setState(() {
        selectedFileBytes = bytes;
        selectedFileName = name;
      }),
    );
  }

  Future<void> _pickIdFile() async {
    await _pickSingleFile(
      onPicked: (bytes, name) => setState(() {
        idFileBytes = bytes;
        idFileName = name;
      }),
    );
  }

  Future<void> _pickQualificationFile(int index) async {
    await _pickSingleFile(
      onPicked: (bytes, name) {
        setState(() {
          while (_qualificationBytes.length <= index) {
            _qualificationBytes.add(null);
            _qualificationNames.add(null);
          }
          _qualificationBytes[index] = bytes;
          _qualificationNames[index] = name;
        });
      },
    );
  }

  void _addQualificationSlot() {
    if (_qualificationBytes.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can upload a maximum of two qualification documents.")),
      );
      return;
    }
    setState(() {
      _qualificationBytes.add(null);
      _qualificationNames.add(null);
    });
  }

  void _removeQualificationSlot(int index) {
    if (_qualificationBytes.length <= 1) return;
    setState(() {
      _qualificationBytes.removeAt(index);
      _qualificationNames.removeAt(index);
    });
  }

  Future<void> _pickSingleFile({
    required void Function(Uint8List bytes, String name) onPicked,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No file selected")));
        return;
      }
      final f = result.files.single;
      if (f.bytes == null || f.bytes!.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not read file. Try again or use a smaller file.")));
        return;
      }
      onPicked(f.bytes!, f.name.isNotEmpty ? f.name : 'document.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<bool> _uploadApplicationDocument({
    required String type,
    required Uint8List bytes,
    required String filename,
    required String tokenValue,
  }) async {
    final uri = Uri.parse('$_apiBase/applications/${widget.applicationId}/document');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $tokenValue';
    request.fields['type'] = type;
    request.files.add(http.MultipartFile.fromBytes('document', bytes, filename: filename));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) return true;
    if (mounted) {
      try {
        final err = json.decode(body) is Map ? (json.decode(body) as Map)['error'] : body;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type: $err')));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload $type')));
      }
    }
    return false;
  }

  Future<void> _uploadAll() async {
    if (selectedFileBytes == null || selectedFileName == null || selectedFileName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload your CV (required).")));
      return;
    }
    final hasId = idFileBytes != null && idFileName != null && idFileName!.isNotEmpty;
    final hasQual = _qualificationBytes.any((b) => b != null) && _qualificationNames.any((n) => n != null && n.isNotEmpty);
    if (!hasId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a certified copy of your ID.")));
      return;
    }
    if (!hasQual) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload at least one qualification document.")));
      return;
    }

    String? tokenValue = await AuthService.getAccessToken();
    if (tokenValue == null || tokenValue.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session expired. Please log in again.")));
      return;
    }
    if (mounted) setState(() => token = tokenValue);
    setState(() => uploading = true);

    try {
      final uri = Uri.parse('$_apiBase/upload_resume/${widget.applicationId}');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $tokenValue';
      request.files.add(http.MultipartFile.fromBytes('resume', selectedFileBytes!, filename: selectedFileName!));
      request.fields['resume_text'] = '';

      var streamedResponse = await request.send();
      var responseString = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null && newToken.isNotEmpty && mounted) {
          setState(() => token = newToken);
          final retry = http.MultipartRequest('POST', uri);
          retry.headers['Authorization'] = 'Bearer $newToken';
          retry.files.add(http.MultipartFile.fromBytes('resume', selectedFileBytes!, filename: selectedFileName!));
          retry.fields['resume_text'] = '';
          streamedResponse = await retry.send();
          responseString = await streamedResponse.stream.bytesToString();
          tokenValue = newToken;
        }
      }

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201 && streamedResponse.statusCode != 202) {
        Map<String, dynamic> resp = {};
        try {
          if (responseString.isNotEmpty && json.decode(responseString) is Map) {
            resp = Map<String, dynamic>.from(json.decode(responseString));
          }
        } catch (_) {}
        final err = resp['error'] ?? resp['message'] ?? responseString;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CV upload failed: $err")));
        setState(() => uploading = false);
        return;
      }

      if (idFileBytes != null && idFileName != null) {
        final ok = await _uploadApplicationDocument(type: 'id', bytes: idFileBytes!, filename: idFileName!, tokenValue: tokenValue);
        if (!ok) {
          setState(() => uploading = false);
          return;
        }
      }

      for (int i = 0; i < _qualificationBytes.length; i++) {
        if (_qualificationBytes[i] == null || _qualificationNames[i] == null || _qualificationNames[i]!.isEmpty) continue;
        final ok = await _uploadApplicationDocument(
          type: 'qualification',
          bytes: _qualificationBytes[i]!,
          filename: _qualificationNames[i]!,
          tokenValue: tokenValue,
        );
        if (!ok) {
          setState(() => uploading = false);
          return;
        }
      }

      if (!mounted) return;

      // Stop the loading spinner before showing success dialog
      setState(() => uploading = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Documents submitted',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: Text(
              'Your documents have been uploaded successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentResultsPage(
            token: tokenValue!,
            applicationId: widget.applicationId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (!mounted) return;
      if (uploading) {
        setState(() => uploading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildFileRow({
    required String label,
    required bool required,
    required String? fileName,
    required VoidCallback onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (required)
                Text('* ', style: TextStyle(color: _accentRed, fontSize: 14, fontWeight: FontWeight.w600)),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: Icon(
                  fileName != null ? Icons.check_circle : Icons.upload_file,
                  size: 18,
                  color: fileName != null ? Colors.green.shade400 : _accentRed,
                ),
                label: Text(
                  fileName != null ? 'Uploaded' : 'Choose File',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fileName != null ? Colors.green.shade400 : Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: fileName != null ? Colors.green.shade400 : _accentRed.withOpacity(0.8),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName ?? 'No file chosen',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _textSecondary,
                    fontStyle: fileName != null ? FontStyle.normal : FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Image.asset('assets/icons/khono.png', height: 32, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
      body: _buildBackground(
        SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      'Personal Documentation',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentRed.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFileRow(
                          label: 'Updated CV',
                          required: true,
                          fileName: selectedFileName,
                          onPick: _pickFile,
                        ),
                        _buildFileRow(
                          label: 'Certified copy of ID',
                          required: true,
                          fileName: idFileName,
                          onPick: _pickIdFile,
                        ),
                        ...List.generate(_qualificationBytes.length, (i) {
                          final isFirst = i == 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isFirst)
                                            Text('* ', style: TextStyle(color: _accentRed, fontSize: 14, fontWeight: FontWeight.w600)),
                                          Expanded(
                                            child: Text(
                                              isFirst
                                                  ? 'Certified Copy of Highest Qualification (Matric, Diploma, Degree)'
                                                  : 'Qualification ${i + 1}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isFirst) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '* At least one qualification document required.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _pickQualificationFile(i),
                                            icon: Icon(
                                              _qualificationNames[i] != null ? Icons.check_circle : Icons.upload_file,
                                              size: 18,
                                              color: _qualificationNames[i] != null ? Colors.green.shade400 : _accentRed,
                                            ),
                                            label: Text(
                                              _qualificationNames[i] != null ? 'Uploaded' : 'Choose File',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: _qualificationNames[i] != null ? Colors.green.shade400 : Colors.white,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: _qualificationNames[i] != null ? Colors.green.shade400 : _accentRed.withOpacity(0.8),
                                                width: 1.5,
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _qualificationNames[i] ?? 'No file chosen',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: _textSecondary,
                                                fontStyle: _qualificationNames[i] != null ? FontStyle.normal : FontStyle.italic,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_qualificationBytes.length > 1)
                                  IconButton(
                                    onPressed: () => _removeQualificationSlot(i),
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 22),
                                    tooltip: 'Remove',
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _addQualificationSlot,
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                          label: Text(
                            'Add another qualification',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: uploading ? null : _uploadAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: uploading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Upload documents',
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Supported: PDF, DOC, DOCX, PNG, JPG. Max file size depends on server.',
                            style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
