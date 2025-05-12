import 'dart:convert';
import 'dart:async'; // Import Timer
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'hotel_details_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _hotels = [];
  List<String> _cities = [];
  String? _selectedCity;
  bool _isLoading = true;
  bool _isLowToHigh = true;
  bool _isPriceFiltered = false;

  // Liste des mots-clés disponibles
  final List<String> _keywords = ['Wifi', 'Piscine', 'Spa', 'Restaurant', 'Parking', 'Gym', 'Vue mer', 'Pet-friendly'];

  // Mots-clés sélectionnés par l'utilisateur
  final Set<String> _selectedKeywords = {};

  Timer? _refreshTimer; // Timer for auto-refresh
  static const Duration _refreshInterval = Duration(minutes: 5); // Refresh every 5 minutes

  @override
  void initState() {
    super.initState();
    _loadHotels(); // Initial load
    // Start auto-refresh timer
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      print("Auto-refreshing hotels...");
      _loadHotels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _loadHotels() async {
    // To prevent multiple loads if already loading, though setState handles UI updates.
    // if (_isLoading && mounted) return; 

    if (mounted) { // Check if the widget is still in the tree
      setState(() => _isLoading = true);
    }
    
    try {
      final hotelsSnapshot = await FirebaseDatabase.instance.ref('hotels').get();
      
      if (hotelsSnapshot.exists && mounted) { // Check mounted again before setState
        final hotelsData = hotelsSnapshot.value as Map<dynamic, dynamic>;
        final Set<String> uniqueCities = {};
        final loadedHotels = <Map<String, dynamic>>[];

        hotelsData.forEach((key, value) {
          final location = value['location'] ?? 'Unknown Location';
          uniqueCities.add(location.toString());
          
          List<dynamic> features = [];
          if (value['features'] != null) {
            features = value['features'] is List ? value['features'] : [value['features'].toString()];
          }
          
          loadedHotels.add({
            'id': key,
            'name': value['name'] ?? 'Unknown Hotel',
            'location': location,
            'price': value['price'] ?? '0',
            'rating': value['rating'] ?? '0.0',
            'description': value['description'] ?? '',
            'imageData': value['imageData'],
            'imageUrl': value['imageUrl'],
            'features': features,
          });
        });

        if (mounted) {
          setState(() {
            _hotels = loadedHotels;
            _cities = uniqueCities.toList()..sort();
            _isLoading = false;
          });
        }
      } else if (mounted) {
         setState(() => _isLoading = false); // Also set isLoading to false if snapshot doesn't exist
      }
    } catch (e) {
      print('Error loading hotels: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredHotels() {
    final searchQuery = _searchController.text.toLowerCase();
    var filteredHotels = _hotels.where((hotel) {
      // Filtrage par ville
      final matchesCity = _selectedCity == null || hotel['location'] == _selectedCity;
      
      // Filtrage par requête de recherche
      final matchesSearch = searchQuery.isEmpty ||
          hotel['name'].toString().toLowerCase().contains(searchQuery) ||
          hotel['location'].toString().toLowerCase().contains(searchQuery);
      
      // Filtrage par caractéristiques sélectionnées
      bool matchesKeywords = true;
      if (_selectedKeywords.isNotEmpty) {
        // Vérifier d'abord les fonctionnalités directement
        List<dynamic> hotelFeatures = hotel['features'] ?? [];
        
        for (var keyword in _selectedKeywords) {
          // Vérifier si la fonctionnalité est présente dans la liste
          bool featureFound = hotelFeatures.any(
            (feature) => feature.toString().toLowerCase().contains(keyword.toLowerCase())
          );
          
          // Si pas trouvé dans les fonctionnalités, vérifier la description comme fallback
          if (!featureFound) {
            featureFound = hotel['description'].toString().toLowerCase().contains(keyword.toLowerCase());
          }
          
          if (!featureFound) {
            matchesKeywords = false;
            break;
          }
        }
      }
      
      return matchesCity && matchesSearch && matchesKeywords;
    }).toList();

    // Tri par prix
    if (_isPriceFiltered) {
      filteredHotels.sort((a, b) {
        final priceA = double.tryParse(a['price'].toString()) ?? 0;
        final priceB = double.tryParse(b['price'].toString()) ?? 0;
        return _isLowToHigh ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
      });
    }

    return filteredHotels;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Afficher les filtres actifs
            if (_selectedKeywords.isNotEmpty)
              Container(
                color: Colors.deepPurple.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.deepPurple, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtres actifs: ${_selectedKeywords.join(", ")}',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedKeywords.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Effacer'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search hotels, cities...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Filter row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // All button
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCity == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCity = null;
                      });
                    },
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    checkmarkColor: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  // Price filter button
                  FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Price'),
                        const SizedBox(width: 4),
                        Icon(
                          _isPriceFiltered 
                            ? (_isLowToHigh ? Icons.arrow_upward : Icons.arrow_downward)
                            : Icons.monetization_on,
                          size: 16,
                        ),
                      ],
                    ),
                    selected: _isPriceFiltered,
                    onSelected: (selected) {
                      setState(() {
                        if (_isPriceFiltered && !selected) {
                          // Deselecting the filter
                          _isPriceFiltered = false;
                        } else if (!_isPriceFiltered && selected) {
                          // Selecting the filter for the first time
                          _isPriceFiltered = true;
                          _isLowToHigh = true;
                        } else {
                          // Toggle sort direction when clicking while selected
                          _isLowToHigh = !_isLowToHigh;
                        }
                      });
                    },
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    checkmarkColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Cities list
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _cities.length,
                itemBuilder: (context, index) {
                  final city = _cities[index];
                  final isSelected = city == _selectedCity;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(city),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCity = selected ? city : null;
                        });
                      },
                      selectedColor: Colors.deepPurple.withOpacity(0.2),
                      checkmarkColor: Colors.deepPurple,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Keywords filter title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Caractéristiques',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 16, // Slightly larger for better visibility
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Keywords filter chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _keywords.length,
                itemBuilder: (context, index) {
                  final keyword = _keywords[index];
                  final isSelected = _selectedKeywords.contains(keyword);
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(keyword),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedKeywords.add(keyword);
                          } else {
                            _selectedKeywords.remove(keyword);
                          }
                        });
                      },
                      selectedColor: Colors.deepPurple.withOpacity(0.2),
                      checkmarkColor: Colors.deepPurple,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Hotels List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _getFilteredHotels().length,
                      itemBuilder: (context, index) {
                        final hotel = _getFilteredHotels()[index];
                        return _buildHotelCard(hotel);
                      },
                    ),
            ),
            _buildResultsCount(),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    // Récupérer les fonctionnalités
    List<dynamic> features = [];
    if (hotel['features'] != null) {
      features = hotel['features'] is List ? hotel['features'] : [hotel['features']];
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HotelDetailsPage(
                hotelData: hotel, // MODIFIED: Pass hotel as hotelData
                hotelId: hotel['id'] as String, // MODIFIED: Pass hotel id as hotelId
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: _buildHotelImage(hotel['imageData'], hotel['imageUrl']),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotel['location'],
                          style: TextStyle(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${hotel['rating']} ★',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(
                        '\$${hotel['price']}/night',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  
                  // Afficher les fonctionnalités disponibles si présentes
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
                  
                  // Afficher "+X more" si plus de 3 fonctionnalités
                  if (features.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '+${features.length - 3} autres',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelImage(String? imageData, String? imageUrl) {
    if (imageData != null && imageData.isNotEmpty) {
      try {
        final imageBytes = base64Decode(imageData);
        return Container(
          height: 150,
          width: double.infinity,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading base64 image: $error');
              return _buildPlaceholderImage();
            },
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return _buildPlaceholderImage();
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            return _buildPlaceholderImage();
          },
        ),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Icon(Icons.hotel, size: 50, color: Colors.grey),
    );
  }

  Widget _buildResultsCount() {
    final filteredCount = _getFilteredHotels().length;
    final totalCount = _hotels.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        filteredCount == totalCount 
          ? '$totalCount hôtels trouvés'
          : '$filteredCount sur $totalCount hôtels correspondent',
        style: TextStyle(
          color: Colors.grey[700],
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}