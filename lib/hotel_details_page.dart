import 'dart:convert'; // For base64Decode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/booking_dialog.dart';

class HotelDetailsPage extends StatelessWidget {
  final Map<String, dynamic> hotelData; // MODIFIED: Changed type to Map<String, dynamic>
  final String hotelId;

  const HotelDetailsPage({super.key, required this.hotelData, required this.hotelId});

  @override
  Widget build(BuildContext context) {
    final String name = hotelData['name'] ?? 'Nom non disponible';
    final String location = hotelData['location'] ?? 'Lieu non disponible';
    final String price = hotelData['price']?.toString() ?? 'N/A';
    final String description = hotelData['description'] ?? 'Aucune description disponible.';
    final String phone = hotelData['phone'] ?? 'Contact non disponible';
    final String? imageUrl = hotelData['imageUrl'] as String?;
    final String? imageData = hotelData['imageData'] as String?;

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
              softWrap: true, // ADDED: To allow text to wrap
              // OU pour couper avec des ellipses si trop long sur plusieurs lignes :
              // overflow: TextOverflow.ellipsis,
              // maxLines: 2, 
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
              'Prix par nuit: \$${price}',
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
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => BookingDialog(hotel: hotelData),
                    );
                    
                    if (result == true) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
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