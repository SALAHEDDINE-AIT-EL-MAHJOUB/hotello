import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application_1/add_hotel_page.dart';
import 'package:flutter_application_1/edit_hotel_page.dart';
// Ajoutez cet import pour gérer l'authentification
import 'package:firebase_auth/firebase_auth.dart';
// Importez votre écran de connexion ici - assurez-vous que le chemin est correct
import 'package:flutter_application_1/login_page.dart'; // Adaptez le chemin selon votre structure
// Ajoutez cet import en haut du fichier
import 'package:flutter_application_1/clients_page.dart';
import 'package:flutter_application_1/admin_tour_services_page.dart'; // Add this import

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> _hotels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseDatabase.instance.ref('hotels').get();
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> loadedHotels = [];
        data.forEach((key, value) {
          // Ensure value is a Map
          if (value is! Map) return;

          // Convert features to List<String> safely
          List<String> features = [];
          if (value['features'] is List) {
            for (var feature in (value['features'] as List)) {
              features.add(feature.toString());
            }
          }

          loadedHotels.add({
            'id': key,
            'name': value['name'] ?? 'N/A',
            'location': value['location'] ?? 'N/A',
            'price': value['price']?.toString() ?? 'N/A',
            'rating': value['rating']?.toString() ?? 'N/A',
            'imageData': value['imageData'],
            'description': value['description'] ?? '',
            'features': features,
            'phone': value['phone'] ?? '',
          });
        });

        setState(() {
          _hotels = loadedHotels;
        });
      } else {
        setState(() {
          _hotels = [];
        });
      }
    } catch (e) {
      if (mounted) { // Check if widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des hôtels: $e')),
        );
      }
    } finally {
      if (mounted) { // Check if widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToAddHotel() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddHotelPage())
    );
    if (result == true) {
      _loadHotels();
    }
  }

  Future<void> _editHotel(Map<String, dynamic> hotel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditHotelPage(hotelToEdit: hotel))
    );
    if (result == true) {
      _loadHotels();
    }
  }

  Future<void> _deleteHotel(String hotelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet hôtel ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseDatabase.instance.ref('hotels').child(hotelId).remove();
        _loadHotels(); // Refresh list
        if (mounted) { // Check if widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hôtel supprimé avec succès')),
          );
        }
      } catch (e) {
        if (mounted) { // Check if widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }

  void _navigateToClientsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientsPage()),
    );
  }

  // Method to navigate to AdminTourServicesPage
  void _navigateToManageTourServicesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminTourServicesPage()),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hotel['imageData'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.memory(
                base64Decode(hotel['imageData']),
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 180,
                  child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                ),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(child: Icon(Icons.hotel_rounded, size: 60, color: Colors.grey)),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel['name'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(hotel['location'], style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 8),
                Text('Prix: ${hotel['price'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Text('Note: ${hotel['rating'] ?? 'N/A'}'),
                if (hotel['features'] != null && (hotel['features'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fonctionnalités:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 6.0,
                          children: (hotel['features'] as List).map<Widget>((feature) {
                            return Chip(
                              label: Text(
                                feature.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (hotel['phone'] != null && hotel['phone'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(hotel['phone'].toString()),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _editHotel(hotel),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _deleteHotel(hotel['id']),
                      icon: const Icon(Icons.delete),
                      label: const Text('Supprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'), // Updated title
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Gérer les clients',
            onPressed: _navigateToClientsPage,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Panneau d\'Administration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Option to manage Tour Services
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined, color: Colors.teal, size: 30),
                      title: const Text('Gérer les Services de Guide/Tourisme', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('Ajouter, modifier ou supprimer des services'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      onTap: _navigateToManageTourServicesPage,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hotels Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestion des Hôtels',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Ajouter Hôtel'),
                        onPressed: _navigateToAddHotel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _hotels.isEmpty
                        ? const Center(
                            child: Text('Aucun hôtel ajouté pour le moment.\nCliquez sur "Ajouter Hôtel" pour commencer.', textAlign: TextAlign.center),
                          )
                        : ListView.builder(
                            itemCount: _hotels.length,
                            itemBuilder: (context, index) {
                              final hotel = _hotels[index];
                              return _buildHotelCard(hotel);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isLoading 
          ? null 
          : FloatingActionButton.extended(
              onPressed: _navigateToAddHotel, // Or remove if the button above is sufficient
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un Hôtel'),
            ),
    );
  }
}