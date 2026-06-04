import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khono_recruite/widgets/youtube_embed.dart';

class InternStoriesPage extends StatelessWidget {
  const InternStoriesPage({super.key});

  static const Color _accent = Color(0xFFC10D00);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _textPrimary = Color(0xFFF5F5F5);
  static const Color _textSecondary = Color(0xFFA0A0A0);
  static const double _maxContentWidth = 1200;

  static const String _heroVideoId = '8jUPt2O7qpU';

  static const List<Map<String, String>> _stories = [
    {
      'name': 'Busisiwe D.',
      'role': 'Software Development · 2025',
      'imageUrl': 'assets/images/DYICT.jpeg',
      'quote':
          'The Academy didn\'t just teach me to code—it showed me how to think like an engineer. '
          'The projects we shipped are on my CV now, and I\'m in a role I didn\'t think was possible a year ago.',
    },
    {
      'name': 'Tiyane M.',
      'role': 'Data & Analytics · 2025',
      'imageUrl': 'assets/images/Khonology.jpeg',
      'quote':
          'Working with real data and the same tools used by major South African companies changed how I see my career. '
          'The 12-month structure and mentorship gave me confidence I couldn\'t get from a short course.',
    },
    {
      'name': 'Sipho M.',
      'role': 'Academy · 2025',
      'imageUrl': 'assets/images/Sipho&Charmaine.jpeg',
      'quote':
          'Learning in the academy—hands-on sessions, real tools, and a room full of people on the same journey. '
          'From AWS to building products, every day felt like a step toward the career we wanted.',
    },
    {
      'name': 'Lebohang N.',
      'role': 'Software Development · 2025',
      'imageUrl': 'assets/images/profile_placeholder.png',
      'quote':
          'From day one we were on real projects with real impact. The mix of soft skills and technical depth is what sets this apart. '
          'I\'m now building products at a company I used to only read about.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(media: media),
                  _TitleSection(media: media),
                  for (int i = 0; i < _stories.length; i++)
                    _StorySection(
                      story: _stories[i],
                      index: i,
                      media: media,
                    ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.go('/'),
              child: Image.asset(
                'assets/icons/khono.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double mediaPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w > 1400) return 80;
  if (w > 900) return 48;
  return 24;
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.media});

  final Size media;

  @override
  Widget build(BuildContext context) {
    final height = media.height * 0.72;
    final width = media.width;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubeEmbed(
            videoId: InternStoriesPage._heroVideoId,
            width: width,
            height: height,
            autoplay: true,
            mute: true,
            loop: true,
          ),
          // Very subtle gradient so video doesn’t feel flat
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.media});

  final Size media;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaPadding(context),
        vertical: 48,
      ),
      child: Column(
        children: [
          Text(
            'Stories from the Academy',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: _responsiveSize(media.width, 32, 48),
              fontWeight: FontWeight.w700,
              color: InternStoriesPage._textPrimary,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Real experiences from our interns—in their words',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: _responsiveSize(media.width, 15, 18),
              fontWeight: FontWeight.w400,
              color: InternStoriesPage._textSecondary,
              letterSpacing: 0.2,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

double _responsiveSize(double width, double small, double large) {
  if (width < 600) return small;
  if (width > 1000) return large;
  return small + (large - small) * ((width - 600) / 400);
}

class _StorySection extends StatelessWidget {
  const _StorySection({
    required this.story,
    required this.index,
    required this.media,
  });

  final Map<String, String> story;
  final int index;
  final Size media;

  @override
  Widget build(BuildContext context) {
    final imageOnLeft = index.isEven;
    final sectionHeight = (media.height * 0.52).clamp(380.0, 520.0);
    final padding = mediaPadding(context);
    final contentWidth = (media.width - 2 * padding).clamp(0.0, InternStoriesPage._maxContentWidth);
    final contentPadding = (media.width - contentWidth) / 2;

    final imageUrl = story['imageUrl'] ?? '';
    final initials = (story['name'] ?? '?')
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final isAsset = imageUrl.startsWith('assets/') || (!imageUrl.startsWith('http') && imageUrl.isNotEmpty);
    final assetPath = isAsset ? (imageUrl.startsWith('assets/') ? imageUrl : 'assets/$imageUrl') : imageUrl;
    // On web, Image.asset can request assets/assets/... (404). Load via network URL with single "assets/" instead.
    final String? assetWebUrl = (kIsWeb && isAsset)
        ? '${Uri.base.origin}${Uri.base.path.endsWith('/') ? Uri.base.path : '${Uri.base.path}/'}$assetPath'
        : null;
    Widget imageBlock = ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: imageOnLeft ? const Radius.circular(0) : const Radius.circular(24),
        right: imageOnLeft ? const Radius.circular(24) : const Radius.circular(0),
      ),
      child: imageUrl.isEmpty
          ? _PlaceholderAvatar(initials: initials)
          : isAsset
              ? (assetWebUrl != null
                  ? Image.network(
                      assetWebUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderAvatar(initials: initials),
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _PlaceholderAvatar(initials: initials),
                    )
                  : Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderAvatar(initials: initials),
                    ))
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderAvatar(initials: initials),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _PlaceholderAvatar(initials: initials),
                ),
    );

    Widget contentBlock = Container(
      width: double.infinity,
      height: sectionHeight,
      padding: EdgeInsets.fromLTRB(
        imageOnLeft ? 56 : 48,
        48,
        imageOnLeft ? 48 : 56,
        48,
      ),
      decoration: const BoxDecoration(
        color: InternStoriesPage._surface,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ACADEMY STORY',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: InternStoriesPage._accent,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story['name']!,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: InternStoriesPage._textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              story['role']!,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: InternStoriesPage._textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"',
                  style: GoogleFonts.inter(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: InternStoriesPage._accent.withOpacity(0.6),
                    height: 0.9,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      story['quote']!,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: InternStoriesPage._textPrimary.withOpacity(0.92),
                        height: 1.7,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      height: sectionHeight,
      child: Row(
        children: [
          SizedBox(width: contentPadding),
          Expanded(
            child: Row(
              children: imageOnLeft
                  ? [
                      Expanded(flex: 48, child: imageBlock),
                      Expanded(flex: 52, child: contentBlock),
                    ]
                  : [
                      Expanded(flex: 52, child: contentBlock),
                      Expanded(flex: 48, child: imageBlock),
                    ],
            ),
          ),
          SizedBox(width: contentPadding),
        ],
      ),
    );
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.06),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: 42,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.25),
          letterSpacing: 2,
        ),
      ),
    );
  }
}
