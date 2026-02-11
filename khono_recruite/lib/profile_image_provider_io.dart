import 'dart:io';

import 'package:flutter/material.dart';

/// Returns an [ImageProvider] for the image at [path]. Used on non-web platforms.
ImageProvider<Object> getProfileImageProviderFromPath(String path) {
  return FileImage(File(path));
}
