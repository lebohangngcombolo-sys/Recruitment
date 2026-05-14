import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Non-web: no-op. Use tap/button only.
void registerEnrollmentDropZone({
  required BuildContext context,
  required void Function(PlatformFile file) onFileDropped,
  void Function()? onUnsupportedFile,
}) {}

void unregisterEnrollmentDropZone() {}
