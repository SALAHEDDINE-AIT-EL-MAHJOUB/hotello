import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/services/hotel_importer.dart'; // Import the HotelImporter

class AddHotelPage extends StatefulWidget {
  const AddHotelPage({super.key});

  @override
  State<AddHotelPage> createState() => _AddHotelPageState();
}

class _AddHotelPageState extends State<AddHotelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ratingController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _hotelImage;
  bool _isLoading = false;
  bool _isImporting = false; // To track import loading state

  // Liste des fonctionnalités disponibles
  final List<String> _availableFeatures = ['Wifi', 'Piscine', 'Spa', 'Restaurant', 'Parking', 'Gym', 'Vue mer', 'Pet-friendly'];

  // Fonctionnalités sélectionnées par l'administrateur
  final Set<String> _selectedFeatures = {};

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _ratingController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _hotelImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _addHotel() async {
    if (!_formKey.currentState!.validate() || _hotelImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs et ajouter une image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      // Convertir l'image en base64
      List<int> imageBytes = await _hotelImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Créer un nouvel hôtel
      final newHotelRef = FirebaseDatabase.instance.ref('hotels').push();
      
      // Générer une description basée sur les fonctionnalités
      String description = _descriptionController.text.trim();
      if (_selectedFeatures.isNotEmpty) {
        description += '\n\nServices disponibles : ${_selectedFeatures.join(', ')}.';
      }
      
      await newHotelRef.set({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'price': _priceController.text.trim(),
        'rating': _ratingController.text.trim(),
        'phone': _phoneController.text.trim(), // Ajout du téléphone
        'description': description,
        'imageData': base64Image,
        'features': _selectedFeatures.toList(),
        'createdAt': ServerValue.timestamp,
      });

      // Revenir à la page précédente après réussite
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hôtel ajouté avec succès!')),
        );
        Navigator.pop(context, true); // Retourne true pour indiquer que des modifications ont été effectuées
      }
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'hôtel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Ajout impossible de l\'hôtel: $e')),
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

  Future<void> _importHotels() async {
    setState(() {
      _isImporting = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Démarrage de l\'importation des hôtels... Veuillez consulter la console pour les détails.')),
    );
    try {
      await HotelImporter.importHotelsFromCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importation des hôtels terminée. Vérifiez la console et Firebase.')),
        );
      }
    } catch (e) {
      print('Erreur lors de l\'importation des hôtels depuis la page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'importation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un nouvel hôtel'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading || _isImporting // Show loader if either operation is in progress
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _hotelImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _hotelImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Ajouter une image de l\'hôtel')
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de l\'hôtel',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le nom de l\'hôtel';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Emplacement',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer l\'emplacement';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Prix par nuit',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le prix';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ratingController,
                        decoration: const InputDecoration(
                          labelText: 'Note (ex. 4.5)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer la note';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          // Le téléphone est facultatif, pas de validation nécessaire
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Caractéristiques de l\'hôtel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _availableFeatures.map((feature) {
                          final isSelected = _selectedFeatures.contains(feature);
                          return FilterChip(
                            label: Text(feature),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedFeatures.add(feature);
                                } else {
                                  _selectedFeatures.remove(feature);
                                }
                              });
                            },
                            selectedColor: Colors.deepPurple.withOpacity(0.2),
                            checkmarkColor: Colors.deepPurple,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24), // Increased spacing
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _addHotel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Ajouter l\'hôtel manuellement'),
                        ),
                      ),
                      const SizedBox(height: 12), // Spacing between buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isImporting ? null : _importHotels, // Disable button when importing
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Different color for distinction
                            foregroundColor: Colors.white,
                          ),
                          child: _isImporting 
                               ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                               : const Text('Importer Hôtels depuis CSV'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0), // Adjusted spacing
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}