import 'dart:convert';
import 'dart:async'; // Add Timer import
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/edit_profile_page.dart';
import 'package:flutter_application_1/notification_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/admin_page.dart';
import 'package:flutter_application_1/hotel_details_page.dart';
import 'package:flutter_application_1/profile_page.dart';
import 'package:flutter_application_1/explore_page.dart';
import 'package:flutter_application_1/bookings_page.dart';
import 'package:flutter_application_1/widgets/chatbot_widget.dart';
import 'package:flutter_application_1/about_us_page.dart';
import 'package:flutter_application_1/help_center_page.dart';
import 'package:flutter_application_1/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = 'Guest'; // Keep existing
  int _selectedIndex = 0; // Keep existing
  String? _profileImageUrl; // Keep existing
  String? _profileImageData; // Keep existing
  bool _isAdmin = false; // Keep existing
  
  // Consolidated hotel related state
  List<Map<String, dynamic>> _hotels = [];
  List<Map<String, dynamic>> _topRatedHotels = [];
  List<Map<String, dynamic>> _recentlyViewedHotels = [];
  bool _isLoading = true; // Consolidated loading state for hotels
  
  User? _currentUser; // Keep existing
  String _searchQuery = ''; // Keep existing
  final TextEditingController _searchController = TextEditingController(); // Keep existing
  StreamSubscription<DatabaseEvent>? _hotelsSubscription; // Consolidated subscription
  StreamSubscription<DatabaseEvent>? _userDataListener; // Keep if used for user data updates

  // For sync functionality
  bool _isSynchronizing = false; // Keep existing
  Timer? _syncTimer; // Keep existing

  static const String _recentlyViewedKey = 'recently_viewed_hotels'; // Keep existing
  static const int _maxRecentlyViewed = 5; // Keep existing

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    
    _loadInitialData(); // New method to orchestrate initial loading

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });

    // Setup periodic sync timer
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _synchronizeData();
    });
  }

  Future<void> _loadInitialData() async {
    await _loadUserData(); // Load user data first
    await _checkAdminStatus();
    await _setupConsolidatedHotelsListener(); // Setup the main hotels listener
    // _loadRecentlyViewedHotels() is called within _setupConsolidatedHotelsListener after hotels are loaded
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hotelsSubscription?.cancel();
    _userDataListener?.cancel(); // Ensure this is managed if you have a _userDataListener
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // ... Keep your existing _loadUserData logic ...
    // Ensure it sets username, _profileImageUrl, _profileImageData
    // Example structure:
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
      // If using a listener for user data:
      _userDataListener?.cancel();
      _userDataListener = userRef.onValue.listen((event) {
        if (!mounted) return;
        if (event.snapshot.exists) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            username = userData['username'] ?? user.displayName ?? 'User';
            _profileImageData = userData['profileImageBase64'] as String?;
            _profileImageUrl = userData['profileImageUrl'] as String?;
            // _isAdmin = userData['isAdmin'] == true; // Can also be updated here
          });
        }
      }, onError: (error) {
        print('Error in user data listener: $error');
      });
      // Or if fetching once:
      // final snapshot = await userRef.get();
      // if (snapshot.exists) { ... setState ... }
    } else {
       setState(() { // Handle guest user
         username = 'Guest';
         _profileImageData = null;
         _profileImageUrl = null;
       });
    }
  }

  Future<void> _checkAdminStatus() async {
    // ... Keep your existing _checkAdminStatus logic ...
    // Ensure it sets _isAdmin
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${_currentUser!.uid}/isAdmin') // More direct path if 'isAdmin' is top-level
          .get();
      if (mounted) {
        setState(() {
          _isAdmin = snapshot.exists && snapshot.value == true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  // Renamed and consolidated hotels listener setup
  Future<void> _setupConsolidatedHotelsListener() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    _hotelsSubscription?.cancel(); 
    _hotelsSubscription =
        FirebaseDatabase.instance.ref('hotels').onValue.listen((event) async {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final loadedHotels = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          final hotelData = Map<String, dynamic>.from(value as Map);
          hotelData['id'] = key;
          // Ensure features is a list of strings
          if (hotelData['features'] != null && hotelData['features'] is List) {
            hotelData['features'] = List<String>.from(hotelData['features'].map((item) => item.toString()));
          } else if (hotelData['features'] != null) {
             hotelData['features'] = [hotelData['features'].toString()];
          } else {
            hotelData['features'] = <String>[];
          }
          // Ensure all necessary fields for cards are present
          hotelData['name'] = hotelData['name'] ?? 'Unknown Hotel';
          hotelData['location'] = hotelData['location'] ?? 'Unknown Location';
          hotelData['price'] = hotelData['price']?.toString() ?? 'N/A';
          hotelData['rating'] = hotelData['rating']?.toString() ?? 'N/A';
          // Add other fields like 'imageData', 'imageUrl' if needed by the card
          hotelData['imageData'] = hotelData['imageData'] as String?;
          hotelData['imageUrl'] = hotelData['imageUrl'] as String?;

          loadedHotels.add(hotelData);
        });

        if (mounted) {
          setState(() {
            _hotels = loadedHotels;
            _topRatedHotels = _getTopRatedHotels(loadedHotels); 
            _isLoading = false;
          });
          await _loadRecentlyViewedHotels(); 
        }
      } else {
        if (mounted) {
          setState(() {
            _hotels = [];
            _topRatedHotels = [];
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        print("Error loading hotels: $error");
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
  
  Future<void> _synchronizeData() async {
    if (_isSynchronizing) return;
    if (!mounted) return;
    
    setState(() {
      _isSynchronizing = true;
      _isLoading = true; 
    });
    
    try {
      // For a manual sync, explicitly re-fetch data or re-init listener
      // Re-initializing the listener will fetch the latest data.
      await _setupConsolidatedHotelsListener(); // This will set _isLoading = false when done
      await _loadUserData(); 
      await _checkAdminStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Données synchronisées'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error during synchronization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de synchronisation'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSynchronizing = false;
          // _isLoading should be handled by _setupConsolidatedHotelsListener
        });
      }
    }
  }

  // ... Keep _getTopRatedHotels, _loadRecentlyViewedHotels, _addRecentlyViewedHotel as they are ...
  // ... Make sure they use the consolidated _hotels list and _isLoading flag ...

  List<Map<String, dynamic>> _getTopRatedHotels(List<Map<String, dynamic>> hotels) {
    List<Map<String, dynamic>> sortedHotels = List.from(hotels);
    sortedHotels.sort((a, b) {
      double ratingA = double.tryParse(a['rating']?.toString() ?? '0.0') ?? 0.0;
      double ratingB = double.tryParse(b['rating']?.toString() ?? '0.0') ?? 0.0;
      return ratingB.compareTo(ratingA); // Sort descending
    });
    return sortedHotels.take(5).toList(); 
  }

  Future<void> _loadRecentlyViewedHotels() async {
    // ... (This method seems fine, ensure it uses _hotels for lookup)
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String>? hotelIds = prefs.getStringList(_recentlyViewedKey);

    if (hotelIds != null && _hotels.isNotEmpty) {
      final loadedRecent = <Map<String, dynamic>>[];
      for (String id in hotelIds) {
        try {
          // Make sure _hotels is populated before this is called effectively
          final hotel = _hotels.firstWhere((h) => h['id'] == id);
          loadedRecent.add(hotel);
        } catch (e) {
          print("Recently viewed hotel with ID $id not found in current _hotels list.");
        }
      }
      if (mounted) {
        setState(() {
          _recentlyViewedHotels = loadedRecent;
        });
      }
    } else if (mounted) {
       setState(() {
         _recentlyViewedHotels = []; // Clear if no IDs or no hotels
       });
    }
  }

  Future<void> _addRecentlyViewedHotel(Map<String, dynamic> hotel) async {
    // ... (This method seems fine)
    if (!mounted || hotel['id'] == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    List<Map<String, dynamic>> updatedRecent = List.from(_recentlyViewedHotels);
    updatedRecent.removeWhere((h) => h['id'] == hotel['id']);
    updatedRecent.insert(0, hotel);

    if (updatedRecent.length > _maxRecentlyViewed) {
      updatedRecent = updatedRecent.sublist(0, _maxRecentlyViewed);
    }

    final List<String> hotelIdsToSave = updatedRecent.map((h) => h['id'] as String).toList();
    await prefs.setStringList(_recentlyViewedKey, hotelIdsToSave);

    if (mounted) {
      setState(() {
        _recentlyViewedHotels = updatedRecent;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildHomePageContent(), 
      const ExplorePage(),
      const BookingsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Accueil'), // Icône remplie pour sélection
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmarks_outlined), label: 'Réservations'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple.shade600, // Couleur plus vive
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Assure que tous les labels sont visibles
        backgroundColor: Colors.white, // Fond blanc pour la nav bar
        elevation: 5, // Ombre subtile
        selectedFontSize: 12, // Style
        unselectedFontSize: 12, // Style
      ),
      drawer: _selectedIndex == 0 ? _buildDrawer() : null, // Drawer seulement pour la page d'accueil
    );
  }
  
  void _onItemTapped(int index) { // Keep existing
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // Enlever le padding par défaut
        children: [
          UserAccountsDrawerHeader( // En-tête plus stylé
            accountName: Text(
              username, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
            ),
            accountEmail: Text(
              _currentUser?.email ?? 'Mode Invité', 
              style: const TextStyle(color: Colors.white70)
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: _buildProfileImage(), // Utilise votre logique d'image de profil
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade400, // Couleur d'en-tête
            ),
            otherAccountsPictures: [ // Exemple d'action rapide
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                },
                tooltip: 'Modifier le profil',
              )
            ],
          ),
          _buildDrawerItem(Icons.home_outlined, 'Accueil', () {
            Navigator.pop(context);
            // Déjà sur l'accueil si le drawer est ouvert depuis là
          }),
          _buildDrawerItem(Icons.settings_outlined, 'Paramètres', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
          }),
          _buildDrawerItem(Icons.info_outline_rounded, 'À Propos', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsPage()));
          }),
          _buildDrawerItem(Icons.help_outline_rounded, 'Centre d\'Aide', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterPage()));
          }),
          _buildDrawerItem(Icons.support_agent_rounded, 'Assistant Hotello', () { // Icône différente
            Navigator.pop(context);
            _showChatbotDialog();
          }, subtitle: 'Besoin d\'aide ?'), // Ajout d'un sous-titre

          const Divider(height: 20, thickness: 0.5, indent: 16, endIndent: 16), // Séparateur stylé

          if (_isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
              child: Text(
                'ADMINISTRATION', // Style
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500, // Style
                  fontSize: 12, // Style
                  letterSpacing: 0.5, // Style
                ),
              ),
            ),
            _buildDrawerItem(Icons.admin_panel_settings_outlined, 'Gérer les Hôtels', () { // Icône différente
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminPage()),
              ).then((_) => _synchronizeData());
            }),
            const Divider(height: 20, thickness: 0.5, indent: 16, endIndent: 16), // Séparateur stylé
          ],
          _buildDrawerItem(Icons.logout_rounded, 'Déconnexion', () async { // Icône différente
            // ... (votre logique de déconnexion existante) ...
            final prefs = await SharedPreferences.getInstance();
            final isGuestMode = prefs.getBool('isGuestMode') ?? false;

            if (isGuestMode) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            } else {
              await FirebaseAuth.instance.signOut();
              await prefs.setBool('isGuestMode', true);
              await prefs.setString('username', 'Guest');
              await prefs.remove('email');
              if(mounted) {
                setState(() {
                  username = 'Guest';
                  _profileImageUrl = null;
                  _profileImageData = null; // Assurez-vous de réinitialiser cela aussi
                  _currentUser = null; // Réinitialiser l'utilisateur actuel
                  _isAdmin = false; // Réinitialiser le statut admin
                });
                Navigator.pop(context); // Fermer le drawer
                 // Optionnel: Naviguer vers la page de connexion après déconnexion
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()), 
                  (Route<dynamic> route) => false,
                );
              }
            }
          }, color: Colors.red.shade400), // Couleur pour la déconnexion
        ],
      ),
    );
  }

  // Helper pour les items du Drawer
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color? color, String? subtitle}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.deepPurple.shade300, size: 24), // Style
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color ?? Colors.black87)), // Style
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null, // Style
      onTap: onTap,
      dense: true, // Style
      contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 2.0), // Style
    );
  }

  Widget _buildProfileImage() {
  // Essayer d'abord les données base64
  if (_profileImageData != null && _profileImageData!.isNotEmpty) {
    try {
      final imageBytes = base64Decode(_profileImageData!);
      return ClipOval(
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: 50, // Ajusté pour UserAccountsDrawerHeader
          height: 50, // Ajusté
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar(size: 50); // Passer la taille
          },
        ),
      );
    } catch (e) {
      print('Error decoding base64: $e');
       return _buildFallbackAvatar(size: 50);
    }
  }

  // Ensuite essayer l'URL
  if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        width: 50, // Ajusté
        height: 50, // Ajusté
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white) // Style
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAvatar(size: 50);
        },
      ),
    );
  }
  return _buildFallbackAvatar(size: 50);
}

