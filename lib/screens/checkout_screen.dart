import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double delivery;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.subtotal,
    required this.delivery,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _Pay {
  final String name;
  final String hint;
  final IconData icon;
  const _Pay(this.name, this.hint, this.icon);
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final DBHelper dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  final TextEditingController noteCtrl = TextEditingController();

  String payment = 'Cash on Delivery';
  bool saveToProfile = true;
  bool placing = false;

  static const List<_Pay> payments = [
    _Pay('Cash on Delivery', 'Pay when your books arrive', Icons.payments_outlined),
    _Pay('Credit Card', 'Our team confirms the payment before dispatch', Icons.credit_card),
    _Pay('EasyPaisa / JazzCash', 'Our team shares the account details by phone', Icons.phone_android),
  ];

  @override
  void initState() {
    super.initState();
    final u = UserSession.currentUser ?? {};
    nameCtrl = TextEditingController(text: (u['name'] ?? '').toString());
    phoneCtrl = TextEditingController(text: (u['phone'] ?? '').toString());
    addressCtrl = TextEditingController(text: (u['address'] ?? '').toString());
    final pm = (u['paymentMethod'] ?? '').toString();
    if (payments.any((p) => p.name == pm)) payment = pm;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    if (placing || !_formKey.currentState!.validate()) return;
    setState(() => placing = true);
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final summary =
        widget.items.map((i) => '${i['title']} x${asInt(i['quantity'])}').join(', ');
    try {
      final orderId = await dbHelper.checkout(UserSession.userId, {
        'userId': UserSession.userId,
        'totalAmount': widget.total,
        'shippingAddress': address,
        'paymentMethod': payment,
        'status': 'Pending',
        'orderDate': DateTime.now().toString().substring(0, 16),
        'itemsSummary': summary,
        'customerName': name,
        'phone': phone,
        'note': noteCtrl.text.trim(),
      });
      if (saveToProfile) {
        final updated = <String, dynamic>{
          'name': name,
          'phone': phone,
          'address': address,
          'paymentMethod': payment,
        };
        await dbHelper.updateProfile(UserSession.userId, updated);
        UserSession.currentUser = {...?UserSession.currentUser, ...updated};
      }
      if (!mounted) return;
      setState(() => placing = false);
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E8B57), size: 52),
          title: Text('Order #$orderId placed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thank you, ${name.split(' ').first}!',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _line(Icons.person_outline, name),
              _line(Icons.phone_outlined, phone),
              _line(Icons.location_on_outlined, address),
              _line(Icons.payments_outlined, '$payment  |  ${rs(widget.total)}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'orders'), child: const Text('Track order')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'browse'), child: const Text('Keep browsing')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, choice ?? 'browse');
    } catch (e) {
      if (!mounted) return;
      setState(() => placing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not place the order: $e')));
    }
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: FilledButton(
            onPressed: placing ? null : _place,
            child: placing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('Place order  |  ${rs(widget.total)}'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Delivery details', style: serif(18)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Enter the name for this order' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                        ? 'Enter a phone number we can call'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Delivery address',
                        hintText: 'House / street, area, city',
                        prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => (v == null || v.trim().length < 8)
                        ? 'Enter the full delivery address'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Note for the courier (optional)',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                  ),
                  const SizedBox(height: 22),
                  Text('Payment method', style: serif(18)),
                  const SizedBox(height: 10),
                  for (final p in payments) _payTile(p),
                  const SizedBox(height: 22),
                  Text('Order summary', style: serif(18)),
                  const SizedBox(height: 10),
                  _summaryCard(),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.teal,
                    value: saveToProfile,
                    onChanged: (v) => setState(() => saveToProfile = v ?? false),
                    title: const Text('Save these details to my profile',
                        style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payTile(_Pay p) {
    final selected = payment == p.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => payment = p.name),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? tint(AppColors.teal, 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.teal : AppColors.line, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(p.icon, color: selected ? AppColors.teal : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(p.hint, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.teal : AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    Widget row(String l, String r, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                  child: Text(l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                          fontSize: bold ? 16 : 14,
                          color: bold ? AppColors.ink : AppColors.muted))),
              Text(r,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      fontSize: bold ? 17 : 14,
                      color: color ?? (bold ? AppColors.teal : AppColors.ink))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (final i in widget.items)
            row('${i['title']}  x${asInt(i['quantity'])}',
                rs(asDouble(i['price']) * asInt(i['quantity']))),
          const Divider(height: 18),
          row('Subtotal', rs(widget.subtotal)),
          row('Delivery', widget.delivery == 0 ? 'Free' : rs(widget.delivery),
              color: widget.delivery == 0 ? const Color(0xFF2E8B57) : null),
          const Divider(height: 18),
          row('Total', rs(widget.total), bold: true),
        ],
      ),
    );
  }
}
