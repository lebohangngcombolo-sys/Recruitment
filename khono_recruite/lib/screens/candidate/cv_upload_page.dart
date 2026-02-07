import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import 'assessments_results_screen.dart';
import '../../widgets/application_flow_stepper.dart';

class CVUploadScreen extends StatefulWidget {
  final int applicationId;
  const CVUploadScreen({super.key, required this.applicationId});

  @override
  State<CVUploadScreen> createState() => _CVUploadScreenState();
}

class _CVUploadScreenState extends State<CVUploadScreen> {
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  TextEditingController resumeTextController = TextEditingController();
  bool uploading = false;
  String? token;

  // Enrollment-style Theme Colors
  final Color _primaryDark = Colors.transparent; // Background
  final Color _cardDark = Colors.black.withOpacity(0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _textSecondary = Colors.grey.shade300; // Secondary text
  final Color _boxFillColor = const Color(0xFFF2F2F2).withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    _loadToken();
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

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplicationFlowStepper(currentStep: 2),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final f = result.files.single;
        setState(() {
          selectedFileBytes = f.bytes;
          selectedFileName = f.name;
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No file selected")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  Future<void> _uploadCV() async {
    final tokenValue = token;
    if ((selectedFileBytes == null || selectedFileName == null) ||
        tokenValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a file and ensure you're logged in.")));
      return;
    }

    setState(() => uploading = true);

    try {
      final uri = Uri.parse(
          'http://127.0.0.1:5000/api/candidate/upload_resume/${widget.applicationId}');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $tokenValue';
      request.files.add(
        http.MultipartFile.fromBytes(
          'resume',
          selectedFileBytes!,
          filename: selectedFileName!,
        ),
      );
      request.fields['resume_text'] = resumeTextController.text;

      final streamedResponse = await request.send();
      final responseString = await streamedResponse.stream.bytesToString();
      Map<String, dynamic> resp = {};
      if (responseString.isNotEmpty) {
        try {
          final decoded = json.decode(responseString);
          if (decoded is Map<String, dynamic>) {
            resp = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          resp = {};
        }
      }

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 202) {
        final parserResultRaw = resp['parser_result'];
        final parserResult = parserResultRaw is Map<String, dynamic>
            ? Map<String, dynamic>.from(parserResultRaw)
            : null;
        final matchScore =
            parserResult?['match_score'] ?? parserResult?['score'];
        final message = streamedResponse.statusCode == 202
            ? "Resume uploaded; analysis queued."
            : (matchScore != null
                ? "Resume uploaded! CV Score: $matchScore"
                : "Resume uploaded!");
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));

        if (streamedResponse.statusCode == 202) {
          final analysisIdRaw = resp['analysis_id'];
          final analysisId =
              analysisIdRaw is num ? analysisIdRaw.toInt() : null;
          if (analysisId != null) {
            await _pollAnalysisStatus(analysisId);
          }
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AssessmentResultsPage(
                token: tokenValue,
                applicationId: widget.applicationId,
              ),
            ),
          );
        }
      } else {
        final err = resp['error'] ??
            resp['message'] ??
            (responseString.isNotEmpty ? responseString : 'Upload failed');
        throw Exception(err);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error uploading CV: $e")));
    } finally {
      if (!mounted) return;
      setState(() => uploading = false);
    }
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchAnalysisStatus(int analysisId) async {
    final tokenValue = token;
    if (tokenValue == null) return null;
    final uri = Uri.parse(
        'http://127.0.0.1:5000/api/candidate/cv-analyses/$analysisId');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenValue',
      },
    );
    if (response.statusCode != 200) return null;
    final decoded = _safeJsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<void> _pollAnalysisStatus(int analysisId) async {
    const maxAttempts = 20;
    const delay = Duration(seconds: 3);
    final tokenValue = token;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(delay);
      final statusResp = await _fetchAnalysisStatus(analysisId);
      if (statusResp == null) continue;

      final status = statusResp['status']?.toString();
      if (status == 'completed') {
        if (tokenValue == null) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CV analysis completed.")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AssessmentResultsPage(
              token: tokenValue,
              applicationId: widget.applicationId,
            ),
          ),
        );
        return;
      }
      if (status == 'failed') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CV analysis failed. Try again later.")),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("CV analysis still processing.")),
    );
  }

  @override
  void dispose() {
    resumeTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileLabel = selectedFileName ?? 'No file selected';

    return Scaffold(
      backgroundColor: _primaryDark,
      body: _buildBackground(
        SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  _buildStepperHeader(),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.all(16),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_file, size: 60, color: _accentRed),
                          const SizedBox(height: 12),
                          Text(
                            "Upload CV/Resume",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Select your CV file and optionally paste the text content for analysis.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(Icons.folder_open,
                                      color: _accentRed),
                                  label: Text(
                                    "Select File",
                                    style: TextStyle(
                                      color: _accentRed,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: _accentRed),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  fileLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: _textSecondary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: _boxFillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _accentRed.withOpacity(0.4)),
                            ),
                            child: TextField(
                              controller: resumeTextController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                labelText: "Paste your CV text (optional)",
                                labelStyle: TextStyle(
                                  color: _textSecondary,
                                  fontFamily: 'Poppins',
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: uploading ? null : _uploadCV,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentRed,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: uploading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Upload CV/Resume Continue",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supported: PDF/DOC/DOCX/TXT. Max file size depends on server config.',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