Widget _buildFallbackAvatar({double size = 24}) { // Accepte une taille
  return Container( // Conteneur pour centrer le texte si l'image est dans un CircleAvatar
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.deepPurple.shade200, // Couleur de fond pour l'avatar
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      username.isNotEmpty ? username[0].toUpperCase() : 'G',
      style: TextStyle(
        fontSize: size * 0.5, // Taille de police relative
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

// Update the chatbot dialog implementation
void _showChatbotDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,  // Prevent closing by tapping outside
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assistant Hotello',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const Expanded(
              child: ChatbotWidget(),
            ),
          ],
        ),
      ),
    ),
  );
}

  List<Map<String, dynamic>> _getFeaturedHotels(List<Map<String, dynamic>> hotels) {
    // Example: take first 5 hotels or implement specific logic
    return hotels.take(5).toList();
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel, {bool isSmall = false}) {
    final String name = hotel['name'] ?? 'Unknown Hotel';
    final String location = hotel['location'] ?? 'Unknown Location';
    final String price = hotel['price']?.toString() ?? 'N/A';
    final String rating = hotel['rating']?.toString() ?? 'N/A';
    final String? imageData = hotel['imageData'] as String?;
    final String? imageUrl = hotel['imageUrl'] as String?;
    final List<String> features = hotel['features'] is List
        ? List<String>.from(hotel['features'])
        : (hotel['features'] != null ? [hotel['features'].toString()] : []);


    Widget imageWidget;
    if (imageData != null && imageData.isNotEmpty) {
      try {
        imageWidget = Image.memory(
          base64Decode(imageData),
          height: isSmall ? 100 : 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(isSmall: isSmall),
        );
      } catch (e) {
        imageWidget = _buildFallbackImage(isSmall: isSmall);
      }
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl,
        height: isSmall ? 100 : 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(isSmall: isSmall),
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: isSmall ? 100 : 150,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = _buildFallbackImage(isSmall: isSmall);
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HotelDetailsPage(hotelData: hotel, hotelId: hotel['id'] as String),
            ),
          ).then((_) {
             // When returning from details, add to recently viewed
            _addRecentlyViewedHotel(hotel);
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageWidget,
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: isSmall ? 14 : 17, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isSmall) const SizedBox(height: 4),
                  if (!isSmall)
                    Text(
                      location,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$$price/nuit',
                        style: TextStyle(
                            fontSize: isSmall ? 13 : 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: isSmall ? 14 : 18),
                          const SizedBox(width: 4),
                          Text(rating, style: TextStyle(fontSize: isSmall ? 13: 14)),
                        ],
                      ),
                    ],
                  ),
                  if (!isSmall && features.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: features.take(2).map((feature) => Chip(
                        label: Text(feature, style: const TextStyle(fontSize: 10)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        backgroundColor: Colors.deepPurple.withOpacity(0.1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage({bool isSmall = false}) {
    return Container(
      height: isSmall ? 100 : 150,
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.hotel,
          color: Colors.grey[500],
          size: isSmall ? 40 : 60,
        ),
      ),
    );
  }

  Widget _buildRecommendationSection({
    required String title,
    required List<Map<String, dynamic>> hotels,
    required bool isLoading,
  }) {
    if (isLoading && hotels.isEmpty) { // Show loader only if initially loading and no data
      return const SizedBox.shrink(); // Or a small loader
    }
    if (hotels.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no hotels
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        SizedBox(
          height: 260, // Adjust height as needed for small cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: hotels.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: 200, // Adjust width for small cards
                child: _buildHotelCard(hotels[index], isSmall: true),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomePageContent() {
    final filteredHotels = _hotels.where((hotel) {
      final hotelName = hotel['name']?.toString().toLowerCase() ?? '';
      final hotelLocation = hotel['location']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return hotelName.contains(query) || hotelLocation.contains(query);
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar( // Utilisation de SliverAppBar pour un effet de défilement
          expandedHeight: 240.0, // Hauteur de l'en-tête étendu
          floating: false,
          pinned: true, // L'AppBar reste visible en haut
          snap: false,
          backgroundColor: Colors.deepPurple.shade400, // Couleur de l'AppBar
          elevation: 2,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: _isSynchronizing // Afficher le loader de synchro ou rien
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                : const SizedBox.shrink(), // MODIFIÉ ICI: Supprime le texte "Hotello"
            background: Container( // Contenu de l'en-tête étendu
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16), // Ajuster le padding supérieur pour l'AppBar
              decoration: BoxDecoration(
                gradient: LinearGradient( // Dégradé subtil
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, // Aligner en bas
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  
                ],
              ),
            ),
          ),
          actions: [ // Actions pour SliverAppBar
            if (!_isSynchronizing)
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: Colors.white), // Icône différente
                onPressed: _synchronizeData,
                tooltip: 'Synchroniser les données',
              ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white), // Icône différente
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationPage()),
                );
              },
              tooltip: 'Notifications',
            ),
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white), // Icône différente
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPage()),
                  );
                },
                tooltip: 'Panneau Admin',
              ),
          ],
        ),

        // Recently Viewed Section
        if (_recentlyViewedHotels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRecommendationSection(
              title: 'Consultés Récemment', // Titre plus clair
              hotels: _recentlyViewedHotels,
              isLoading: _isLoading,
            ),
          ),
        
        // Top Rated Section
        if (_topRatedHotels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRecommendationSection(
              title: 'Hôtels les Mieux Notés',
              hotels: _topRatedHotels,
              isLoading: _isLoading,
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12), // Ajusté
            child: Text(
              _searchQuery.isEmpty ? 'Hôtels Populaires' : 'Résultats de Recherche', // Titre plus clair
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), // Style
            ),
          ),
        ),
        _isLoading && filteredHotels.isEmpty
            ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.deepPurple.shade300))) // Style
            : filteredHotels.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0), // Amélioration de l'état vide
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hotel_class_outlined, size: 70, color: Colors.grey.shade400), // Icône
                            const SizedBox(height: 20),
                            Text(
                              _searchQuery.isEmpty ? 'Aucun hôtel à afficher' : 'Aucun résultat trouvé', // Texte plus clair
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54), // Style
                              textAlign: TextAlign.center,
                            ),
                             if (_searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text("Essayez un autre terme de recherche.", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverPadding( // Utiliser SliverPadding pour la liste principale
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Utiliser la version de _buildHotelCard de home_page.dart
                          return _buildHotelCard(filteredHotels[index], isSmall: false); 
                        },
                        childCount: filteredHotels.length,
                      ),
                    ),
                  ),
      ],
    );
  }
}