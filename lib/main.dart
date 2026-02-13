// CAMPUS DELIVERY — MULTI-SERVICE + LIVE MAP + UPI (no internet images)
import 'dart:io' show Platform;

import 'ui/payment_qr_screen.dart';
import 'services/payment_service.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// === Firebase ===
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// === Auth UI ===
import 'auth/auth_gate.dart';
import 'auth/screens/sign_in.dart';
import 'auth/screens/sign_up.dart';
import 'auth/screens/verify_otp.dart';
import 'auth/screens/verify_email.dart';

// Core
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

import 'firebase_options.dart';

// === New (orders + settings) ===
import 'models/order.dart';
import 'services/order_service.dart';
import 'models/user_settings.dart';
import 'services/user_settings_service.dart';

double bottomInsetPadding(BuildContext c, {double extra = 80}) =>
    MediaQuery.of(c).viewInsets.bottom + extra;

/// --------------------------------------------------------------
/// Lightweight bootstrapper used by the splash to hold ~2s
/// --------------------------------------------------------------
class AppBootstrapper {
  static Future<void>? _once;
  static Future<void> ensureInitialized() {
    _once ??= _run();
    return _once!;
  }

  static Future<void> _run() async {
    // Simulate warm-up (fonts/cache).
    await Future.delayed(const Duration(milliseconds: 2200));
  }
}

// ===================== MAIN =====================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Firebase App Check (skip on desktop)
  try {
    if (kIsWeb) {
      const siteKey = 'YOUR_RECAPTCHA_V3_SITE_KEY';
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(siteKey),
      );
    } else if (Platform.isAndroid) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    } else if (Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.debug,
      );
    } else {
      debugPrint('Firebase App Check not supported on this platform. Skipping activate().');
    }
  } catch (e) {
    debugPrint('App Check activation skipped/failed: $e');
  }

  runApp(const ProviderScope(child: App()));
}

// ===================== ROUTER =====================
final _router = GoRouter(
  initialLocation: '/splash', // 👈 start at splash
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/', builder: (_, __) => const AuthGate(child: Shell())),
    GoRoute(
      path: '/vendor/:id',
      builder: (_, s) => VendorScreen(vendorId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
    GoRoute(path: '/track', builder: (_, __) => const TrackScreen()),

    // Auth routes
    GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
    GoRoute(path: '/otp', builder: (_, __) => const VerifyOtpScreen()),
  ],
);

// ===================== APP =====================
class App extends ConsumerWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseSeed = const Color(0xFFFF7A00);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Campus Delivery',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: baseSeed, brightness: Brightness.light),
        visualDensity: VisualDensity.compact,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          elevation: 2,
          indicatorShape: StadiumBorder(),
        ),
      ),
      routerConfig: _router,
    );
  }
}

