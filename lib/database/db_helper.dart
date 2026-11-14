import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'seed_books.dart';

typedef Rows = List>;

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final path = kIsWeb
        ? '/bookstore_eproject.db'
        : join(await getDatabasesPath(), 'bookstore_eproject.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, email TEXT UNIQUE, password TEXT, phone TEXT,
        address TEXT, paymentMethod TEXT, role TEXT
      )''');
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT, author TEXT, genre TEXT, description TEXT, coverUrl TEXT,
        price REAL, popularity INTEGER, releaseDate TEXT,
        isBestseller INTEGER, isNewArrival INTEGER
      )''');
    await db.execute('''
      CREATE TABLE cart (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER, bookId INTEGER, quantity INTEGER
      )''');
    await db.execute('''
      CREATE TABLE wishlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER, bookId INTEGER
      )''');
    await db.execute('''
      CREATE TABLE reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER, userName TEXT, rating REAL, comment TEXT, likes INTEGER
      )''');
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER, totalAmount REAL, shippingAddress TEXT,
        paymentMethod TEXT, status TEXT, orderDate TEXT, itemsSummary TEXT,
        customerName TEXT, phone TEXT, note TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS active_session (
        id INTEGER PRIMARY KEY,
        userId INTEGER
      )''');

    await db.insert('users', {
      'name': 'Admin Manager',
      'email': 'admin@bookstore.com',
      'password': 'admin123',
      'phone': '03001234567',
      'address': 'Main Branch, Karachi',
      'paymentMethod': 'Cash on Delivery',
      'role': 'admin'
    });
    await db.insert('users', {
      'name': 'Muhammad Usman',
      'email': 'user@gmail.com',
      'password': 'user123',
      'phone': '03120000000',
      'address': 'Korangi, Karachi',
      'paymentMethod': 'Cash on Delivery',
      'role': 'user'
    });
    await _seedBooks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      for (final col in ['itemsSummary', 'customerName', 'phone', 'note']) {
        try {
          await db.execute('ALTER TABLE orders ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }
    if (oldVersion < 4) {
      await db.execute('CREATE TABLE IF NOT EXISTS active_session (id INTEGER PRIMARY KEY, userId INTEGER)');
      await db.delete('cart');
      await db.delete('wishlist');
      await db.delete('reviews');
      await db.delete('books');
      await _seedBooks(db);
    }
  }

  Future<void> _seedBooks(Database db) async {
    final ids = <int>[];
    for (final book in seedBooks) {
      ids.add(await db.insert('books', book));
    }
    final reviews = <List<Object>>[
      [0, 'Ali Raza', 5.0, 'Best book for software engineering students!', 4],
      [0, 'Sara Khan', 4.0, 'Clear examples. Some chapters are dense but worth it.', 2],
      [6, 'Hira Malik', 5.0, 'Short, calm and inspiring. I finished it in two evenings.', 3],
      [7, 'Bilal Ahmed', 5.0, 'Still unsettlingly relevant.', 1],
      [14, 'Usman Tariq', 5.0, 'Small changes really do add up. Practical and easy to follow.', 6],
      [14, 'Ayesha Noor', 4.0, 'Great ideas, I wish the middle was a bit shorter.', 1],
      [19, 'Fatima Zahra', 5.0, 'Changed how I think about saving and risk.', 2],
      [24, 'Hamza Sheikh', 5.0, 'Makes history feel like one connected story.', 0],
    ];
    for (final r in reviews) {
      final idx = r[0] as int;
      if (idx >= ids.length) continue;
      await db.insert('reviews', {
        'bookId': ids[idx],
        'userName': r[1],
        'rating': r[2],
        'comment': r[3],
        'likes': r[4],
      });
    }
  }

  Rows _rows(List> r) => List>.from(r);

  // --- PERSISTENT SESSION ---
  Future<void> saveSession(int userId) async {
    final d = await db;
    await d.execute('CREATE TABLE IF NOT EXISTS active_session (id INTEGER PRIMARY KEY, userId INTEGER)');
    await d.delete('active_session');
    await d.insert('active_session', {'id': 1, 'userId': userId});
  }

  Future?> getSavedSessionUser() async {
    final d = await db;
    await d.execute('CREATE TABLE IF NOT EXISTS active_session (id INTEGER PRIMARY KEY, userId INTEGER)');
    final s = await d.query('active_session', limit: 1);
    if (s.isEmpty) return null;
    final uid = (s.first['userId'] as num).toInt();
    final u = await d.query('users', where: 'id = ?', whereArgs: [uid], limit: 1);
    return u.isEmpty ? null : Map<String, dynamic>.from(u.first);
  }

  Future<void> clearSavedSession() async {
    final d = await db;
    await d.execute('CREATE TABLE IF NOT EXISTS active_session (id INTEGER PRIMARY KEY, userId INTEGER)');
    await d.delete('active_session');
  }

  // --- AUTH & PROFILE ---
  Future?> loginUser(String email, String password) async {
    final d = await db;
    final res = await d.query('users',
        where: 'LOWER(email) = ? AND password = ?',
        whereArgs: [email.trim().toLowerCase(), password]);
    return res.isEmpty ? null : Map<String, dynamic>.from(res.first);
  }

  Future<int> registerUser(Map<String, dynamic> userData) async {
    final d = await db;
    final data = Map<String, dynamic>.from(userData);
    data['email'] = (data['email'] ?? '').toString().trim().toLowerCase();
    return d.insert('users', data);
  }

  Future<int> resetPassword(String email, String phone, String newPassword) async {
    final d = await db;
    return d.update('users', {'password': newPassword},
        where: 'LOWER(email) = ? AND phone = ?',
        whereArgs: [email.trim().toLowerCase(), phone.trim()]);
  }

  Future<int> updateProfile(int id, Map<String, dynamic> data) async {
    final d = await db;
    return d.update('users', data, where: 'id = ?', whereArgs: [id]);
  }

  // --- BOOKS ---
  Future<Rows> getBooks() async {
    final d = await db;
    return _rows(await d.query('books'));
  }

  Future<int> addBook(Map<String, dynamic> book) async {
    final d = await db;
    return d.insert('books', book);
  }

  Future<int> updateBook(int id, Map<String, dynamic> book) async {
    final d = await db;
    return d.update('books', book, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBook(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('cart', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('wishlist', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('reviews', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- CART ---
  Future<void> addToCart(int userId, int bookId) async {
    final d = await db;
    final check = await d.query('cart',
        where: 'userId = ? AND bookId = ?', whereArgs: [userId, bookId]);
    if (check.isNotEmpty) {
      final qty = (check.first['quantity'] as num).toInt();
      await d.update('cart', {'quantity': qty + 1},
          where: 'id = ?', whereArgs: [check.first['id']]);
    } else {
      await d.insert('cart', {'userId': userId, 'bookId': bookId, 'quantity': 1});
    }
  }

  Future<Rows> getCartItems(int userId) async {
    final d = await db;
    return _rows(await d.rawQuery('''
      SELECT cart.id AS cartId, cart.quantity, books.*
      FROM cart INNER JOIN books ON cart.bookId = books.id
      WHERE cart.userId = ?
      ORDER BY cart.id DESC
    ''', [userId]));
  }

  Future<int> getCartCount(int userId) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS c FROM cart WHERE userId = ?', [userId]);
    return (r.first['c'] as num).toInt();
  }

  Future<void> updateCartQty(int cartId, int newQty) async {
    final d = await db;
    if (newQty <= 0) {
      await d.delete('cart', where: 'id = ?', whereArgs: [cartId]);
    } else {
      await d.update('cart', {'quantity': newQty}, where: 'id = ?', whereArgs: [cartId]);
    }
  }

  // --- WISHLIST ---
  Future<bool> toggleWishlist(int userId, int bookId) async {
    final d = await db;
    final check = await d.query('wishlist',
        where: 'userId = ? AND bookId = ?', whereArgs: [userId, bookId]);
    if (check.isNotEmpty) {
      await d.delete('wishlist', where: 'id = ?', whereArgs: [check.first['id']]);
      return false;
    }
    await d.insert('wishlist', {'userId': userId, 'bookId': bookId});
    return true;
  }

  Future<bool> isInWishlist(int userId, int bookId) async {
    final d = await db;
    final r = await d.query('wishlist',
        where: 'userId = ? AND bookId = ?', whereArgs: [userId, bookId], limit: 1);
    return r.isNotEmpty;
  }

  Future<Set<int>> getWishlistIds(int userId) async {
    final d = await db;
    final r = await d.query('wishlist',
        columns: ['bookId'], where: 'userId = ?', whereArgs: [userId]);
    return r.map((e) => (e['bookId'] as num).toInt()).toSet();
  }

  Future<Rows> getWishlist(int userId) async {
    final d = await db;
    return _rows(await d.rawQuery('''
      SELECT wishlist.id AS wishId, books.*
      FROM wishlist INNER JOIN books ON wishlist.bookId = books.id
      WHERE wishlist.userId = ?
      ORDER BY wishlist.id DESC
    ''', [userId]));
  }

  // --- REVIEWS ---
  Future<Rows> getReviews(int bookId) async {
    final d = await db;
    return _rows(await d.query('reviews',
        where: 'bookId = ?', whereArgs: [bookId], orderBy: 'id DESC'));
  }

  Future>> getRatingsMap() async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT bookId, AVG(rating) AS avg, COUNT(*) AS cnt FROM reviews GROUP BY bookId');
    return {
      for (final row in r)
        (row['bookId'] as num).toInt(): {
          'avg': (row['avg'] as num).toDouble(),
          'count': (row['cnt'] as num).toInt(),
        }
    };
  }

  Future<int> addReview(Map<String, dynamic> review) async {
    final d = await db;
    return d.insert('reviews', review);
  }

  Future<void> likeReview(int reviewId) async {
    final d = await db;
    await d.rawUpdate('UPDATE reviews SET likes = COALESCE(likes, 0) + 1 WHERE id = ?', [reviewId]);
  }

  // --- ORDERS ---
  Future<int> checkout(int userId, Map<String, dynamic> order) async {
    final d = await db;
    return d.transaction((txn) async {
      final id = await txn.insert('orders', order);
      await txn.delete('cart', where: 'userId = ?', whereArgs: [userId]);
      return id;
    });
  }

  Future<Rows> getUserOrders(int userId) async {
    final d = await db;
    return _rows(await d.query('orders',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'id DESC'));
  }

  Future<Rows> getAllOrders() async {
    final d = await db;
    return _rows(await d.rawQuery('''
      SELECT orders.*, COALESCE(NULLIF(orders.customerName, ''), users.name) AS buyerName
      FROM orders LEFT JOIN users ON users.id = orders.userId
      ORDER BY orders.id DESC
    '''));
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final d = await db;
    await d.update('orders', {'status': status}, where: 'id = ?', whereArgs: [orderId]);
  }
}
