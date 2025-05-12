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
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon1 - lon1) * p)) / 2;
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
      // appBar: AppBar( // Optionnel: si vous voulez un AppBar ici
      //   title: const Text("Explorer les Hôtels"),
      //   backgroundColor: Colors.deepPurple,
      // ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Afficher les filtres actifs
            if (_selectedKeywords.isNotEmpty)
              Container(
                color: Colors.deepPurple.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Ajusté
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.deepPurple.shade300, size: 20), // Style
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtres: ${_selectedKeywords.join(", ")}', // Style
                        style: TextStyle(
                          color: Colors.deepPurple.shade700, // Style
                          fontWeight: FontWeight.w500, // Style
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedKeywords.clear();
                          _isDistanceSortActive = false; // Désactiver le tri par distance
                        });
                      },
                      icon: Icon(Icons.clear, size: 18, color: Colors.deepPurple.shade300), // Style
                      label: Text('Effacer', style: TextStyle(color: Colors.deepPurple.shade400)), // Style
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Ajusté
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un hôtel, une ville...', // Texte plus clair
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600), // Style
                  filled: true,
                  fillColor: Colors.grey.shade200, // Couleur de fond plus douce
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25), // Plus arrondi
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), // Ajusté
                ),
                onChanged: (_) => setState(() {
                  _isDistanceSortActive = false; 
                }),
              ),
            ),

            // Filter row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Ajusté
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous'), // Style
                    selected: _selectedCity == null && !_isDistanceSortActive,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCity = null;
                        _isDistanceSortActive = false; 
                      });
                    },
                    backgroundColor: Colors.grey.shade200, // Style
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    checkmarkColor: Colors.deepPurple,
                    labelStyle: TextStyle(color: _selectedCity == null && !_isDistanceSortActive ? Colors.deepPurple : Colors.black87), // Style
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Style
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Prix', style: TextStyle(color: _isPriceFiltered && !_isDistanceSortActive ? Colors.deepPurple : Colors.black87)), // Style
                        const SizedBox(width: 4),
                        Icon(
                          _isPriceFiltered
                              ? (_isLowToHigh ? Icons.arrow_upward : Icons.arrow_downward)
                              : Icons.monetization_on_outlined, // Icône différente
                          size: 18, // Style
                          color: _isPriceFiltered && !_isDistanceSortActive ? Colors.deepPurple : Colors.grey.shade700, // Style
                        ),
                      ],
                    ),
                    selected: _isPriceFiltered && !_isDistanceSortActive,
                    onSelected: (selected) {
                      setState(() {
                        _isDistanceSortActive = false; 
                        if (_isPriceFiltered && !selected) {
                          _isPriceFiltered = false;
                        } else if (!_isPriceFiltered && selected) {
                          _isPriceFiltered = true;
                          _isLowToHigh = true; 
                        } else {
                          _isLowToHigh = !_isLowToHigh;
                        }
                      });
                    },
                    backgroundColor: Colors.grey.shade200, // Style
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    checkmarkColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Style
                  ),
                ],
              ),
            ),
            // Cities list
            if (_cities.isNotEmpty)
              SizedBox(
                height: 45, // Ajusté
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Ajusté
                  itemCount: _cities.length,
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final isSelected = city == _selectedCity && !_isDistanceSortActive;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(city, style: TextStyle(color: isSelected ? Colors.deepPurple : Colors.black87)), // Style
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCity = selected ? city : null;
                            _isDistanceSortActive = false; 
                          });
                        },
                        backgroundColor: Colors.grey.shade200, // Style
                        selectedColor: Colors.deepPurple.withOpacity(0.2),
                        checkmarkColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Style
                      ),
                    );
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 4.0), // Ajusté
              child: Text(
                'Caractéristiques populaires', // Titre plus engageant
                style: TextStyle(
                  fontWeight: FontWeight.w600, // Style
                  color: Colors.grey.shade800, // Style
                  fontSize: 16,
                ),
              ),
            ),
            // Keywords filter chips
            SizedBox(
              height: 45, // Ajusté
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Ajusté
                itemCount: _keywords.length,
                itemBuilder: (context, index) {
                  final keyword = _keywords[index];
                  final isSelected = _selectedKeywords.contains(keyword) && !_isDistanceSortActive;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(keyword, style: TextStyle(color: isSelected ? Colors.deepPurple : Colors.black87)), // Style
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _isDistanceSortActive = false; 
                          if (selected) {
                            _selectedKeywords.add(keyword);
                          } else {
                            _selectedKeywords.remove(keyword);
                          }
                        });
                      },
                      backgroundColor: Colors.grey.shade200, // Style
                      selectedColor: Colors.deepPurple.withOpacity(0.2),
                      checkmarkColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Style
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Ajusté
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _requestLocationPermission,
                icon: _isLocating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.my_location, size: 20), // Style
                label: const Text('Hôtels les plus proches'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade400, // Couleur ajustée
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Style
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), // Style
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), // Style
                ),
              ),
            ),
            // Hotels List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple)) // Style
                  : hotelsToDisplay.isEmpty
                      ? Center(
                          child: Column( // Amélioration de l'état vide
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text("Aucun hôtel ne correspond.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text("Essayez d'ajuster vos filtres.", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                            ],
                          )
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Ajusté
                          itemCount: hotelsToDisplay.length,
                          itemBuilder: (context, index) {
                            final hotel = hotelsToDisplay[index];
                            return _buildHotelCard(hotel);
                          },
                        ),
            ),
            if (!_isLoading && hotelsToDisplay.isNotEmpty) _buildResultsCount(), // Afficher seulement si non vide et non en chargement
          ],
        ),
      ),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    List<dynamic> features = [];
    if (hotel['features'] != null) {
      features = hotel['features'] is List ? hotel['features'] : [hotel['features']];
    }
    final distance = hotel['distance'];

    return Card(
      margin: const EdgeInsets.only(bottom: 20), // Plus d'espace
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Plus arrondi
      ),
      elevation: 4, // Ombre plus prononcée
      shadowColor: Colors.deepPurple.withOpacity(0.1), // Ombre colorée
      child: InkWell(
        borderRadius: BorderRadius.circular(15), // Doit correspondre à la Card
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HotelDetailsPage(
                hotelData: hotel,
                hotelId: hotel['id'] as String,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), // Correspondre
              child: _buildHotelImage(hotel['imageData'], hotel['imageUrl']),
            ),
            Padding(
              padding: const EdgeInsets.all(16), // Plus de padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel['name'],
                    style: const TextStyle(
                      fontSize: 20, // Plus grand
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, // Couleur plus foncée
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade700), // Icône différente
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hotel['location'],
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14), // Style
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade600), // Icône différente et plus grande
                      const SizedBox(width: 4),
                      Text(
                        '${hotel['rating']}', // Juste le nombre
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 15, fontWeight: FontWeight.bold), // Style
                      ),
                      Text(' (${(int.tryParse(hotel['rating'].toString().split('.').last) ?? 0) * 10}+ avis)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), // Exemple d'avis
                      const Spacer(),
                      Text(
                        '\$${hotel['price']}', // Prix plus simple
                        style: const TextStyle(
                          fontSize: 20, // Plus grand
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Text('/nuit', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)), // Style
                    ],
                  ),
                  if (distance != null && distance != double.infinity)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.directions_walk, size: 16, color: Colors.teal.shade400), // Icône
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(color: Colors.teal.shade600, fontWeight: FontWeight.w500, fontSize: 13), // Style
                          ),
                        ],
                      ),
                    ),
                  if (features.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Wrap(
                        spacing: 8.0, // Style
                        runSpacing: 6.0, // Style
                        children: features.take(3).map<Widget>((feature) {
                          return Chip(
                            avatar: Icon(Icons.check_circle_outline, size: 16, color: Colors.deepPurple.shade300), // Icône
                            label: Text(feature.toString(), style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700)), // Style
                            backgroundColor: Colors.deepPurple.withOpacity(0.08), // Style
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Style
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  if (features.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        '+${features.length - 3} autres caractéristiques', // Texte plus clair
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
      height: 180, // Hauteur cohérente pour la carte
      width: double.infinity,
      decoration: BoxDecoration( // Style
        color: Colors.grey.shade200,
        // borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), // Si vous voulez arrondir seulement le placeholder
      ),
      child: Icon(Icons.hotel_rounded, size: 60, color: Colors.grey.shade400), // Icône différente
    );
  }

  Widget _buildResultsCount() {
    final hotelsToDisplay = _currentPosition != null && _sortedHotelsByDistance.isNotEmpty 
                           ? _sortedHotelsByDistance 
                           : _getFilteredHotels();
    final filteredCount = hotelsToDisplay.length; // Modifié ici
    final totalCount = _hotels.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), // Ajusté
      child: Text(
        filteredCount == totalCount
            ? '$totalCount hôtels disponibles' // Texte plus clair
            : '$filteredCount sur $totalCount hôtels affichés', // Texte plus clair
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13, // Style
        ),
        textAlign: TextAlign.center, // Style
      ),
    );
  }
}