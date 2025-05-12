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
  String username = 'Guest';
  int _selectedIndex = 0;
  String? _profileImageUrl;
  String? _profileImageData;
  List<Map<String, dynamic>> _hotels = [];
  bool _isAdmin = false;
  bool _isLoadingHotels = false;
  bool _isSynchronizing = false;
  
  // Firebase listeners for real-time updates
  StreamSubscription<DatabaseEvent>? _hotelsListener;
  StreamSubscription<DatabaseEvent>? _userDataListener;
  
  // Auto-sync timer
  Timer? _syncTimer;

  List<Map<String, dynamic>> _featuredHotels = [];
  List<Map<String, dynamic>> _topRatedHotels = []; // For Top Rated
  List<Map<String, dynamic>> _recentlyViewedHotels = []; // For Recently Viewed
  bool _isLoading = true;
  User? _currentUser;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _hotelsSubscription;

  static const String _recentlyViewedKey = 'recently_viewed_hotels';
  static const int _maxRecentlyViewed = 5;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _setupSynchronization();
    _checkAdminStatus();
    _setupHotelsListener();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }
  
  @override
  void dispose() {
    // Clean up listeners when widget is disposed
    _hotelsListener?.cancel();
    _userDataListener?.cancel();
    _syncTimer?.cancel();
    _searchController.dispose();
    _hotelsSubscription?.cancel();
    super.dispose();
  }
  
  // Initial data loading
  Future<void> _initialLoad() async {
    await _loadUserData();
    await _loadHotels();
    await _checkAdminStatus();
  }

  // Setup synchronization mechanisms
  void _setupSynchronization() {
    // Set up Firebase realtime database listeners
    _setupHotelsListener();
    _setupUserDataListener();
    
    // Setup periodic sync timer (every 3 minutes)
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _synchronizeData();
    });
  }
  
  // Perform manual sync
  Future<void> _synchronizeData() async {
    if (_isSynchronizing) return;
    
    setState(() {
      _isSynchronizing = true;
    });
    
    try {
      await _loadHotels();
      await _loadUserData();
      await _checkAdminStatus();
      
      // Show sync success message
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
        });
      }
    }
  }
  
  // Setup hotels realtime listener
  void _setupHotelsListener() {
    final hotelsRef = FirebaseDatabase.instance.ref('hotels');
    _hotelsListener = hotelsRef.onValue.listen((event) {
      if (!mounted) return;
      
      if (event.snapshot.exists) {
        final hotelsData = event.snapshot.value as Map<dynamic, dynamic>;
        final loadedHotels = <Map<String, dynamic>>[];

        hotelsData.forEach((key, value) {
          // Récupérer les fonctionnalités
          List<dynamic> features = [];
          if (value['features'] != null) {
            features = value['features'] is List ? value['features'] : [value['features']];
          }
          
          loadedHotels.add({
            'id': key,
            'name': value['name'] ?? 'Unknown Hotel',
            'location': value['location'] ?? 'Unknown Location',
            'price': value['price'] ?? '0',
            'rating': value['rating'] ?? '0.0',
            'description': value['description'] ?? '',
            'phone': value['phone'] ?? '',
            'features': features,
            'imageData': value['imageData'],
            'imageUrl': value['imageUrl'],
          });
        });

        if (mounted) {
          setState(() {
            _hotels = loadedHotels;
            _isLoadingHotels = false;
          });
        }
      }
    }, onError: (error) {
      print('Error in hotels listener: $error');
    });
  }
  
  // Setup user data realtime listener
  void _setupUserDataListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
      _userDataListener = userRef.onValue.listen((event) {
        if (!mounted) return;
        
        if (event.snapshot.exists) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          
          if (mounted) {
            setState(() {
              username = userData['username'] ?? user.displayName ?? 'User';
              
              if (userData['profileImageBase64'] != null && 
                  userData['profileImageBase64'].toString().isNotEmpty) {
                _profileImageData = userData['profileImageBase64'];
              }
              if (userData['profileImageUrl'] != null && 
                  userData['profileImageUrl'].toString().isNotEmpty) {
                _profileImageUrl = userData['profileImageUrl'];
              }
              
              _isAdmin = userData['isAdmin'] == true;
            });
          }
        }
      }, onError: (error) {
        print('Error in user data listener: $error');
      });
    }
  }

  // Add these new methods
  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}')
            .get();
        
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>?;
          if (userData != null && userData['isAdmin'] == true) {
            setState(() {
              _isAdmin = true;
            });
          }
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  // Dans la méthode _loadHotels(), ajoutez le chargement des fonctionnalités
  Future<void> _loadHotels() async {
    setState(() {
      _isLoadingHotels = true;
    });
    
    try {
      final hotelsSnapshot = await FirebaseDatabase.instance.ref('hotels').get();
      
      if (hotelsSnapshot.exists) {
        final hotelsData = hotelsSnapshot.value as Map<dynamic, dynamic>;
        final loadedHotels = <Map<String, dynamic>>[];

        hotelsData.forEach((key, value) {
          // Récupérer les fonctionnalités
          List<dynamic> features = [];
          if (value['features'] != null) {
            features = value['features'] is List ? value['features'] : [value['features']];
          }
          
          loadedHotels.add({
            'id': key,
            'name': value['name'] ?? 'Unknown Hotel',
            'location': value['location'] ?? 'Unknown Location',
            'price': value['price'] ?? '0',
            'rating': value['rating'] ?? '0.0',
            'description': value['description'] ?? '',
            'phone': value['phone'] ?? '',
            'features': features,
            // Gérer les deux formats d'image possibles
            'imageData': value['imageData'],
            'imageUrl': value['imageUrl'],
          });
        });

        setState(() {
          _hotels = loadedHotels;
        });
      }
    } catch (e) {
      print('Error loading hotels: $e');
    } finally {
      setState(() {
        _isLoadingHotels = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        final userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}')
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          
          setState(() {
            username = userData['username'] ?? user.displayName ?? 'User';
            // Récupérer l'URL ou les données base64 de l'image
            if (userData['profileImageBase64'] != null && 
                userData['profileImageBase64'].toString().isNotEmpty) {
              _profileImageData = userData['profileImageBase64'];
            }
            if (userData['profileImageUrl'] != null && 
                userData['profileImageUrl'].toString().isNotEmpty) {
              _profileImageUrl = userData['profileImageUrl'];
            }
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          const ExplorePage(),
          const BookingsPage(), // Remplacer le placeholder
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      drawer: _selectedIndex == 0 ? _buildDrawer() : null,
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: _synchronizeData,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: const Text('Hotello',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: Colors.deepPurple,
              actions: [
                // Sync button
                _isSynchronizing 
                  ? Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync, color: Colors.white),
                      onPressed: _synchronizeData,
                      tooltip: 'Synchroniser les données',
                    ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationPage()),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: _buildProfileImage(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, $username!',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const Text(
                                'Find your perfect stay',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        // Edit profile button removed
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Search bar removed - non-functional
            // Add Featured Hotels section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Featured Hotels',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isAdmin)
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPage(),
                                ),
                              ).then((_) => _loadHotels());
                            },
                            child: const Text('Manage'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Display hotels
            _isLoadingHotels
                ? const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _hotels.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No hotels available'),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final hotel = _hotels[index];
                            return _buildHotelCard(
                              hotel['name'],
                              '${hotel['rating']} ★',
                              '\$${hotel['price']}/night',
                              hotel['location'],
                              hotel['imageData'],
                              hotel,  // Passez l'objet hôtel complet comme dernier argument
                            );
                          },
                          childCount: _hotels.length,
                        ),
                      ),
            // ...existing Recent Bookings section...
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(
              Icons.home,
              color: Colors.deepPurple,
            ),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings,
              color: Colors.deepPurple,
            ),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Ferme le drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.info,
              color: Colors.deepPurple,
            ),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // Ferme le drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.help,
              color: Colors.deepPurple,
            ),
            title: const Text('Help'),
            onTap: () {
              Navigator.pop(context); // Ferme le drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
            },
          ),
          // Add Chatbot item before the admin section
          ListTile(
            leading: const Icon(
              Icons.smart_toy, // Robot icon for chatbot
              color: Colors.deepPurple,
            ),
            title: const Text('Chatbot Assistant'),
            subtitle: const Text('Besoin d\'aide ?'),
            onTap: () {
              // TODO: Implement chatbot functionality
              Navigator.pop(context);
              _showChatbotDialog();
            },
          ),

          const Divider(),

          if (_isAdmin) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                'Admin',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.deepPurple,
              ),
              title: const Text('Manage Hotels'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPage(),
                  ),
                ).then((_) => _loadHotels());
              },
            ),
          ],
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final isGuestMode = prefs.getBool('isGuestMode') ?? false;

              if (isGuestMode) {
                // If already in guest mode, just go to login page
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              } else {
                // Sign out from Firebase Auth
                await FirebaseAuth.instance.signOut();

                // Reset to guest mode
                await prefs.setBool('isGuestMode', true);
                await prefs.setString('username', 'Guest');

                // Clear other user data
                await prefs.remove('email');

                // Reload user data to update UI
                setState(() {
                  username = 'Guest';
                  _profileImageUrl = null;
                });

                // Close drawer
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // Mettez à jour la méthode _buildHotelCard pour afficher les fonctionnalités
  Widget _buildHotelCard(
      String name, String rating, String price, String location, String? imageData, Map<String, dynamic> hotel) {
    // Récupérer les fonctionnalités
    List<dynamic> features = hotel['features'] ?? [];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: _buildHotelImage(imageData, hotel['imageUrl']),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                // Afficher les fonctionnalités
                if (features.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: features.take(3).map<Widget>((feature) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            feature.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                
                // Bouton Consulter
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HotelDetailsPage(hotelData: hotel, hotelId: hotel['id'] as String),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Consulter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelImage(String? imageData, String? imageUrl) {
  // Priorité à imageData (base64) s'il existe
  if (imageData != null && imageData.isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(imageData),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading base64 image: $error');
          // Si l'image base64 échoue, essayer imageUrl
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return _buildImageFromUrl(imageUrl);
          }
          return _buildPlaceholderImage();
        },
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      // Si le décodage base64 échoue, essayer imageUrl
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return _buildImageFromUrl(imageUrl);
      }
    }
  }
  
  // Ensuite essayer imageUrl
  if (imageUrl != null && imageUrl.isNotEmpty) {
    return _buildImageFromUrl(imageUrl);
  }
  
  // Fallback
  return _buildPlaceholderImage();
}

