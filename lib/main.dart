import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/home_page.dart';
import 'package:flutter_application_1/admin_page.dart';
import 'package:flutter_application_1/signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/utils/app_settings.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_1/notification_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
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
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
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
      home: const LoginPage(), // Change to your actual start page - no AuthWrapper?
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hotel,
              size: 120,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 30),
            const Text(
              'Welcome to Hotello',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginPage())
                );
              },
              child: const Text('Sign In', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () async {
                // Set guest mode in shared preferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isGuestMode', true);
                await prefs.setString('username', 'Guest');
                
                // Navigate to home page
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomePage())
                  );
                }
              },
              child: const Text(
                'Continue as Guest',
                style: TextStyle(fontSize: 16, color: Colors.deepPurple),
              ),
            ),
            
            // Add admin access button
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                minimumSize: const Size(220, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Check if user is already logged in as admin
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Check if user is admin
                  final snapshot = await FirebaseDatabase.instance
                      .ref()
                      .child('users/${user.uid}')
                      .get();
                  
                  if (snapshot.exists) {
                    final userData = snapshot.value as Map<dynamic, dynamic>?;
                    final isAdmin = userData != null && userData['isAdmin'] == true;
                    
                    if (isAdmin && context.mounted) {
                      // Navigate directly to admin page
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const AdminPage())
                      );
                      return;
                    }
                  }
                }
                
                // If not already logged in as admin, show login with admin intent
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(isAdminLogin: true)
                    )
                  );
                }
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin Access', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
