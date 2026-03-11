import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void _onDragOver(html.Event e) {
  e.preventDefault();
  e.stopPropagation();
}

void _onDrop(html.Event e) {
  e.preventDefault();
  e.stopPropagation();
}

/// Register global drop zone. Uses documentElement + capture phase so we receive
/// drag/drop before Flutter's canvas can consume the events.
void registerEnrollmentDropZone({
  required BuildContext context,
  required void Function(PlatformFile file) onFileDropped,
  void Function()? onUnsupportedFile,
}) {
  _EnrollmentDropZoneImpl._callback = onFileDropped;
  _EnrollmentDropZoneImpl._onUnsupportedFile = onUnsupportedFile;
  final doc = html.document.documentElement!;
  doc.addEventListener('dragover', _EnrollmentDropZoneImpl._dragOverListener, true);
  doc.addEventListener('drop', _EnrollmentDropZoneImpl._dropListener, true);
}

void unregisterEnrollmentDropZone() {
  _EnrollmentDropZoneImpl._callback = null;
  _EnrollmentDropZoneImpl._onUnsupportedFile = null;
  final doc = html.document.documentElement!;
  doc.removeEventListener('dragover', _EnrollmentDropZoneImpl._dragOverListener, true);
  doc.removeEventListener('drop', _EnrollmentDropZoneImpl._dropListener, true);
}

abstract class _EnrollmentDropZoneImpl {
  static void Function(PlatformFile file)? _callback;
  static void Function()? _onUnsupportedFile;

  static void _dragOverListener(html.Event e) {
    _onDragOver(e);
  }

  static void _dropListener(html.Event e) {
    _onDrop(e);
    // ignore: avoid_dynamic_calls
    final dt = (e as dynamic).dataTransfer;
    if (dt == null || (dt.files?.isEmpty ?? true)) return;
    final file = dt.files!.first;
    final name = file.name ?? 'document';
    final ext = name.split('.').last.toLowerCase();
    if (ext != 'pdf' && ext != 'doc' && ext != 'docx') {
      // Invoke immediately so the error dialog shows right away (no waiting for next frame).
      _onUnsupportedFile?.call();
      return;
    }
    // Deliver file instantly so UI shows "Uploaded" + filename without waiting for read.
    final size = file.size ?? 0;
    _callback?.call(PlatformFile(name: name, size: size, bytes: null));

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result == null) return;
      final Uint8List list;
      if (result is ByteBuffer) {
        list = result.asUint8List();
      } else if (result is Uint8List) {
        list = result;
      } else {
        return;
      }
      final platformFile = PlatformFile(
        name: name,
        size: list.length,
        bytes: list,
      );
      _callback?.call(platformFile);
    });
    reader.readAsArrayBuffer(file);
  }
}