/// ===================== SPLASH (2.2s with pop-in animation) =====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
    ..forward();

  @override
  void initState() {
    super.initState();
    AppBootstrapper.ensureInitialized().whenComplete(() {
      if (!mounted) return;
      context.go('/'); // proceed; AuthGate takes over
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Scaffold(
      backgroundColor: const Color(0xFFFF7A00),
      body: Center(
        child: FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: .7, end: 1.0).animate(curve),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.local_shipping_rounded, size: 110, color: Colors.white),
                SizedBox(height: 14),
                Text(
                  'Campus Delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    fontSize: 22,
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------------------- MODELS ---------------------------- */
class Vendor {
  final String id, name, type;
  final IconData icon;
  final double rating;
  final int eta;
  final String offer;
  Vendor({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.rating,
    required this.eta,
    required this.offer,
  });
}

class MenuItem {
  final String id, vendorId, name, desc;
  final int price;
  final IconData icon;
  const MenuItem({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.desc,
    required this.price,
    required this.icon,
  });
}

/* ---------------------------- MOCK DATA ---------------------------- */
final vendors = [
  Vendor(
    id: 'v1',
    name: 'Hostel Canteen',
    type: 'Food',
    icon: Icons.restaurant_rounded,
    rating: 4.3,
    eta: 15,
    offer: '₹60 OFF • 20%',
  ),
  Vendor(
    id: 'v2',
    name: 'Laundry Express',
    type: 'Laundry',
    icon: Icons.local_laundry_service_rounded,
    rating: 4.5,
    eta: 40,
    offer: '10% OFF • First order',
  ),
  Vendor(
    id: 'v3',
    name: 'Parcel Pickup',
    type: 'Courier',
    icon: Icons.local_shipping_rounded,
    rating: 4.2,
    eta: 25,
    offer: '₹30 OFF • Flipkart/Amazon',
  ),
];

final menu = [
  const MenuItem(
    id: 'i1',
    vendorId: 'v1',
    name: 'Veg Thali',
    desc: 'Dal • Rice • Roti • Salad',
    price: 90,
    icon: Icons.rice_bowl_rounded,
  ),
  const MenuItem(
    id: 'i2',
    vendorId: 'v2',
    name: 'Wash & Fold (2 kg)',
    desc: '48h delivery • Eco detergents',
    price: 120,
    icon: Icons.local_laundry_service_rounded,
  ),
];

/* ---------------------------- CART ---------------------------- */
class CartLine {
  final MenuItem item;
  int qty;
  CartLine(this.item, this.qty);
}

class CartNotifier extends StateNotifier<List<CartLine>> {
  CartNotifier() : super([]);
  void add(MenuItem item) {
    final list = [...state];
    final i = list.indexWhere((e) => e.item.id == item.id);
    if (i == -1) {
      list.add(CartLine(item, 1));
    } else {
      list[i].qty++;
    }
    state = list;
  }

  void dec(MenuItem item) {
    final list = [...state];
    final i = list.indexWhere((e) => e.item.id == item.id);
    if (i != -1) {
      if (list[i].qty > 1) {
        list[i].qty--;
      } else {
        list.removeAt(i);
      }
      state = list;
    }
  }

  int get total => state.fold(0, (s, e) => s + e.item.price * e.qty);
}

final cartProvider =
StateNotifierProvider<CartNotifier, List<CartLine>>((ref) => CartNotifier());

final tabProvider = StateProvider<int>((ref) => 0);

/* ---------------------------- SHELL ---------------------------- */
class Shell extends ConsumerWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabProvider);
    final pages = [
      const HomeScreen(),
      const TrackScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

/* ---------------------------- HOME ---------------------------- */
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _card(BuildContext context, Vendor v, List<Color> grad) {
    return GestureDetector(
      onTap: () => context.push('/vendor/${v.id}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top visual
                Container(
                  height: constraints.maxHeight * 0.42,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'vendor:${v.id}',
                      child: Icon(v.icon, size: 52, color: Colors.white),
                    ),
                  ),
                ),

                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            v.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: Colors.black.withOpacity(.55)),
                            const SizedBox(width: 4),
                            Text('${v.eta} min', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(.65))),
                            const SizedBox(width: 8),
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(v.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Chip(
                            label: Text(v.offer, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.green.withOpacity(.10),
                            side: BorderSide.none,
                            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradients = [
      [const Color(0xFFFFB86C), const Color(0xFFFF7A00)],
      [const Color(0xFF7BC9FF), const Color(0xFF2F80ED)],
      [const Color(0xFF6EE7B7), const Color(0xFF10B981)],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: const [
            Text('Campus Delivery'),
            SizedBox(height: 2),
            Text('Everything on campus, fast', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Search canteen, laundry, courier…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onTap: () {
                  // (future) search
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: vendors.length,
                itemBuilder: (_, i) => _card(context, vendors[i], gradients[i % gradients.length]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------- VENDOR ---------------------------- */
class VendorScreen extends ConsumerWidget {
  final String vendorId;
  const VendorScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vendors.firstWhere((e) => e.id == vendorId);
    final items = menu.where((m) => m.vendorId == vendorId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(v.name)),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final it = items[i];

          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'vendor:${v.id}:item:${it.id}',
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(it.icon, color: Colors.orange.shade800, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          it.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.desc,
                          style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${it.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            ref.read(cartProvider.notifier).add(it);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${it.name} added'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cart'),
        backgroundColor: Colors.orange,
        label: const Text('Go to Cart'),
        icon: const Icon(Icons.shopping_cart),
      ),
    );
  }
}

/* ---------------------------- CART / CHECKOUT ---------------------------- */
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final total = lines.fold(0, (s, e) => s + e.item.price * e.qty);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Your Cart')),
      body: SafeArea(
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInsetPadding(context)),
          itemCount: lines.isEmpty ? 1 : lines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (lines.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('Cart is empty')),
              );
            }
            final c = lines[i];
            return Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(c.item.icon, color: Colors.orange.shade800),
                ),
                title: Text(c.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('₹${c.item.price}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => ref.read(cartProvider.notifier).dec(c.item),
                  ),
                  Text('${c.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => ref.read(cartProvider.notifier).add(c.item),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total • ₹$total',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              FilledButton(
                onPressed: total == 0 ? null : () => context.push('/checkout'),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  Future<void> _launchNetBankDemo(BuildContext context, int amount) async {
    final uri = Uri.parse('https://razorpay.com/demo/pay?amount=$amount');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open demo bank page')),
        );
      }
    }
  }

  List<OrderItem> _cartToOrderItems(List<CartLine> lines) => lines
      .map((c) => OrderItem(
    id: c.item.id,
    name: c.item.name,
    qty: c.qty,
    price: c.item.price,
  ))
      .toList();

  /// Try UPI deep link; if no handler, fall back to in-app QR.
  Future<void> _openUpiAppOrQr({
    required BuildContext context,
    required String orderId,
    required int amount,
    required String vpa,
    required String payeeName,
  }) async {
    // Build encoded UPI URI
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: <String, String>{
        'pa': vpa,                      // virtual payment address
        'pn': payeeName,                // payee name
        'am': amount.toString(),        // amount
        'cu': 'INR',                    // currency
        'tn': 'Campus Order #$orderId', // note
        'tr': orderId,                  // transaction ref
      },
    );

    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        // Couldn’t launch even though handler exists – show QR
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentQrScreen(
            paymentId: orderId, // you can pass paymentId if different
            orderId: orderId,
            amount: amount,
          ),
        ));
      }
    } else {
      // No UPI app installed – show QR
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentQrScreen(
            paymentId: orderId, // or your payment doc id from PaymentService
            orderId: orderId,
            amount: amount,
          ),
        ));
      }
    }
  }

  Future<void> _placeOrderAndPay(
      BuildContext context,
      WidgetRef ref,
      String paymentMethod,
      ) async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) return;

    final items = _cartToOrderItems(lines);
    final amount = lines.fold(0, (s, e) => s + e.item.price * e.qty);
    final vendorId = lines.first.item.vendorId;
    final vendorName = vendors.firstWhere((v) => v.id == vendorId).name;

    try {
      // Create order (paymentStatus defaults to 'pending' server-side)
      final orderId = await OrderService().createOrder(
        vendorId: vendorId,
        vendorName: vendorName,
        items: items,
        amount: amount,
        paymentMethod: paymentMethod,
      );

      if (paymentMethod == 'cash') {
        // In your later flow, delivery agent / vendor confirms payment in admin app.
        await OrderService().markPaymentSuccess(orderId);
        ref.read(cartProvider.notifier).state = [];
        if (context.mounted) context.pushReplacement('/track');
        return;
      }

      if (paymentMethod == 'upi') {
        // Create intent record (optional but useful for polling/status)
        final payId = await PaymentService().createIntent(
          orderId: orderId,
          amount: amount,
          upiId: 'campusbot@upi',
          payeeName: 'CampusBot',
        );

        // Try deep-link first, then fallback to QR
        await _openUpiAppOrQr(
          context: context,
          orderId: payId, // use payment doc id as transaction ref
          amount: amount,
          vpa: 'campusbot@upi',
          payeeName: 'CampusBot',
        );
        return;
      }

      // NetBank demo
      await _launchNetBankDemo(context, amount);
      if (context.mounted) context.pushReplacement('/track');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment start failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final total = lines.fold(0, (s, e) => s + e.item.price * e.qty);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Mini order summary
          if (lines.isNotEmpty) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, size: 18),
                        const SizedBox(width: 6),
                        Text('Order Summary', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...lines.map((c) => Row(
                      children: [
                        Expanded(
                          child: Text('${c.qty} × ${c.item.name}',
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('₹${c.item.price * c.qty}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Text('Choose a payment method',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.qr_code_2, color: Colors.deepPurple),
              title: const Text('UPI Payment (Google Pay / Paytm / PhonePe)'),
              subtitle: const Text('Open UPI app or scan QR if unavailable'),
              onTap: total == 0 ? null : () => _placeOrderAndPay(context, ref, 'upi'),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.indigo),
              title: const Text('Net Banking (demo redirect)'),
              subtitle: const Text('Simulated bank page for testing'),
              onTap: total == 0 ? null : () => _placeOrderAndPay(context, ref, 'netbank'),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Cash / Mock Payment'),
              subtitle: const Text('Pay at delivery (cash or UPI to agent)'),
              onTap: () => _placeOrderAndPay(context, ref, 'cash'),
            ),
          ),

          const SizedBox(height: 28),
          Center(
            child: FilledButton(
              onPressed: total == 0 ? null : () => _placeOrderAndPay(context, ref, 'upi'),
              child: Text('Pay ₹$total'),
            ),
          ),
        ]),
      ),
    );
  }
}


