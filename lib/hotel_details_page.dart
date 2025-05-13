import 'dart:convert'; // For base64Decode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Importer Firebase Database
import 'widgets/booking_dialog.dart';
import 'package:intl/intl.dart'; // Pour le formatage de la date des avis

// MODIFIED: Convert to StatefulWidget
class HotelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> hotelData;
  final String hotelId; // Gardez hotelId, c'est mieux pour filtrer les avis

  const HotelDetailsPage({super.key, required this.hotelData, required this.hotelId});

  @override
  State<HotelDetailsPage> createState() => _HotelDetailsPageState();
}

class _HotelDetailsPageState extends State<HotelDetailsPage> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviews = []; // Clear previous reviews
    });
    try {
      // Utiliser widget.hotelId pour filtrer les avis serait plus robuste.
      // Pour l'instant, on se base sur hotelName comme dans LeaveReviewPage.
      // Idéalement, LeaveReviewPage devrait aussi enregistrer hotelId.
      final reviewsSnapshot = await FirebaseDatabase.instance
          .ref('reviews')
          .orderByChild('hotelName') // Ou 'hotelId' si vous l'enregistrez
          .equalTo(widget.hotelData['name']) // Ou widget.hotelId
          .get();

      if (reviewsSnapshot.exists) {
        final reviewsData = reviewsSnapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> loadedReviews = [];

        for (var entry in reviewsData.entries) {
          final review = Map<String, dynamic>.from(entry.value as Map);
          review['id'] = entry.key; // L'ID de l'avis

          // Récupérer le nom de l'utilisateur
          final userId = review['userId'];
          if (userId != null) {
            final userSnapshot = await FirebaseDatabase.instance.ref('users').child(userId).get();
            if (userSnapshot.exists && userSnapshot.value != null) {
              final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
              review['userName'] = userData['name'] ?? userData['firstName'] ?? 'Utilisateur Anonyme';
            } else {
              review['userName'] = 'Utilisateur Anonyme';
            }
          } else {
            review['userName'] = 'Utilisateur Anonyme';
          }
          loadedReviews.add(review);
        }
        // Trier les avis par date (plus récent en premier)
        loadedReviews.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        _reviews = loadedReviews;
      }
    } catch (e) {
      print('Error loading reviews: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des avis: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text('Aucun avis pour cet hôtel pour le moment.')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Avis des clients (${_reviews.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true, // Important dans un SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(), // Pour désactiver le scroll interne
          itemCount: _reviews.length,
          itemBuilder: (context, index) {
            final review = _reviews[index];
            final DateTime reviewDate = review['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(review['timestamp'])
                : DateTime.now();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          review['userName'] ?? 'Utilisateur Anonyme',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (review['rating'] != null && review['rating'] > 0)
                          _buildStarRating(review['rating'] as int),
                      ],
                    ),
                    const SizedBox(height: 4),
                     Text(
                      DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(reviewDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(review['reviewText'] ?? ''),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // Les données de l'hôtel sont maintenant accessibles via widget.hotelData
    final String name = widget.hotelData['name'] ?? 'Nom non disponible';
    final String location = widget.hotelData['location'] ?? 'Lieu non disponible';
    final String price = widget.hotelData['price']?.toString() ?? 'N/A';
    final String description = widget.hotelData['description'] ?? 'Aucune description disponible.';
    final String phone = widget.hotelData['phone'] ?? 'Contact non disponible';
    final String? imageUrl = widget.hotelData['imageUrl'] as String?;
    final String? imageData = widget.hotelData['imageData'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'N/A')
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                    return _buildPlaceholderImage();
                  },
                ),
              )
            else if (imageData != null && imageData.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.memory(
                  base64Decode(imageData),
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                    return _buildPlaceholderImage();
                  },
                ),
              )
            else
              _buildPlaceholderImage(),

            const SizedBox(height: 16),

            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              softWrap: true,
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(location, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Prix par nuit: \$${price}', // Devise à adapter si besoin
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty && description != 'N/A' ? description : 'Aucune description fournie.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            Text(
              'Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  phone.isNotEmpty && phone != 'N/A' ? phone : 'Non disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            
            // Section des avis
            _buildReviewsSection(),

            const SizedBox(height: 32),

            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez vous connecter pour réserver'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    // Passez widget.hotelData et widget.hotelId au BookingDialog
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => BookingDialog(hotel: widget.hotelData, hotelId: widget.hotelId),
                    );
                    
                    if (result == true) {
                      if (context.mounted) {
                        // Optionnel: Revenir à la page précédente ou afficher un message
                        // Navigator.of(context).pop(); // Si vous voulez fermer HotelDetailsPage après réservation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Réservation confirmée!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Réserver maintenant'),
              ),
            ),
            const SizedBox(height: 20), // Espace en bas
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Icon(
        Icons.hotel,
        color: Colors.grey[600],
        size: 100,
      ),
    );
  }
}