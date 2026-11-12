import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';
import '../widgets/book_cover.dart';
import 'checkout_screen.dart';
import 'profile_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  double get subtotal =>
      items.fold<double>(0, (a, i) => a + asDouble(i['price']) * asInt(i['quantity']));
  double get delivery => (items.isEmpty || subtotal >= kFreeDeliveryAbove) ? 0 : kDeliveryFee;
  double get total => subtotal + delivery;
  @override
  void initState() {
    super.initState();
    loadCart();
  }

  Future<void> loadCart() async {
    final data = await dbHelper.getCartItems(UserSession.userId);
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _setQty(Map<String, dynamic> item, int qty) async {
    await dbHelper.updateCartQty(asInt(item['cartId']), qty);
    await loadCart();
  }

  Future<void> _goCheckout() async {
    if (items.isEmpty) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
            items: List<Map<String, dynamic>>.from(items),
            subtotal: subtotal,
            delivery: delivery,
            total: total),
      ),
    );
    if (!mounted) return;
    await loadCart();
    if (!mounted) return;
    if (result == 'orders') {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 1)));
    } else if (result == 'browse') {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _empty()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) => _itemTile(items[i]),
                      ),
                    ),
                    _summary(),
                  ],
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('Your cart is empty', style: serif(20)),
              const SizedBox(height: 6),
              const Text('Books you add will show up here.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Browse books')),
            ],
          ),
        ),
      );

  Widget _itemTile(Map<String, dynamic> item) {
    final qty = asInt(item['quantity']);
    return Dismissible(
      key: ValueKey('cart_${item['cartId']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: AppColors.rose, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => items.removeWhere((e) => e['cartId'] == item['cartId']));
        _setQty(item, 0);
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
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: BookCover(book: item)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: serif(15)),
                  const SizedBox(height: 2),
                  Text(item['author'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(rs(asDouble(item['price']) * qty),
                            style: const TextStyle(
                                color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _stepper(item, qty),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(Map<String, dynamic> item, int qty) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: qty == 1 ? 'Remove' : 'Decrease',
              visualDensity: VisualDensity.compact,
              icon: Icon(qty == 1 ? Icons.delete_outline : Icons.remove, size: 18),
              onPressed: () => _setQty(item, qty - 1),
            ),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: 'Increase',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => _setQty(item, qty + 1),
            ),
          ],
        ),
      );

  Widget _row(String l, String r, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: TextStyle(
                    fontSize: bold ? 17 : 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? AppColors.ink : AppColors.muted)),
            Text(r,
                style: TextStyle(
                    fontSize: bold ? 19 : 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: color ?? (bold ? AppColors.teal : AppColors.ink))),
          ],
        ),
      );

  Widget _summary() {
    final toFree = kFreeDeliveryAbove - subtotal;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: tint(Colors.black, 0.08), blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Subtotal', rs(subtotal)),
            _row('Delivery', delivery == 0 ? 'Free' : rs(delivery),
                color: delivery == 0 ? const Color(0xFF2E8B57) : null),
            if (toFree > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Add ${rs(toFree)} more for free delivery',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              ),
            const Divider(height: 16),
            _row('Total', rs(total), bold: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _goCheckout,
                child: Text('Checkout  |  ${rs(total)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
