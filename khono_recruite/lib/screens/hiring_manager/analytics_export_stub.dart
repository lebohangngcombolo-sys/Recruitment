import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Non-web (mobile/desktop): write PDF to app storage and open with system handler.
void downloadAnalyticsPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  _saveAndOpenPdf(context, pdfBytes, filename);
}

/// Shortlist export: same as analytics; saves PDF and opens with system handler.
void downloadShortlistPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  _saveAndOpenPdf(context, pdfBytes, filename);
}

/// Non-web: write CSV to temp file and open.
Future<void> downloadShortlistCsv(BuildContext context, String csvContent, String filename) async {
  try {
    final safeName = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final name = safeName.isEmpty || !safeName.endsWith('.csv') ? '${safeName.isEmpty ? "shortlist_export" : safeName}.csv' : safeName;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';
    final file = File(path);
    await file.writeAsString(csvContent, flush: true);
    final result = await OpenFile.open(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.type == ResultType.done ? 'CSV opened.' : 'CSV saved to app storage.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

Future<void> _saveAndOpenPdf(BuildContext context, Uint8List pdfBytes, String filename) async {
  try {
    final safeName = _sanitizeFilename(filename);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$safeName';
    final file = File(path);
    await file.writeAsBytes(pdfBytes);
    final result = await OpenFile.open(path);
    if (context.mounted) {
      if (result.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics PDF opened. You can save or share it from the viewer.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to app storage. Open manually if needed: ${result.message}')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

String _sanitizeFilename(String name) {
  String s = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  if (s.isEmpty) s = 'export.pdf';
  return s.endsWith('.pdf') ? s : '$s.pdf';
}
