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
      final hotelsSnapshot = await FirebaseDatabase.instance.ref('hotels').get();
      
      if (hotelsSnapshot.exists) {
        final hotelsData = hotelsSnapshot.value as Map<dynamic, dynamic>;
        final loadedHotels = <Map<String, dynamic>>[];

        hotelsData.forEach((key, value) {
          // Récupérer les fonctionnalités et les convertir en liste si nécessaire
          List<dynamic> features = [];
          if (value['features'] != null) {
            features = value['features'] is List ? value['features'] : [value['features']];
          }
          
          loadedHotels.add({
            'id': key,
            'name': value['name'],
            'location': value['location'],
            'price': value['price'],
            'rating': value['rating'],
            'description': value['description'],
            'imageData': value['imageData'],  // Récupération de l'image en base64
            'features': features,  // Ajout des fonctionnalités
            'phone': value['phone'] ?? '', // Ajout du téléphone
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des hôtels: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Méthode pour naviguer vers la page d'ajout d'hôtel
  Future<void> _navigateToAddHotel() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const AddHotelPage())
    );
    
    // Si des modifications ont été effectuées, recharger la liste
    if (result == true) {
      _loadHotels();
    }
  }
  
  // Méthode pour naviguer vers la page de modification d'hôtel
  Future<void> _editHotel(Map<String, dynamic> hotel) async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => EditHotelPage(hotelToEdit: hotel))
    );
    
    // Si des modifications ont été effectuées, recharger la liste
    if (result == true) {
      _loadHotels();
    }
  }
  
  // Méthode pour supprimer un hôtel
  Future<void> _deleteHotel(String hotelId) async {
    // Montrer une boîte de dialogue de confirmation
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
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FirebaseDatabase.instance.ref('hotels').child(hotelId).remove();
      await _loadHotels();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hôtel supprimé avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression de l\'hôtel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression de l\'hôtel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Nouvelle méthode pour la déconnexion - version corrigée
  Future<void> _logout() async {
    try {
      // Afficher une boîte de dialogue de confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) return;

      await FirebaseAuth.instance.signOut();
      
      // Remplacer la navigation par route nommée par une navigation directe
      if (mounted) {
        // Utilisez Navigator.pushReplacement au lieu de pushNamedAndRemoveUntil
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
  
  // Méthode pour naviguer vers la page des clients
  void _navigateToClientsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientsPage()),
    );
  }
  
  // Méthode pour afficher une carte d'hôtel
  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image from base64
          hotel['imageData'] != null 
              ? Image.memory(
                  base64Decode(hotel['imageData']),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 50),
                ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel['name'] ?? 'Inconnu',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(hotel['location'] ?? 'Emplacement inconnu'),
                const SizedBox(height: 4),
                Text('Prix: ${hotel['price'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Text('Note: ${hotel['rating'] ?? 'N/A'}'),
                
                // Afficher les fonctionnalités
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
                
                // Afficher le téléphone si disponible
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
                
                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bouton d'édition
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
                    // Bouton de suppression
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
        title: const Text('Administration des hôtels'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Bouton pour voir les clients
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Gérer les clients',
            onPressed: _navigateToClientsPage,
          ),
          // Bouton de déconnexion existant
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
                    'Liste des hôtels',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _hotels.isEmpty
                        ? const Center(
                            child: Text('Aucun hôtel ajouté pour le moment'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddHotel,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un hôtel'),
      ),
    );
  }
}