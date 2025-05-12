import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/home_page.dart';
import 'package:flutter_application_1/utils/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_application_1/profile_page.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // Paramètres par défaut
  String _currency = 'USD';
  String _language = 'Français';
  Locale _locale = const Locale('fr');
  bool _darkModeEnabled = false;
  
  // Getters
  String get currency => _currency;
  String get language => _language;
  Locale get locale => _locale;
  bool get darkModeEnabled => _darkModeEnabled;
  ThemeMode get themeMode => _darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
  
  // Thèmes
  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
  
  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  // Symboles de devise
  final Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'MAD': 'MAD',
    'CAD': 'CA\$',
  };

  // Obtenir le symbole de la devise actuelle
  String get currencySymbol => _currencySymbols[_currency] ?? '\$';

  // Formater un prix avec la devise actuelle
  String formatPrice(dynamic price) {
    if (price == null) return '$currencySymbol 0';
    
    // Assurer que price est un nombre
    double numPrice;
    if (price is String) {
      numPrice = double.tryParse(price) ?? 0;
    } else if (price is int) {
      numPrice = price.toDouble();
    } else if (price is double) {
      numPrice = price;
    } else {
      numPrice = 0;
    }
    
    // Formatter selon la devise
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );
    
    return formatter.format(numPrice);
  }

  // Initialiser les paramètres depuis SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString('currency') ?? 'USD';
    _language = prefs.getString('language') ?? 'Français';
    _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
    _setLocale();
    notifyListeners();
  }

  // Mettre à jour la devise
  Future<void> setCurrency(String currency) async {
    if (_currency != currency) {
      _currency = currency;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', currency);
      notifyListeners();
    }
  }

  // Mettre à jour la langue
  Future<void> setLanguage(String language) async {
    if (_language != language) {
      _language = language;
      _setLocale();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', language);
      notifyListeners();
    }
  }

  // Ajouter cette méthode pour le mode sombre
  Future<void> setDarkMode(bool enabled) async {
    if (_darkModeEnabled != enabled) {
      _darkModeEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkModeEnabled', enabled);
      notifyListeners();
    }
  }

  // Convertir la langue en Locale
  void _setLocale() {
    switch (_language) {
      case 'Français':
        _locale = const Locale('fr');
        break;
      case 'English':
        _locale = const Locale('en');
        break;
      case 'Español':
        _locale = const Locale('es');
        break;
      case 'Deutsch':
        _locale = const Locale('de');
        break;
      case 'العربية':
        _locale = const Locale('ar');
        break;
      default:
        _locale = const Locale('fr');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser les paramètres
  final appSettings = AppSettings();
  await appSettings.init();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(
    ChangeNotifierProvider.value(
      value: appSettings,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettings>(context);
    
    return MaterialApp(
      title: 'Hotello',
      debugShowCheckedModeBanner: false,
      themeMode: appSettings.themeMode,
      theme: appSettings.lightTheme,
      darkTheme: appSettings.darkTheme,
      locale: appSettings.locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
        Locale('de'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'Français';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final appSettings = Provider.of<AppSettings>(context, listen: false);
    
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _darkModeEnabled = appSettings.darkModeEnabled;
      _selectedCurrency = appSettings.currency;
      _selectedLanguage = appSettings.language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettings>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ... autres widgets ...
          
          SwitchListTile(
            title: const Text('Mode sombre'),
            subtitle: const Text('Changer l\'apparence de l\'application'),
            value: _darkModeEnabled,
            onChanged: (value) async {
              setState(() {
                _darkModeEnabled = value;
              });
              await appSettings.setDarkMode(value);
            },
            secondary: const Icon(Icons.dark_mode, color: Colors.deepPurple),
          ),
          
          // Devise et langue
          ListTile(
            title: const Text('Devise'),
            subtitle: Text(_selectedCurrency),
            leading: const Icon(Icons.currency_exchange, color: Colors.deepPurple),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showCurrencyPicker(appSettings),
          ),
          
          ListTile(
            title: const Text('Langue'),
            subtitle: Text(_selectedLanguage),
            leading: const Icon(Icons.language, color: Colors.deepPurple),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showLanguagePicker(appSettings),
          ),
          
          // ... autres widgets ...
        ],
      ),
    );
  }

  Future<void> _showCurrencyPicker(AppSettings appSettings) async {
    // ... code existant ...
  }

  Future<void> _showLanguagePicker(AppSettings appSettings) async {
    final languages = ['Français', 'English', 'Español', 'Deutsch', 'العربية'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une langue'),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) => RadioListTile<String>(
              title: Text(languages[index]),
              value: languages[index],
              groupValue: _selectedLanguage,
              onChanged: (value) async {
                if (value != null) {
                  Navigator.of(context).pop();
                  
                  setState(() {
                    _selectedLanguage = value;
                  });
                  
                  // Mettre à jour la langue dans AppSettings
                  await appSettings.setLanguage(value);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Langue mise à jour. Redémarrez l\'application pour voir tous les changements.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}