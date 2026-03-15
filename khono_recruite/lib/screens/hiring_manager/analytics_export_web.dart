import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

void _downloadPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  final safeName = _sanitizeFilename(filename);
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = safeName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(milliseconds: 500), () {
    html.Url.revokeObjectUrl(url);
  });
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF download started')),
    );
  }
}

/// Web: trigger analytics PDF download via Blob and anchor.
void downloadAnalyticsPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  try {
    _downloadPdf(context, pdfBytes, filename);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

/// Web: trigger shortlist PDF download (same mechanism as analytics).
void downloadShortlistPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  try {
    _downloadPdf(context, pdfBytes, filename);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

/// Web: trigger shortlist CSV download for hiring committee.
Future<void> downloadShortlistCsv(BuildContext context, String csvContent, String filename) async {
  try {
    final safeName = filename.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
    final name = safeName.isEmpty || !safeName.endsWith('.csv') ? '${safeName.isEmpty ? "shortlist_export" : safeName}.csv' : safeName;
    final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    Future.delayed(const Duration(milliseconds: 500), () {
      html.Url.revokeObjectUrl(url);
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV download started')),
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

String _sanitizeFilename(String name) {
  String s = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  if (s.isEmpty) s = 'export.pdf';
  return s.endsWith('.pdf') ? s : '$s.pdf';
}
