import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DBHelper dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  String paymentMethod = 'Cash on Delivery';
  List<Map<String, dynamic>> myOrders = [];
  bool loadingOrders = true;
  bool saving = false;

  static const List<String> payments = ['Cash on Delivery', 'Credit Card', 'EasyPaisa / JazzCash'];

  @override
  void initState() {
    super.initState();
    final u = UserSession.currentUser ?? {};
    nameCtrl = TextEditingController(text: (u['name'] ?? '').toString());
    phoneCtrl = TextEditingController(text: (u['phone'] ?? '').toString());
    addressCtrl = TextEditingController(text: (u['address'] ?? '').toString());
    final pm = (u['paymentMethod'] ?? 'Cash on Delivery').toString();
    paymentMethod = payments.contains(pm) ? pm : 'Cash on Delivery';
    loadOrders();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  Future<void> loadOrders() async {
    final data = await dbHelper.getUserOrders(UserSession.userId);
    if (!mounted) return;
    setState(() {
      myOrders = data;
      loadingOrders = false;
    });
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final updated = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'paymentMethod': paymentMethod,
    };
    try {
      await dbHelper.updateProfile(UserSession.userId, updated);
      UserSession.currentUser = {...?UserSession.currentUser, ...updated};
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My account'),
          bottom: TabBar(
            labelColor: AppColors.teal,
            indicatorColor: AppColors.teal,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              const Tab(text: 'Profile'),
              Tab(text: 'Orders (${myOrders.length})'),
            ],
          ),
        ),
        body: TabBarView(children: [_profileTab(), _ordersTab()]),
      ),
    );
  }

  Widget _profileTab() {
    final email = (UserSession.currentUser?['email'] ?? '').toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.tealDark, AppColors.teal]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.marigold,
                        child: Text(initialsOf(nameCtrl.text),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(UserSession.name, style: serif(19, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(email,
                                style: TextStyle(color: tint(Colors.white, 0.8), fontSize: 13)),
                            if (UserSession.isAdmin)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.marigold,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text('Admin',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Personal and shipping details', style: serif(18)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) =>
                      (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                          ? 'Enter a valid phone number'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Shipping address',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Enter your delivery address' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                      labelText: 'Preferred payment method',
                      prefixIcon: Icon(Icons.payments_outlined)),
                  items: payments
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: saving ? null : saveProfile,
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _contact(Map<String, dynamic> o) {
    final n = (o['customerName'] ?? '').toString();
    final ph = (o['phone'] ?? '').toString();
    if (n.isEmpty) return '';
    return ph.isEmpty ? n : '$n, $ph';
  }

  Widget _ordersTab() {
    if (loadingOrders) return const Center(child: CircularProgressIndicator());
    if (myOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('No orders yet', style: serif(20)),
              const SizedBox(height: 6),
              const Text('Your orders will appear here once you check out.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myOrders.length,
        itemBuilder: (ctx, i) {
          final o = myOrders[i];
          final status = (o['status'] ?? 'Pending').toString();
          final summary = (o['itemsSummary'] ?? '').toString();
          final contact = _contact(o);
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
                    Expanded(child: Text('Order #${o['id']}', style: serif(16))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: tint(statusColor(status), 0.14),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor(status))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(o['orderDate'].toString(),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(summary, style: const TextStyle(height: 1.4)),
                ],
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Deliver to $contact',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(o['shippingAddress'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                    Text(rs(asDouble(o['totalAmount'])),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: AppColors.teal, fontSize: 15)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
