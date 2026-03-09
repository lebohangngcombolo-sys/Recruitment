import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Non-web fallback: shows thumbnail and opens YouTube when tapped.
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
  final bool autoplay;
  final bool mute;
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final w = width ?? MediaQuery.sizeOf(context).width * 0.9;
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
              width: w,
              height: height,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(18),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
          ),
        ],
      ),
    );
  }
}
