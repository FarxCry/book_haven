import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';
import '../widgets/book_cover.dart';
import 'cart_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  final String? heroTag;
  const BookDetailScreen({super.key, required this.book, this.heroTag});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final DBHelper dbHelper = DBHelper();
  final TextEditingController commentCtrl = TextEditingController();
  List<Map<String, dynamic>> reviews = [];
  bool wished = false;
  bool expanded = false;
  bool adding = false;
  int selectedRating = 5;

  int get bookId => asInt(widget.book['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await dbHelper.getReviews(bookId);
    final w = await dbHelper.isInWishlist(UserSession.userId, bookId);
    if (!mounted) return;
    setState(() {
      reviews = r;
      wished = w;
    });
  }

  void _toast(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), action: action));
  }

  double get avgRating {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<double>(0, (a, r) => a + asDouble(r['rating']));
    return sum / reviews.length;
  }

  Future<void> _toggleWish() async {
    final now = await dbHelper.toggleWishlist(UserSession.userId, bookId);
    if (!mounted) return;
    setState(() => wished = now);
    _toast(now ? 'Saved to wishlist' : 'Removed from wishlist');
  }

  Future<void> _addToCart() async {
    if (adding) return;
    setState(() => adding = true);
    await dbHelper.addToCart(UserSession.userId, bookId);
    if (!mounted) return;
    setState(() => adding = false);
    _toast('Added to cart',
        action: SnackBarAction(
            label: 'View cart',
            textColor: AppColors.marigold,
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))));
  }

  Future<void> _submitReview() async {
    final text = commentCtrl.text.trim();
    if (text.isEmpty) {
      _toast('Write a few words about the book first.');
      return;
    }
    await dbHelper.addReview({
      'bookId': bookId,
      'userName': UserSession.name,
      'rating': selectedRating.toDouble(),
      'comment': text,
      'likes': 0,
    });
    commentCtrl.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await _load();
    if (mounted) _toast('Thanks, your review is posted.');
  }

  Future<void> _like(Map<String, dynamic> rev) async {
    await dbHelper.likeReview(asInt(rev['id']));
    await _load();
  }

  Widget _stars(double value, {double size = 18}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final icon = value >= i + 1
              ? Icons.star_rounded
              : (value >= i + 0.5 ? Icons.star_half_rounded : Icons.star_border_rounded);
          return Icon(icon, size: size, color: AppColors.marigold);
        }),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final isBest = asInt(b['isBestseller']) == 1;
    final isNew = asInt(b['isNewArrival']) == 1;
    final cover = ClipRRect(borderRadius: BorderRadius.circular(10), child: BookCover(book: b));

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.line)),
            boxShadow: [
              BoxShadow(color: tint(Colors.black, 0.05), blurRadius: 12, offset: const Offset(0, -3))
            ],
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(rs(asDouble(b['price'])),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.teal)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FilledButton.icon(
                  onPressed: adding ? null : _addToCart,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 330,
            backgroundColor: AppColors.tealDark,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: wished ? 'Remove from wishlist' : 'Save to wishlist',
                icon: Icon(wished ? Icons.favorite : Icons.favorite_border,
                    color: wished ? AppColors.rose : Colors.white),
                onPressed: _toggleWish,
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.tealDark, AppColors.teal]),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56, bottom: 20),
                    child: Container(
                      width: 164,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: tint(Colors.black, 0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 10))
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: widget.heroTag == null
                            ? cover
                            : Hero(tag: widget.heroTag!, child: cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _pill(b['genre'].toString(), Colors.white, AppColors.ink, border: true),
                          if (isBest) _pill('Bestseller', AppColors.marigold, AppColors.ink),
                          if (isNew) _pill('New', AppColors.teal, Colors.white),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(b['title'], style: serif(26)),
                      const SizedBox(height: 4),
                      Text('by ${b['author']}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _stars(avgRating),
                          const SizedBox(width: 8),
                          Text(
                              reviews.isEmpty
                                  ? 'No reviews yet'
                                  : '${avgRating.toStringAsFixed(1)} (${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'})',
                              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('About this book', style: serif(18)),
                      const SizedBox(height: 6),
                      Text(b['description'].toString(),
                          maxLines: expanded ? null : 3,
                          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.5)),
                      if (b['description'].toString().length > 120)
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => setState(() => expanded = !expanded),
                          child: Text(expanded ? 'Show less' : 'Read more'),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _infoTile(Icons.event_outlined, 'Released', b['releaseDate'].toString()),
                          const SizedBox(width: 10),
                          _infoTile(Icons.trending_up, 'Popularity', '${asInt(b['popularity'])}%'),
                          const SizedBox(width: 10),
                          _infoTile(Icons.local_shipping_outlined, 'Delivery', '2 to 4 days'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Text('Reviews', style: serif(20)),
                      const SizedBox(height: 10),
                      _reviewForm(),
                      const SizedBox(height: 14),
                      if (reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Be the first to review this book.',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      else
                        ...reviews.map(_reviewTile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg, {bool border = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border ? Border.all(color: AppColors.line) : null,
        ),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _infoTile(IconData icon, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.teal),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _reviewForm() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your rating', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: '${i + 1} stars',
                  onPressed: () => setState(() => selectedRating = i + 1),
                  icon: Icon(i < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 30, color: AppColors.marigold),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: commentCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'What did you think of this book?'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _submitReview, child: const Text('Post review')),
            ),
          ],
        ),
      );

  Widget _reviewTile(Map<String, dynamic> rev) {
    final name = rev['userName'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tint(AppColors.teal, 0.12),
            child: Text(initialsOf(name),
                style: const TextStyle(
                    color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                _stars(asDouble(rev['rating']), size: 15),
                const SizedBox(height: 6),
                Text(rev['comment'].toString(), style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _like(rev),
            icon: const Icon(Icons.thumb_up_alt_outlined, size: 17),
            label: Text('${asInt(rev['likes'])}'),
          ),
        ],
      ),
    );
  }
}