Widget _buildImageFromUrl(String url) {
  return Image.network(
    url,
    height: 150,
    width: double.infinity,
    fit: BoxFit.cover,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Center(
        child: CircularProgressIndicator(
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null,
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
      print('Error loading network image: $error');
      return _buildPlaceholderImage();
    },
  );
}

Widget _buildPlaceholderImage() {
  return Container(
    height: 150,
    color: Colors.deepPurple.withOpacity(0.2),
    child: Center(
      child: Icon(Icons.hotel, size: 40, color: Colors.deepPurple.withOpacity(0.7)),
    ),
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
          width: 60,
          height: 60,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading base64 image: $error');
            return _buildFallbackAvatar();
          },
        ),
      );
    } catch (e) {
      print('Error decoding base64: $e');
    }
  }

  // Ensuite essayer l'URL
  if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white)
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image from URL: $error');
          return _buildFallbackAvatar();
        },
      ),
    );
  }

  // Image par défaut
  return _buildFallbackAvatar();
}

Widget _buildFallbackAvatar() {
  return Text(
    username.isNotEmpty ? username[0].toUpperCase() : 'G',
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
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

  List<Map<String, dynamic>> _getTopRatedHotels(List<Map<String, dynamic>> hotels) {
    List<Map<String, dynamic>> sortedHotels = List.from(hotels);
    sortedHotels.sort((a, b) {
      double ratingA = double.tryParse(a['rating']?.toString() ?? '0.0') ?? 0.0;
      double ratingB = double.tryParse(b['rating']?.toString() ?? '0.0') ?? 0.0;
      return ratingB.compareTo(ratingA); // Sort descending
    });
    return sortedHotels.take(5).toList(); // Take top 5
  }

  Future<void> _loadRecentlyViewedHotels() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String>? hotelIds = prefs.getStringList(_recentlyViewedKey);

    if (hotelIds != null && _hotels.isNotEmpty) {
      final loadedRecent = <Map<String, dynamic>>[];
      for (String id in hotelIds) {
        try {
          final hotel = _hotels.firstWhere((h) => h['id'] == id);
          loadedRecent.add(hotel);
        } catch (e) {
          // Hotel with this ID not found in current _hotels list, might have been deleted
          print("Recently viewed hotel with ID $id not found.");
        }
      }
      if (mounted) {
        setState(() {
          _recentlyViewedHotels = loadedRecent;
        });
      }
    }
  }

  Future<void> _addRecentlyViewedHotel(Map<String, dynamic> hotel) async {
    if (!mounted || hotel['id'] == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    List<Map<String, dynamic>> updatedRecent = List.from(_recentlyViewedHotels);

    // Remove if already exists to move it to the front
    updatedRecent.removeWhere((h) => h['id'] == hotel['id']);
    
    // Add to the beginning
    updatedRecent.insert(0, hotel);

    // Limit the list size
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
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              // borderRadius: BorderRadius.only(
              //   bottomLeft: Radius.circular(20),
              //   bottomRight: Radius.circular(20),
              // ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trouvez votre prochain séjour',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recherchez des offres sur les hôtels, les maisons et bien plus encore...',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Paris, Hôtel de la plage...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // Recently Viewed Section
        if (_recentlyViewedHotels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRecommendationSection(
              title: 'Consultés récemment',
              hotels: _recentlyViewedHotels,
              isLoading: _isLoading, // Pass loading state
            ),
          ),
        
        // Top Rated Section
        if (_topRatedHotels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRecommendationSection(
              title: 'Hôtels les Mieux Notés',
              hotels: _topRatedHotels,
              isLoading: _isLoading, // Pass loading state
            ),
          ),

        // Featured Hotels Section (Original "Featured" or "All Hotels" if search is empty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              _searchQuery.isEmpty ? 'Hôtels populaires' : 'Résultats de recherche',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ),
        _isLoading && filteredHotels.isEmpty // Show loader if loading and no results yet
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            : filteredHotels.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _searchQuery.isEmpty ? 'Aucun hôtel disponible pour le moment.' : 'Aucun hôtel ne correspond à votre recherche.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildHotelCard(filteredHotels[index]);
                        },
                        childCount: filteredHotels.length,
                      ),
                    ),
                  ),
      ],
    );
  }
}