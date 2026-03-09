import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Non-web: show message. Use web to download PDF.
void downloadAnalyticsPdf(BuildContext context, Uint8List pdfBytes, String filename) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Export is available on web. Open this app in a browser to download PDF.'),
    ),
  );
}
