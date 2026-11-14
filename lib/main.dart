import 'package:flutter/material.dart';
import 'database/db_factory.dart';
import 'database/db_helper.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'utils/session.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDbFactory();
  final savedUser = await DBHelper().getSavedSessionUser();
  if (savedUser != null) {
    UserSession.currentUser = savedUser;
  }
  runApp(const BookStoreApp());
}

class BookStoreApp extends StatelessWidget {
  const BookStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: UserSession.currentUser != null
          ? const HomeScreen()
          : const AuthScreen(),
    );
  }
}
