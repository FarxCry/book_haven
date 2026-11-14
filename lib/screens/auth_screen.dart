import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../utils/session.dart';
import '../utils/theme.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final DBHelper dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  bool isLogin = true;
  bool hidePass = true;
  bool busy = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  void showMsg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // Quick login buttons are protected by a PIN (no credentials are filled in).
  static const Map<String, String> _quickPins = {'user': '420', 'admin': '5595'};
  static const Map<String, List<String>> _quickAccounts = {
    'user': ['user@gmail.com', 'user123'],
    'admin': ['admin@bookstore.com', 'admin123'],
  };

  Future<void> quickLogin(String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PinDialog(
        title: role == 'admin' ? 'Admin PIN' : 'Customer PIN',
        expectedPin: _quickPins[role]!,
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      final acc = _quickAccounts[role]!;
      final user = await dbHelper.loginUser(acc[0], acc[1]);
      if (user == null) {
        showMsg('This quick login account is not available.');
        return;
      }
      UserSession.currentUser = user;
      await dbHelper.saveSession(asInt(user['id']));
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      showMsg('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text;
      if (!isLogin) {
        try {
          await dbHelper.registerUser({
            'name': nameCtrl.text.trim(),
            'email': email,
            'password': pass,
            'phone': phoneCtrl.text.trim(),
            'address': addressCtrl.text.trim(),
            'paymentMethod': 'Cash on Delivery',
            'role': 'user',
          });
        } catch (_) {
          showMsg('This email is already registered. Try logging in.');
          return;
        }
      }
      final user = await dbHelper.loginUser(email, pass);
      if (user == null) {
        showMsg('Email or password is incorrect.');
        return;
      }
      UserSession.currentUser = user;
      await dbHelper.saveSession(asInt(user['id']));
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      showMsg('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void forgotPassword() {
    final fEmail = TextEditingController(text: emailCtrl.text.trim());
    final fPhone = TextEditingController();
    final fPass = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email and the phone number you registered with.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              TextField(
                  controller: fEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: fPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Registered phone')),
              const SizedBox(height: 10),
              TextField(
                  controller: fPass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password (6+ characters)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (fPass.text.length < 6) {
                showMsg('New password needs at least 6 characters.');
                return;
              }
              final n = await dbHelper.resetPassword(fEmail.text, fPhone.text, fPass.text);
              if (ctx.mounted) Navigator.pop(ctx);
              showMsg(n > 0
                  ? 'Password changed. You can log in now.'
                  : 'Email and phone number do not match any account.');
            },
            child: const Text('Reset password'),
          ),
        ],
      ),
    ).then((_) {
      fEmail.dispose();
      fPhone.dispose();
      fPass.dispose();
    });
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealDark, AppColors.teal]),
      ),
      child: Column(
        children: [
          const AppLogo(size: 84, light: true),
          const SizedBox(height: 16),
          Text(kAppName, style: serif(32, color: Colors.white)),
          const SizedBox(height: 6),
          Text(kTagline,
              textAlign: TextAlign.center,
              style: TextStyle(color: tint(Colors.white, 0.8), fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _hero(),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: tint(Colors.black, 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(isLogin ? 'Welcome back' : 'Create your account',
                              style: serif(22)),
                          const SizedBox(height: 4),
                          Text(
                              isLogin
                                  ? 'Log in to see your cart, wishlist and orders.'
                                  : 'It takes less than a minute.',
                              style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 18),
                          if (!isLogin) ...[
                            TextFormField(
                              controller: nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                              validator: (v) {
                                final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                return d.length < 10 ? 'Enter a valid phone number' : null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: addressCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Shipping address',
                                  prefixIcon: Icon(Icons.location_on_outlined)),
                              validator: (v) => (v == null || v.trim().length < 5)
                                  ? 'Enter your delivery address'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                            validator: (v) =>
                                _emailRe.hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passCtrl,
                            obscureText: hidePass,
                            onFieldSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(hidePass ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => hidePass = !hidePass),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Use at least 6 characters'
                                : null,
                          ),
                          if (isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                  onPressed: forgotPassword,
                                  child: const Text('Forgot password?')),
                            )
                          else
                            const SizedBox(height: 12),
                          FilledButton(
                            onPressed: busy ? null : submit,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: Colors.white))
                                : Text(isLogin ? 'Log in' : 'Create account'),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() => isLogin = !isLogin),
                            child: Text(isLogin
                                ? 'New here? Create an account'
                                : 'Already registered? Log in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isLogin)
              Transform.translate(
                offset: const Offset(0, -24),
                child: Column(
                  children: [
                    const Text('Quick login (PIN required)',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: const Text('Customer'),
                          onPressed: busy ? null : () => quickLogin('user'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.admin_panel_settings, size: 16),
                          label: const Text('Admin'),
                          onPressed: busy ? null : () => quickLogin('admin'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a numeric PIN. Pops true when the PIN is correct.
class _PinDialog extends StatefulWidget {
  final String title;
  final String expectedPin;
  const _PinDialog({required this.title, required this.expectedPin});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final TextEditingController ctrl = TextEditingController();
  String? error;
  int attempts = 0;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (ctrl.text.trim() == widget.expectedPin) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      attempts++;
      error = attempts >= 3 ? 'Incorrect PIN. Please try again later.' : 'Incorrect PIN';
      ctrl.clear();
    });
    if (attempts >= 3) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pop(context, false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline, color: AppColors.teal),
      title: Text(widget.title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        enabled: attempts < 3,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 6),
        decoration: InputDecoration(counterText: '', hintText: 'Enter PIN', errorText: error),
        onSubmitted: (_) => _check(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: attempts < 3 ? _check : null, child: const Text('Continue')),
      ],
    );
  }
}
