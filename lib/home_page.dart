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

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _setupSynchronization();
  }
  
  @override
  void dispose() {
    // Clean up listeners when widget is disposed
    _hotelsListener?.cancel();
    _userDataListener?.cancel();
    _syncTimer?.cancel();
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
}