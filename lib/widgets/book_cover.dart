import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Shows the cover image. If it is missing or fails to load (offline, CORS,
/// bad link) a designed gradient cover with the title is shown instead.
class BookCover extends StatelessWidget {
  final Map<String, dynamic> book;
  final BoxFit fit;
  const BookCover({super.key, required this.book, this.fit = BoxFit.cover});

  static const List<List<Color>> _palettes = [
    [Color(0xFF0E6B63), Color(0xFF083F3B)],
    [Color(0xFF3B4A8C), Color(0xFF1F2756)],
    [Color(0xFF9C4A35), Color(0xFF5E2517)],
    [Color(0xFF6B4E8E), Color(0xFF392A55)],
    [Color(0xFF2F6F9E), Color(0xFF173B58)],
    [Color(0xFF8A6D1F), Color(0xFF4D3B0B)],
  ];

  @override
  Widget build(BuildContext context) {
    final url = (book['coverUrl'] ?? '').toString().trim();
    if (url.isEmpty) return _fallback();
    return Image.network(
      url,
      fit: fit,
      cacheWidth: 400,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      loadingBuilder: (ctx, child, progress) => progress == null ? child : _fallback(),
      errorBuilder: (ctx, error, stack) => _fallback(),
    );
  }

  Widget _fallback() {
    final title = (book['title'] ?? '').toString();
    final author = (book['author'] ?? '').toString();
    final seed = title.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = _palettes[seed % _palettes.length];
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 120.0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: Row(
          children: [
            Container(width: (w * 0.06).clamp(4.0, 12.0), color: tint(Colors.black, 0.2)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all((w * 0.09).clamp(8.0, 18.0)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: serif((w / 8.5).clamp(11.0, 26.0), color: Colors.white)),
                    Text(author,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: tint(Colors.white, 0.75),
                            fontSize: (w / 12).clamp(9.0, 14.0))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
