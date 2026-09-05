import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/products_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const PosquproApp());
}

class PosquproApp extends StatelessWidget {
  const PosquproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        title: 'POSQUPRO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashOrLoginWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/pos':
              return MaterialPageRoute(builder: (_) => const PosScreen());
            case '/products':
              return MaterialPageRoute(builder: (_) => const ProductsScreen());
            case '/transactions':
              return MaterialPageRoute(builder: (_) => const TransactionsScreen());
            case '/settings':
              return MaterialPageRoute(builder: (_) => const SettingsScreen());
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}

class SplashOrLoginWrapper extends StatefulWidget {
  const SplashOrLoginWrapper({super.key});

  @override
  State<SplashOrLoginWrapper> createState() => _SplashOrLoginWrapperState();
}

class _SplashOrLoginWrapperState extends State<SplashOrLoginWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = await auth.tryAutoLogin();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _showSplash = false);

    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen(onInitializationComplete: null);
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
