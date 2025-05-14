import 'dart:convert'; // Add this for base64Decode
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application_1/models/tour_service_model.dart';
import 'package:flutter_application_1/excursion_detail_page.dart'; // Ajoutez cet import

class TourGuideServicePage extends StatefulWidget {
  const TourGuideServicePage({super.key});

  @override
  State<TourGuideServicePage> createState() => _TourGuideServicePageState();
}

class _TourGuideServicePageState extends State<TourGuideServicePage> {
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  List<TourService> _fetchedExcursions = [];
  bool _isLoadingExcursions = true;

  @override
  void initState() {
    super.initState();
    _loadExcursions();
  }

  Future<void> _loadExcursions() async {
    if (!mounted) return;
    setState(() => _isLoadingExcursions = true);
    try {
      final dbRef = FirebaseDatabase.instance.ref('tourServices');
      final snapshot = await dbRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final List<TourService> loadedExcursions = [];
        data.forEach((key, value) {
          if (value is Map) {
            try {
              if (key is String) {
                loadedExcursions.add(TourService.fromJson(value as Map<dynamic, dynamic>, key));
              } else {
                debugPrint('Clé non-String ignorée dans tourServices: $key');
              }
            } catch (e) {
              debugPrint('Erreur lors de la désérialisation du service (tourServices) avec la clé $key: $e. Données: $value');
            }
          } else {
             debugPrint('Donnée non-Map ignorée dans tourServices pour la clé $key: $value');
          }
        });
        if (mounted) {
          setState(() {
            _fetchedExcursions = loadedExcursions;
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _fetchedExcursions = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading excursions: $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load excursions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingExcursions = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos Services de Guide', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Découvrez le Maroc avec nos guides locaux experts !',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 25),

          _buildSectionTitle('Excursions d\'une journée'),
          _isLoadingExcursions
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ))
              : _fetchedExcursions.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Aucune excursion disponible pour le moment."),
                    ))
                  // MODIFIED: Pass _fetchedExcursions directly
                  : _buildExcursionList(_fetchedExcursions),
          const SizedBox(height: 25),

          // --- Section "Comment réserver" ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  'Comment réserver ou en savoir plus ?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Contactez notre réception pour discuter de vos besoins, obtenir des devis et organiser votre expérience de guide touristique inoubliable.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Contacter la Réception'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Action de contact à implémenter.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: const Text('Infos Générales Tourisme Maroc'),
                    onPressed: () {
                      _launchURL('https://www.visitmorocco.com/fr');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // Renamed and modified to accept List<TourService>
  Widget _buildExcursionList(List<TourService> services) {
    return SizedBox(
      height: 230, // Vous pouvez ajuster la hauteur si nécessaire
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return _buildHorizontalListItem(
            isBase64Image: true,
            imageUrl: service.imageUrl,
            title: service.title,
            subtitle: service.subtitle, // Ce sous-titre est celui affiché sur la carte
            onTap: () {
              // Navigation vers la page de détail
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExcursionDetailPage(excursion: service),
                ),
              );
              debugPrint('Tapped on: ${service.title}, navigating to detail page.');
            },
          );
        },
      ),
    );
  }

  Widget _buildHorizontalListItem({
    required String imageUrl,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool isBase64Image = false, // Flag to differentiate image source
  }) {
    // Helper function to build image widget based on source
    Widget _buildImageWidget() {
      if (imageUrl.isEmpty) { // Handle empty imageUrl string
        return Container(
          height: 120,
          width: double.infinity,
          color: Colors.grey[200],
          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 40),
        );
      }
      if (isBase64Image) {
        try {
          // Ensure the base64 string is valid before decoding
          final UriData? data = Uri.tryParse(imageUrl)?.data;
          if (data != null && data.isBase64) {
             return Image.memory(
              data.contentAsBytes(),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey[200],
                child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40),
              ),
              gaplessPlayback: true, // To avoid flicker on image change
            );
          } else {
            // Attempt direct base64 decode if not a data URI, but be cautious
             return Image.memory(
              base64Decode(imageUrl.split(',').last), // Handles 'data:image/jpeg;base64,' prefix if present
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint("Error decoding base64 image for '$title': $error");
                return Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40),
                );
              },
              gaplessPlayback: true,
            );
          }
        } catch (e) {
          debugPrint("Exception decoding base64 image for '$title': $e");
          return Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40),
          );
        }
      } else {
        return Image.network(
          imageUrl, // This is a web URL
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 120,
              width: double.infinity,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10.0),
                topRight: Radius.circular(10.0),
              ),
              child: _buildImageWidget(), // Use the helper to build the image
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle, // Ce sous-titre est celui affiché sur la carte
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}