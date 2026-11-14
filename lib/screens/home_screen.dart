import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/book_cover.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'book_detail_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper dbHelper = DBHelper();
  final TextEditingController searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> allBooks = [];
  List<Map<String, dynamic>> filtered = [];
  Map<int, Map<String, dynamic>> ratings = {};
  Set<int> wishIds = {};
  int cartCount = 0;
  bool loading = true;

  String query = '';
  String genre = 'All';
  String special = 'All';
  String sortBy = 'Featured';

  static const List<String> specials = ['All', 'Bestsellers', 'New Arrivals'];
  static const List<String> sortOptions = [
    'Featured',
    'Price: Low to High',
    'Price: High to Low',
    'Popularity',
    'Newest',
  ];

  bool get isFiltering => query.isNotEmpty || genre != 'All' || special != 'All';

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    try {
      final books = await dbHelper.getBooks();
      final rt = await dbHelper.getRatingsMap();
      final wl = await dbHelper.getWishlistIds(UserSession.userId);
      final cc = await dbHelper.getCartCount(UserSession.userId);
      if (!mounted) return;
      setState(() {
        allBooks = books;
        ratings = rt;
        wishIds = wl;
        cartCount = cc;
        loading = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _toast('Could not load books: $e');
    }
  }

  void _applyFilters() {
    final q = query.toLowerCase();
    final list = allBooks.where((b) {
      final matchesSearch = q.isEmpty ||
          b['title'].toString().toLowerCase().contains(q) ||
          b['author'].toString().toLowerCase().contains(q) ||
          b['genre'].toString().toLowerCase().contains(q);
      final matchesGenre = genre == 'All' || b['genre'] == genre;
      final matchesSpecial = special == 'All' ||
          (special == 'Bestsellers' && asInt(b['isBestseller']) == 1) ||
          (special == 'New Arrivals' && asInt(b['isNewArrival']) == 1);
      return matchesSearch && matchesGenre && matchesSpecial;
    }).toList();

    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (sortBy) {
        case 'Price: Low to High':
          return asDouble(a['price']).compareTo(asDouble(b['price']));
        case 'Price: High to Low':
          return asDouble(b['price']).compareTo(asDouble(a['price']));
        case 'Newest':
          return b['releaseDate'].toString().compareTo(a['releaseDate'].toString());
        default:
          return asInt(b['popularity']).compareTo(asInt(a['popularity']));
      }
    }

    list.sort(cmp);
    filtered = list;
  }

  void _toast(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), action: action));
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) loadAll();
  }

  Future<void> _toggleWish(Map<String, dynamic> book) async {
    final id = asInt(book['id']);
    final nowWished = await dbHelper.toggleWishlist(UserSession.userId, id);
    if (!mounted) return;
    setState(() {
      if (nowWished) {
        wishIds.add(id);
      } else {
        wishIds.remove(id);
      }
    });
    _toast(nowWished ? 'Saved to wishlist' : 'Removed from wishlist');
  }

  Future<void> _addToCart(Map<String, dynamic> book) async {
    await dbHelper.addToCart(UserSession.userId, asInt(book['id']));
    final cc = await dbHelper.getCartCount(UserSession.userId);
    if (!mounted) return;
    setState(() => cartCount = cc);
    _toast('${book['title']} added to cart',
        action: SnackBarAction(
            label: 'View cart',
            textColor: AppColors.marigold,
            onPressed: () => _open(const CartScreen())));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to see your cart and orders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await dbHelper.clearSavedSession();
    UserSession.logout();
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
  }

  void _clearFilters() {
    searchCtrl.clear();
    setState(() {
      query = '';
      genre = 'All';
      special = 'All';
      _applyFilters();
    });
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final bestsellers = allBooks.where((b) => asInt(b['isBestseller']) == 1).toList()
      ..sort((a, b) => asInt(b['popularity']).compareTo(asInt(a['popularity'])));

    return Scaffold(
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: loadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              titleSpacing: 0,
              title: Row(children: [
                const AppLogo(size: 32),
                const SizedBox(width: 10),
                Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kAppName, style: serif(20)),
                  Text('Hi, ${UserSession.name.split(' ').first}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400)),
                ],
              )),
              ]),
              actions: [
                IconButton(
                  tooltip: 'Wishlist',
                  icon: Badge(
                      isLabelVisible: wishIds.isNotEmpty,
                      label: Text('${wishIds.length}'),
                      backgroundColor: AppColors.rose,
                      child: const Icon(Icons.favorite_border)),
                  onPressed: () => _open(const WishlistScreen()),
                ),
                IconButton(
                  tooltip: 'Cart',
                  icon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      child: const Icon(Icons.shopping_bag_outlined)),
                  onPressed: () => _open(const CartScreen()),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(child: _searchBar()),
            if (loading)
              const SliverFillRemaining(
                  hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else ...[
              if (!isFiltering && bestsellers.isNotEmpty) ...[
                _sectionTitle('Bestsellers'),
                SliverToBoxAdapter(child: _bestsellerStrip(bestsellers)),
              ],
              SliverToBoxAdapter(child: _genreChips()),
              SliverToBoxAdapter(child: _filterRow()),
              if (filtered.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.56,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final book = filtered[i];
                        final id = asInt(book['id']);
                        return _BookCard(
                          book: book,
                          rating: ratings[id],
                          wished: wishIds.contains(id),
                          heroTag: 'grid_$id',
                          onTap: () => _open(BookDetailScreen(book: book, heroTag: 'grid_$id')),
                          onWish: () => _toggleWish(book),
                          onAdd: () => _addToCart(book),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search title, author or genre',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchCtrl.clear();
                    setState(() {
                      query = '';
                      _applyFilters();
                    });
                  }),
        ),
        onChanged: (val) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            setState(() {
              query = val.trim();
              _applyFilters();
            });
          });
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(t, style: serif(20)),
        ),
      );

  Widget _bestsellerStrip(List<Map<String, dynamic>> books) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final b = books[i];
          return GestureDetector(
            onTap: () => _open(BookDetailScreen(book: b)),
            child: SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 186,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: tint(Colors.black, 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10), child: BookCover(book: b)),
                  ),
                  const SizedBox(height: 8),
                  Text(b['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(rs(asDouble(b['price'])),
                      style: const TextStyle(color: AppColors.teal, fontSize: 12.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _genreChips() {
    final items = ['All', ...kGenres];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final selected = genre == items[i];
            return ChoiceChip(
              label: Text(items[i]),
              selected: selected,
              labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w500),
              onSelected: (_) => setState(() {
                genre = items[i];
                _applyFilters();
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _filterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in specials)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: special == s,
                        selectedColor: AppColors.marigold,
                        labelStyle: const TextStyle(
                            color: AppColors.ink, fontWeight: FontWeight.w500, fontSize: 13),
                        onSelected: (_) => setState(() {
                          special = s;
                          _applyFilters();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.swap_vert),
            onSelected: (v) => setState(() {
              sortBy = v;
              _applyFilters();
            }),
            itemBuilder: (ctx) => [
              for (final o in sortOptions)
                CheckedPopupMenuItem<String>(value: o, checked: sortBy == o, child: Text(o)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text('No books match your search', style: serif(18)),
          const SizedBox(height: 6),
          const Text('Try a different word or clear the filters.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters')),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final name = UserSession.name;
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.tealDark, AppColors.teal]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.marigold,
                  child: Text(initialsOf(name),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                const SizedBox(height: 12),
                Text(name, style: serif(18, color: Colors.white)),
                const SizedBox(height: 2),
                Text((UserSession.currentUser?['email'] ?? '').toString(),
                    style: TextStyle(color: tint(Colors.white, 0.8), fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Catalog'),
                    onTap: () => Navigator.pop(context)),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile and orders'),
                  onTap: () {
                    Navigator.pop(context);
                    _open(const ProfileScreen());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Wishlist'),
                  onTap: () {
                    Navigator.pop(context);
                    _open(const WishlistScreen());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('Cart'),
                  onTap: () {
                    Navigator.pop(context);
                    _open(const CartScreen());
                  },
                ),
                if (UserSession.isAdmin) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize_outlined, color: AppColors.rose),
                    title: const Text('Admin panel',
                        style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _open(const AdminScreen());
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final Map<String, dynamic>? rating;
  final bool wished;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback onWish;
  final VoidCallback onAdd;

  const _BookCard({
    required this.book,
    required this.rating,
    required this.wished,
    required this.heroTag,
    required this.onTap,
    required this.onWish,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isBest = asInt(book['isBestseller']) == 1;
    final isNew = asInt(book['isNewArrival']) == 1;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: heroTag, child: BookCover(book: book)),
                    if (isBest || isNew)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: isBest ? AppColors.marigold : AppColors.teal,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(isBest ? 'Bestseller' : 'New',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isBest ? AppColors.ink : Colors.white)),
                        ),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: onWish,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: tint(Colors.white, 0.92), shape: BoxShape.circle),
                          child: Icon(wished ? Icons.favorite : Icons.favorite_border,
                              size: 19, color: wished ? AppColors.rose : AppColors.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: serif(14.5)),
                    const SizedBox(height: 2),
                    Text(book['author'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.marigold),
                        const SizedBox(width: 2),
                        Text(
                            rating == null
                                ? 'No reviews'
                                : asDouble(rating!['avg']).toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(rs(asDouble(book['price'])),
                              style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5)),
                        ),
                        IconButton.filled(
                          tooltip: 'Add to cart',
                          onPressed: onAdd,
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.add_shopping_cart),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
