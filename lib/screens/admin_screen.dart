import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/theme.dart';
import '../widgets/book_cover.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String orderFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final b = await dbHelper.getBooks();
    final o = await dbHelper.getAllOrders();
    if (!mounted) return;
    setState(() {
      books = b;
      orders = o;
      loading = false;
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openForm([Map<String, dynamic>? book]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BookForm(book: book),
      ),
    );
    if (result == null) return;
    try {
      if (book == null) {
        await dbHelper.addBook(result);
        _toast('Book added');
      } else {
        await dbHelper.updateBook(asInt(book['id']), result);
        _toast('Book updated');
      }
      await loadData();
    } catch (e) {
      _toast('Could not save the book: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text(
            '"${book['title']}" will be removed from the catalog, and from every cart, wishlist and review list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await dbHelper.deleteBook(asInt(book['id']));
    await loadData();
    _toast('Book deleted');
  }

  Future<void> _setStatus(Map<String, dynamic> order, String status) async {
    await dbHelper.updateOrderStatus(asInt(order['id']), status);
    await loadData();
    _toast('Order #${order['id']} marked $status');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin panel'),
          bottom: const TabBar(
            labelColor: AppColors.teal,
            indicatorColor: AppColors.teal,
            unselectedLabelColor: AppColors.muted,
            tabs: [Tab(text: 'Overview'), Tab(text: 'Books'), Tab(text: 'Orders')],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_overview(), _booksTab(), _ordersTab()]),
      ),
    );
  }

  // ------------------------------------------------------------ overview
  Widget _overview() {
    final active = orders.where((o) => o['status'] != 'Cancelled');
    final revenue = active.fold<double>(0, (a, o) => a + asDouble(o['totalAmount']));
    final pending = orders.where((o) => o['status'] == 'Pending').length;
    final delivered = orders.where((o) => o['status'] == 'Delivered').length;

    Widget stat(IconData icon, String label, String value, Color color) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: tint(color, 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: serif(22))),
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ],
          ),
        );

    final recent = orders.take(4).toList();
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              stat(Icons.menu_book_outlined, 'Books in catalog', '${books.length}', AppColors.teal),
              stat(Icons.receipt_long_outlined, 'Total orders', '${orders.length}',
                  const Color(0xFF2F6F9E)),
              stat(Icons.hourglass_bottom, 'Pending orders', '$pending', const Color(0xFFD98A12)),
              stat(Icons.payments_outlined, 'Revenue', rs(revenue), const Color(0xFF2E8B57)),
            ],
          ),
          const SizedBox(height: 8),
          Text('$delivered of ${orders.length} orders delivered',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 20),
          Text('Latest orders', style: serif(18)),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Text('No orders yet.', style: TextStyle(color: AppColors.muted))
          else
            ...recent.map(_orderCard),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- books
  Widget _booksTab() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: books.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text('${books.length} books', style: serif(18))),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add book'),
                  ),
                ],
              ),
            );
          }
          final b = books[i - 1];
          return Container(
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
                  width: 46,
                  height: 68,
                  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: BookCover(book: b)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: serif(15)),
                      Text('${b['author']}  |  ${b['genre']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(rs(asDouble(b['price'])),
                          style: const TextStyle(
                              color: AppColors.teal, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openForm(b),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: AppColors.rose),
                  onPressed: () => _delete(b),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------- orders
  Widget _ordersTab() {
    final filters = ['All', ...kOrderStatuses];
    final shown = orderFilter == 'All'
        ? orders
        : orders.where((o) => o['status'] == orderFilter).toList();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final f = filters[i];
              final selected = orderFilter == f;
              final count =
                  f == 'All' ? orders.length : orders.where((o) => o['status'] == f).length;
              return ChoiceChip(
                label: Text('$f ($count)'),
                selected: selected,
                labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w500),
                onSelected: (_) => setState(() => orderFilter = f),
              );
            },
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(
                  child: Text('No orders in this view.', style: TextStyle(color: AppColors.muted)))
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: shown.length,
                    itemBuilder: (ctx, i) => _orderCard(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'Pending').toString();
    final summary = (o['itemsSummary'] ?? '').toString();
    final customer = (o['buyerName'] ?? 'Customer #${o['userId']}').toString();
    final phone = (o['phone'] ?? '').toString();
    final note = (o['note'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Order #${o['id']}  |  $customer', style: serif(15))),
              Text(rs(asDouble(o['totalAmount'])),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal)),
            ],
          ),
          const SizedBox(height: 4),
          Text(o['orderDate'].toString(),
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(height: 1.4)),
          ],
          const SizedBox(height: 8),
          if (phone.isNotEmpty)
            Text('Phone: $phone', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${o['shippingAddress']}  |  ${o['paymentMethod']}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          if (note.isNotEmpty)
            Text('Note: $note', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: tint(statusColor(status), 0.14),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: statusColor(status))),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Change status',
                onSelected: (s) => _setStatus(o, s),
                itemBuilder: (ctx) => [
                  for (final s in kOrderStatuses)
                    CheckedPopupMenuItem<String>(value: s, checked: s == status, child: Text(s)),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Update status',
                          style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_drop_down, color: AppColors.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit form shown in a bottom sheet. Pops with the book map to save.
class _BookForm extends StatefulWidget {
  final Map<String, dynamic>? book;
  const _BookForm({this.book});

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleCtrl;
  late final TextEditingController authorCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController coverCtrl;
  late final TextEditingController descCtrl;
  late String genre;
  late bool bestseller;
  late bool newArrival;

  bool get editing => widget.book != null;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    titleCtrl = TextEditingController(text: b?['title']?.toString() ?? '');
    authorCtrl = TextEditingController(text: b?['author']?.toString() ?? '');
    priceCtrl = TextEditingController(
        text: b == null ? '' : asDouble(b['price']).round().toString());
    coverCtrl = TextEditingController(text: b?['coverUrl']?.toString() ?? '');
    descCtrl = TextEditingController(text: b?['description']?.toString() ?? '');
    final g = b?['genre']?.toString() ?? kGenres.first;
    genre = kGenres.contains(g) ? g : kGenres.first;
    bestseller = asInt(b?['isBestseller']) == 1;
    newArrival = b == null ? true : asInt(b['isNewArrival']) == 1;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    authorCtrl.dispose();
    priceCtrl.dispose();
    coverCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final b = widget.book;
    Navigator.pop(context, {
      'title': titleCtrl.text.trim(),
      'author': authorCtrl.text.trim(),
      'genre': genre,
      'description': descCtrl.text.trim().isEmpty
          ? 'A new addition to our catalog.'
          : descCtrl.text.trim(),
      'coverUrl': coverCtrl.text.trim(),
      'price': double.parse(priceCtrl.text.trim()),
      'popularity': b == null ? 80 : asInt(b['popularity']),
      'releaseDate': b == null
          ? DateTime.now().toIso8601String().substring(0, 10)
          : b['releaseDate'].toString(),
      'isBestseller': bestseller ? 1 : 0,
      'isNewArrival': newArrival ? 1 : 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? 'Edit book' : 'Add a book', style: serif(20)),
              const SizedBox(height: 14),
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: authorCtrl,
                decoration: const InputDecoration(labelText: 'Author'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the author' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: genre,
                      decoration: const InputDecoration(labelText: 'Genre'),
                      items: kGenres
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => genre = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (Rs.)'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return (n == null || n <= 0) ? 'Enter a price' : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: coverCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Cover image link (optional)',
                    helperText: 'Leave empty to use a designed cover'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bestseller'),
                value: bestseller,
                onChanged: (v) => setState(() => bestseller = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('New arrival'),
                value: newArrival,
                onChanged: (v) => setState(() => newArrival = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                        onPressed: _save,
                        child: Text(editing ? 'Save changes' : 'Add book')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
