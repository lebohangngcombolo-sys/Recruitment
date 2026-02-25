import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Web: embeds YouTube iframe so video plays inline.
class YoutubeEmbed extends StatelessWidget {
  const YoutubeEmbed({
    super.key,
    required this.videoId,
    this.width,
    this.height = 320,
    this.autoplay = false,
    this.mute = false,
    this.loop = false,
  });

  final String videoId;
  final double? width;
  final double height;
  /// When true, video starts automatically (use with [mute] for browser autoplay policy).
  final bool autoplay;
  final bool mute;
  final bool loop;

  static final Set<String> _registered = {};

  static void _register(String videoId, {bool autoplay = false, bool mute = false, bool loop = false}) {
    final key = '$videoId-$autoplay-$mute-$loop';
    if (_registered.contains(key)) return;
    _registered.add(key);
    final viewType = 'youtube-embed-$key';
    final params = <String>['rel=0', 'modestbranding=1'];
    if (autoplay) params.add('autoplay=1');
    if (mute) params.add('mute=1');
    if (loop) params.add('loop=1&playlist=$videoId');
    final query = params.join('&');
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final embedUrl = 'https://www.youtube.com/embed/$videoId?$query';
        final iframe = html.IFrameElement()
          ..src = embedUrl
          ..style.border = 'none'
          ..style.borderRadius = '16px'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = '$videoId-$autoplay-$mute-$loop';
    _register(videoId, autoplay: autoplay, mute: mute, loop: loop);
    final viewType = 'youtube-embed-$key';
    final w = width ?? MediaQuery.sizeOf(context).width * 0.92;
    return SizedBox(
      width: w,
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
