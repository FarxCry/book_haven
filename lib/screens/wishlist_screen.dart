import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> wishItems = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadWishlist();
  }

  Future<void> loadWishlist() async {
    final data = await dbHelper.getWishlist(UserSession.userId);
    if (!mounted) return;
    setState(() {
      wishItems = data;
      loading = false;
    });
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _remove(Map<String, dynamic> book) async {
    await dbHelper.toggleWishlist(UserSession.userId, asInt(book['id']));
    await loadWishlist();
    _toast('Removed from wishlist');
  }

  Future<void> _addToCart(Map<String, dynamic> book) async {
    await dbHelper.addToCart(UserSession.userId, asInt(book['id']));
    _toast('${book['title']} added to cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : wishItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_border, size: 64, color: AppColors.muted),
                        const SizedBox(height: 12),
                        Text('Nothing saved yet', style: serif(20)),
                        const SizedBox(height: 6),
                        const Text('Tap the heart on any book to save it for later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 18),
                        FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Browse books')),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: wishItems.length,
                  itemBuilder: (ctx, i) {
                    final book = wishItems[i];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
                        loadWishlist();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 62,
                              height: 92,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: BookCover(book: book)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book['title'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: serif(15)),
                                  Text(book['author'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.muted, fontSize: 12.5)),
                                  const SizedBox(height: 6),
                                  Text(rs(asDouble(book['price'])),
                                      style: const TextStyle(
                                          color: AppColors.teal, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 36),
                                            padding: const EdgeInsets.symmetric(horizontal: 12)),
                                        onPressed: () => _addToCart(book),
                                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                                        label: const Text('Add to cart'),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Remove',
                                        icon: const Icon(Icons.favorite, color: AppColors.rose),
                                        onPressed: () => _remove(book),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