/* ---------------------------- TRACK SCREEN ---------------------------- */
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final mapController = MapController();
  LatLng? _current;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() => _current = LatLng(pos.latitude, pos.longitude));

    Geolocator.getPositionStream().listen((pos) {
      final next = LatLng(pos.latitude, pos.longitude);
      setState(() => _current = next);
      if (_follow) mapController.move(next, mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Live Map')),
      body: Stack(children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: _current!, initialZoom: 17),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.campus.bot.campus_delivery',
            ),
            const CurrentLocationLayer(
              style: LocationMarkerStyle(
                marker: DefaultLocationMarker(),
                markerSize: Size(40, 40),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(children: [
            FloatingActionButton.small(
              heroTag: 'zoom+',
              onPressed: () => mapController.move(
                mapController.camera.center,
                mapController.camera.zoom + 0.5,
              ),
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'zoom-',
              onPressed: () => mapController.move(
                mapController.camera.center,
                mapController.camera.zoom - 0.5,
              ),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'center',
              onPressed: () {
                if (_current != null) {
                  _follow = true;
                  mapController.move(_current!, 17);
                }
              },
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'follow',
              onPressed: () => setState(() => _follow = !_follow),
              child: Icon(_follow ? Icons.navigation : Icons.navigation_outlined),
            ),
          ]),
        ),
      ]),
    );
  }
}

