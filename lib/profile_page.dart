import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application_1/edit_profile_page.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/help_center_page.dart';
import 'package:flutter_application_1/about_us_page.dart'; 
import 'package:flutter_application_1/terms_page.dart';
import 'package:flutter_application_1/notification_page.dart'; // Add this import

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _username = 'Guest';
  String _email = '';
  String? _profileImageUrl;
  String? _profileImageData;
  bool _isGuestMode = true;
  bool _isAdmin = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}')
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          print('Données utilisateur brutes: $userData'); // Debug print

          setState(() {
            _username = userData['username'] ?? user.displayName ?? 'User';
            _email = user.email ?? '';
            
            // Récupérer directement l'URL et les données base64
            _profileImageUrl = userData['profileImageUrl'];
            _profileImageData = userData['profileImageBase64'];
            
            _isGuestMode = false;
            _isAdmin = userData['isAdmin'] == true;
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  // Déconnexion Firebase
                  await FirebaseAuth.instance.signOut();
                  
                  // Mettre à jour les préférences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isGuestMode', true);
                  await prefs.setString('username', 'Guest');
                  
                  // Rediriger vers la page de connexion
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              child: const Text('Déconnecter', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _isGuestMode
            ? _buildGuestView()
            : _buildUserProfileView(),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          const Text(
            'Vous n\'êtes pas connecté',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connectez-vous pour accéder à votre profil et à vos réservations',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ).then((_) => _loadUserData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du profil avec photo
            Center(
              child: Column(
                children: [
                  // Photo de profil
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.withOpacity(0.1),
                      border: Border.all(color: Colors.deepPurple.withOpacity(0.3), width: 2),
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Nom d'utilisateur
                  Text(
                    _username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Email
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badge admin si applicable
                  if (_isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 16, color: Colors.deepPurple),
                          SizedBox(width: 4),
                          Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Bouton modifier le profil
            _buildProfileOption(
              icon: Icons.edit,
              title: 'Modifier le profil',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                ).then((_) => _loadUserData());
              },
            ),
            
            const Divider(height: 32),
            
            // Options du compte
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'PARAMÈTRES DU COMPTE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            
            _buildProfileOption(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {
                // Navigate to notifications page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationPage()),
                );
              },
            ),
            
            _buildProfileOption(
              icon: Icons.lock_outline,
              title: 'Sécurité',
              onTap: () {
                // Navigate to edit profile page for security settings
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                ).then((_) => _loadUserData());
              },
            ),
            
            const Divider(height: 32),
            
            // Section Aide et informations
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'AIDE ET INFORMATIONS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            
            // Centre d'aide
            _buildProfileOption(
              icon: Icons.help_outline,
              title: 'Centre d\'aide',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpCenterPage()),
                );
              },
            ),

            // À propos de nous
            _buildProfileOption(
              icon: Icons.info_outline,
              title: 'À propos de nous',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutUsPage()),
                );
              },
            ),

            // Conditions générales
            _buildProfileOption(
              icon: Icons.policy_outlined,
              title: 'Conditions générales',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsPage()),
                );
              },
            ),
            
            const Divider(height: 32),
            
            // Bouton de déconnexion
            _buildProfileOption(
              icon: Icons.logout,
              title: 'Déconnexion',
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: _signOut,
            ),
            
            const SizedBox(height: 32),
            
            // Version de l'application
            Center(
              child: Text(
                'Hotello v1.0.0',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
  print('Building profile image with:');
  print('URL: $_profileImageUrl');
  print('Base64 data available: ${_profileImageData?.isNotEmpty}');

  // Essayer d'abord les données base64
  if (_profileImageData != null && _profileImageData!.isNotEmpty) {
    try {
      final imageBytes = base64Decode(_profileImageData!);
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading base64 image: $error');
          return _buildFallbackProfileImage();
        },
      );
    } catch (e) {
      print('Error decoding base64: $e');
    }
  }

  // Si les données base64 échouent et qu'on a une URL
  if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
    // Vérifier si l'URL est déjà complète
    final url = _profileImageUrl!.startsWith('http') 
        ? _profileImageUrl!
        : 'URL_DE_VOTRE_DATABASE/$_profileImageUrl';
        
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image from URL: $error');
        return _buildFallbackProfileImage();
      },
    );
  }
  
  // Image par défaut si rien ne fonctionne
  return _buildFallbackProfileImage();
}

  Widget _buildFallbackProfileImage() {
    return Center(
      child: Text(
        _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.deepPurple,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title, 
        style: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  bool _isValidBase64(String str) {
  try {
    base64Decode(str);
    return true;
  } catch (e) {
    return false;
  }
}

// Appellez cette méthode depuis initState après _loadUserData()
void _verifyProfileImageData() {
  Future.delayed(const Duration(seconds: 1), () {
    if (_profileImageData != null && !_isValidBase64(_profileImageData!)) {
      print('Les données d\'image ne sont pas au format base64 valide. Réinitialisation...');
      setState(() {
        _profileImageData = null;
      });
    }
  });
}

// Ajoutez cette méthode qui ouvre une page de diagnostic
void _showDebugInfo() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Informations de débogage'),
          backgroundColor: Colors.deepPurple,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Username: $_username'),
              Text('Email: $_email'),
              Text('IsAdmin: $_isAdmin'),
              Text('IsGuestMode: $_isGuestMode'),
              Text('ProfileImageUrl: $_profileImageUrl'),
              Text('ProfileImageUrl length: ${_profileImageUrl?.length ?? 0}'),
              const Divider(),
              Text('ProfileImageBase64 length: ${_profileImageData?.length ?? 0}'),
              if (_profileImageData != null)
                Text('Is valid base64: ${_isValidBase64(_profileImageData!)}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final snapshot = await FirebaseDatabase.instance
                        .ref()
                        .child('users/${user.uid}')
                        .get();
                    
                    if (snapshot.exists) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Données brutes utilisateur'),
                            content: Text(snapshot.value.toString()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fermer'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  }
                },
                child: const Text('Voir les données brutes'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}