import 'dart:convert';
import 'dart:async'; // Import Timer
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'hotel_details_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' show cos, sqrt, asin;

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
  Position? _currentPosition;
  bool _isLocating = false;
  List<Map<String, dynamic>> _sortedHotelsByDistance = [];
  List<Map<String, dynamic>> _topRatedHotels = [];
  bool _isDistanceSortActive = false; // Nouveau: pour gérer le mode de tri par distance

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

  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    setState(() {
      _isLocating = true; // Pour l'indicateur du bouton
      // Tentative d'activation du mode distance, mais sera confirmé après obtention de la loc.
    });

    var status = await Permission.location.status;
    bool permissionGranted = status.isGranted;

    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      permissionGranted = await Permission.location.request().isGranted;
    }

    if (permissionGranted) {
      await _getCurrentLocationAndSort();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée.')),
        );
        setState(() {
          _isDistanceSortActive = false; // Échec de l'activation
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocationAndSort() async {
    // _isLocating devrait déjà être true
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _isDistanceSortActive = true; // Localisation obtenue, active le mode
        });
        _sortHotelsByDistance(useBaseHotels: true); // Trie tous les hôtels par distance
      }
    } catch (e) {
      print("Erreur de localisation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'obtenir la position: $e')),
        );
        setState(() {
          _isDistanceSortActive = false; // Échec de l'activation
          _currentPosition = null; // Assure que la position est nulle en cas d'erreur
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; // Pi / 180
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _sortHotelsByDistance({bool useBaseHotels = false}) {
    if (!mounted) return;

    if (_currentPosition == null || _hotels.isEmpty) {
      setState(() {
        // Si pas de position ou pas d'hôtels, _sortedHotelsByDistance reflète les filtres normaux
        _sortedHotelsByDistance = _getFilteredHotels();
        // _isDistanceSortActive sera géré par la fonction appelante si _currentPosition est null
      });
      return;
    }

    List<Map<String, dynamic>> sourceList = useBaseHotels ? _hotels : _getFilteredHotels();
    List<Map<String, dynamic>> tempHotels = List.from(sourceList);

    for (var hotel in tempHotels) {
      final double? hotelLat = hotel['latitude'] is String
          ? double.tryParse(hotel['latitude'])
          : hotel['latitude']?.toDouble();
      final double? hotelLon = hotel['longitude'] is String
          ? double.tryParse(hotel['longitude'])
          : hotel['longitude']?.toDouble();

      if (hotelLat != null && hotelLon != null) {
        hotel['distance'] = _calculateDistance(_currentPosition!.latitude,
            _currentPosition!.longitude, hotelLat, hotelLon);
      } else {
        hotel['distance'] = double.infinity;
      }
    }

    tempHotels.sort((a, b) {
      final distA = a['distance'] ?? double.infinity;
      final distB = b['distance'] ?? double.infinity;
      return distA.compareTo(distB);
    });

    setState(() {
      _sortedHotelsByDistance = tempHotels;
    });
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
            'latitude': value['latitude'], // Charger la latitude
            'longitude': value['longitude'], // Charger la longitude
          });
        });

        if (mounted) {
          setState(() {
            _hotels = loadedHotels;
            _cities = uniqueCities.toList()..sort();
            _isLoading = false;
            // Trie initialement basé sur les filtres actuels (aucun si c'est le premier chargement)
            // _isDistanceSortActive sera false ici, donc _sortHotelsByDistance triera _getFilteredHotels()
            _sortHotelsByDistance(); 
          });
          List<Map<String, dynamic>> sortedByRating = List.from(loadedHotels);
          sortedByRating.sort((a, b) {
            double ratingA = double.tryParse(a['rating'].toString()) ?? 0.0;
            double ratingB = double.tryParse(b['rating'].toString()) ?? 0.0;
            return ratingB.compareTo(ratingA); // Décroissant
          });
          _topRatedHotels = sortedByRating.take(5).toList();
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
    // Utiliser _hotels comme source si _sortedHotelsByDistance n'est pas encore pertinent
    // ou si on ne veut pas que le filtre de distance soit toujours appliqué avant les autres.
    // Pour l'instant, on filtre la liste de base _hotels.
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
    final hotelsToDisplay = _isDistanceSortActive && _currentPosition != null
        ? _sortedHotelsByDistance
        : _getFilteredHotels();
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
                onChanged: (_) => setState(() {
                  _isDistanceSortActive = false; // Désactive le tri par distance
                }),
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
                    selected: _selectedCity == null && !_isDistanceSortActive, // Ajusté
                    onSelected: (selected) {
                      setState(() {
                        _selectedCity = null;
                        _isDistanceSortActive = false; // Désactive le tri par distance
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
                    selected: _isPriceFiltered && !_isDistanceSortActive, // Ajusté
                    onSelected: (selected) {
                      setState(() {
                        _isDistanceSortActive = false; // Désactive le tri par distance
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
                  final isSelected = city == _selectedCity && !_isDistanceSortActive; // Ajusté
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(city),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCity = selected ? city : null;
                          _isDistanceSortActive = false; // Désactive le tri par distance
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
                  final isSelected = _selectedKeywords.contains(keyword) && !_isDistanceSortActive; // Ajusté
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(keyword),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _isDistanceSortActive = false; // Désactive le tri par distance
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _requestLocationPermission,
                icon: _isLocating 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                    : const Icon(Icons.my_location),
                label: const Text('Hôtels les plus proches'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            // Hotels List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hotelsToDisplay.isEmpty // Modifié ici
                    ? const Center(child: Text("Aucun hôtel trouvé."))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: hotelsToDisplay.length, // Modifié ici
                      itemBuilder: (context, index) {
                        final hotel = hotelsToDisplay[index]; // Modifié ici
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
    final distance = hotel['distance'];
    
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
                  if (distance != null && distance != double.infinity)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Distance: ${distance.toStringAsFixed(1)} km',
                        style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
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
    final hotelsToDisplay = _currentPosition != null && _sortedHotelsByDistance.isNotEmpty 
                           ? _sortedHotelsByDistance 
                           : _getFilteredHotels();
    final filteredCount = hotelsToDisplay.length; // Modifié ici
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