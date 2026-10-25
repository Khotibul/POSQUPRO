import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/report_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/register_provider.dart';
import 'providers/local_database_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/products_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/db_setup_screen.dart';
import 'screens/register_screen.dart';
import 'screens/parked_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/purchase_orders_screen.dart';
import 'screens/stock_counts_screen.dart';
import 'screens/users_screen.dart';
import 'screens/master_data_screen.dart';
import 'screens/activity_logs_screen.dart';
import 'screens/saas_dashboard_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/inventory_history_screen.dart';

void main() async {
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
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => RegisterProvider()),
        ChangeNotifierProvider(create: (_) => LocalDatabaseProvider()),
      ],
      child: MaterialApp(
        title: 'POSQUPRO',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashOrLoginWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/db-setup':
              return MaterialPageRoute(builder: (_) => DbSetupScreen(onConfigured: () {}));
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/pos':
              return MaterialPageRoute(builder: (_) => const PosScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/parked':
              return MaterialPageRoute(builder: (_) => const ParkedScreen());
            case '/expenses':
              return MaterialPageRoute(builder: (_) => const ExpensesScreen());
            case '/purchase-orders':
              return MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen());
            case '/stock-counts':
              return MaterialPageRoute(builder: (_) => const StockCountsScreen());
            case '/users':
              return MaterialPageRoute(builder: (_) => const UsersScreen());
            case '/master-data':
              return MaterialPageRoute(builder: (_) => const MasterDataScreen());
            case '/activity-logs':
              return MaterialPageRoute(builder: (_) => const ActivityLogsScreen());
            case '/saas':
              return MaterialPageRoute(builder: (_) => const SaasDashboardScreen());
            case '/tenants':
              return MaterialPageRoute(builder: (_) => const TenantsScreen());
            case '/inventory-histories':
              return MaterialPageRoute(builder: (_) => const InventoryHistoryScreen());
            case '/products':
              return MaterialPageRoute(builder: (_) => const ProductsScreen());
            case '/customers':
              return MaterialPageRoute(builder: (_) => const CustomersScreen());
            case '/suppliers':
              return MaterialPageRoute(builder: (_) => const SuppliersScreen());
            case '/transactions':
              return MaterialPageRoute(builder: (_) => const TransactionsScreen());
            case '/reports':
              return MaterialPageRoute(builder: (_) => const ReportsScreen());
            case '/stock':
              return MaterialPageRoute(builder: (_) => const StockScreen());
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
