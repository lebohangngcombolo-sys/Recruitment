import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../utils/api_endpoints.dart';
import 'assessments_results_screen.dart';
class CVUploadScreen extends StatefulWidget {
  final int applicationId;
  const CVUploadScreen({super.key, required this.applicationId});

  @override
  State<CVUploadScreen> createState() => _CVUploadScreenState();
}

class _CVUploadScreenState extends State<CVUploadScreen> {
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  bool uploading = false;
  String? token;

  // Enrollment-style Theme Colors
  final Color _primaryDark = Colors.transparent; // Background
  final Color _cardDark = Colors.black.withOpacity(0.55); // Card background
  final Color _accentRed = const Color(0xFFC10D00); // Main red
  final Color _textSecondary = Colors.grey.shade300; // Secondary text

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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final f = result.files.single;
        if (f.bytes == null || f.bytes!.isEmpty) {
          setState(() {
            selectedFileBytes = null;
            selectedFileName = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Could not read the file. Try selecting it again or use a smaller file.")));
          }
          return;
        }
        setState(() {
          selectedFileBytes = f.bytes;
          selectedFileName = f.name.isNotEmpty ? f.name : 'resume.pdf';
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
    if (selectedFileBytes == null || selectedFileName == null || selectedFileName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a file to upload.")));
      return;
    }

    // Always get a fresh token at upload time
    String? tokenValue = await AuthService.getAccessToken();
    if (tokenValue == null || tokenValue.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Session expired or not logged in. Please log in again.")));
      return;
    }
    if (mounted) setState(() => token = tokenValue);

    setState(() => uploading = true);

    try {
      final uri = Uri.parse(
          '${ApiEndpoints.candidateBase}/upload_resume/${widget.applicationId}');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $tokenValue';
      request.files.add(
        http.MultipartFile.fromBytes(
          'resume',
          selectedFileBytes!,
          filename: selectedFileName!,
        ),
      );
      request.fields['resume_text'] = '';

      var streamedResponse = await request.send();
      var responseString = await streamedResponse.stream.bytesToString();

      // On 401, try refresh and retry once
      if (streamedResponse.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null && newToken.isNotEmpty && mounted) {
          setState(() => token = newToken);
          final retryRequest = http.MultipartRequest('POST', uri);
          retryRequest.headers['Authorization'] = 'Bearer $newToken';
          retryRequest.files.add(
            http.MultipartFile.fromBytes(
              'resume',
              selectedFileBytes!,
              filename: selectedFileName!,
            ),
          );
          retryRequest.fields['resume_text'] = '';
          streamedResponse = await retryRequest.send();
          responseString = await streamedResponse.stream.bytesToString();
          tokenValue = newToken;
        }
      }

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
            ? "Resume uploaded. You can view results on the next screen."
            : (matchScore != null
                ? "Resume uploaded! CV Score: $matchScore"
                : "Resume uploaded!");
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));

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
      } else {
        final err = resp['error'] ??
            resp['message'] ??
            (responseString.isNotEmpty ? responseString : 'Upload failed');
        if (streamedResponse.statusCode == 401 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Session expired. Please log in again.")));
        } else if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error uploading CV: $err")));
        }
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileLabel = selectedFileName ?? 'No file selected';

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
              child: Image.asset(
                'assets/icons/khono.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: _buildBackground(
        Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
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
                            "Select your CV file for analysis.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textSecondary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(
                                    selectedFileName != null
                                        ? Icons.check_circle
                                        : Icons.upload_file,
                                    color: selectedFileName != null
                                        ? Colors.green.shade400
                                        : Colors.white,
                                    size: 22,
                                  ),
                                  label: Text(
                                    selectedFileName != null
                                        ? "Uploaded"
                                        : "Select CV file",
                                    style: TextStyle(
                                      color: selectedFileName != null
                                          ? Colors.green.shade400
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: selectedFileName != null
                                          ? Colors.green.shade400
                                          : _accentRed,
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  fileLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: _textSecondary,
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
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
                                      "Upload CV",
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