/* ---------------------------- ORDERS (stream) ---------------------------- */
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':
        return Colors.blueGrey;
      case 'preparing':
        return Colors.orange;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Orders')),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderService().streamMyOrders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = orders[i];
              return Card(
                child: ListTile(
                  title: Text('${o.vendorName} • ₹${o.amount}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        Chip(
                          label: Text(o.status),
                          backgroundColor: _statusColor(o.status).withOpacity(.12),
                          labelStyle: TextStyle(color: _statusColor(o.status), fontWeight: FontWeight.w600),
                          side: BorderSide(color: _statusColor(o.status).withOpacity(.2)),
                        ),
                        Chip(
                          label: Text(o.paymentMethod.toUpperCase()),
                          backgroundColor: Colors.black.withOpacity(.06),
                          side: BorderSide.none,
                        ),
                        Chip(
                          label: Text(o.paymentStatus),
                          backgroundColor: (o.paymentStatus == 'success'
                              ? Colors.green
                              : o.paymentStatus == 'failed'
                              ? Colors.red
                              : Colors.amber)
                              .withOpacity(.12),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Optional: push details screen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ---------------------------- ACCOUNT SCREEN ---------------------------- */
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? profileData;
  bool loading = true;
  bool _navLocked = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    user = FirebaseAuth.instance.currentUser; // refresh local copy
    if (user == null) {
      setState(() => loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) profileData = doc.data();
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    context.go('/signin');
  }

  Future<void> _goTo(String path) async {
    if (_navLocked) return;
    _navLocked = true;
    await context.push(path);
    _navLocked = false;
    await _loadProfile();
  }

  Future<void> _editSettings() async {
    final svc = UserSettingsService();
    final current = await svc.getSettings();

    if (!mounted) return;
    final nameCtrl = TextEditingController(text: current.displayName);
    String method = current.defaultPayment;
    bool push = current.pushEnabled;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            Text('Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name',
                filled: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: method,
              items: const [
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'netbank', child: Text('Net Banking')),
              ],
              onChanged: (v) => method = v ?? 'upi',
              decoration: const InputDecoration(labelText: 'Default payment', filled: true),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: push,
              onChanged: (v) => setState(() => push = v),
              title: const Text('Push notifications'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final s = UserSettings(
                  pushEnabled: push,
                  defaultPayment: method,
                  displayName: nameCtrl.text.trim(),
                );
                await svc.updateSettings(s);
                if (context.mounted) Navigator.pop(ctx);
                await _loadProfile();
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: FilledButton(
            onPressed: () => _goTo('/signin'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }

    final phoneVerified = (profileData?['phoneVerified'] == true) ||
        (FirebaseAuth.instance.currentUser?.phoneNumber != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Account'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange,
              child: Icon(Icons.person, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                user?.email ?? 'No email',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          if (profileData != null) ...[
            Text('📧 Email: ${profileData?['email'] ?? user?.email ?? 'N/A'}'),
            Text('📱 Phone: ${profileData?['phone'] ?? (user?.phoneNumber ?? 'N/A')}'),
            Text('🆔 Reg No: ${profileData?['regNo'] ?? 'N/A'}'),
            Text('✅ Phone Verified: ${phoneVerified ? 'Yes' : 'No'}'),
            if (profileData?['settings'] != null) ...[
              const SizedBox(height: 8),
              Text('⚙️ Default payment: ${profileData!['settings']['defaultPayment'] ?? 'upi'}'),
              Text('🔔 Push enabled: ${profileData!['settings']['pushEnabled'] ?? true}'),
              if ((profileData!['settings']['displayName'] ?? '').toString().isNotEmpty)
                Text('👤 Display name: ${profileData!['settings']['displayName']}'),
            ],
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _editSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Edit settings'),
          ),
          const SizedBox(height: 8),
          if (!phoneVerified)
            FilledButton.icon(
              onPressed: () => _goTo('/otp'),
              icon: const Icon(Icons.sms),
              label: const Text('Verify phone'),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
