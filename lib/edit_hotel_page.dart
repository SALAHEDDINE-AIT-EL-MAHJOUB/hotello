import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditHotelPage extends StatefulWidget {
  final Map<String, dynamic> hotelToEdit;

  const EditHotelPage({super.key, required this.hotelToEdit});

  @override
  State<EditHotelPage> createState() => _EditHotelPageState();
}

class _EditHotelPageState extends State<EditHotelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController(); // Nouveau contrôleur pour le téléphone
  final _ratingController = TextEditingController();
  File? _hotelImage;
  bool _isLoading = false;
  String? _currentEditingHotelId;
  
  // Liste des fonctionnalités disponibles
  final List<String> _availableFeatures = ['Wifi', 'Piscine', 'Spa', 'Restaurant', 'Parking', 'Gym', 'Vue mer', 'Pet-friendly'];

  // Fonctionnalités sélectionnées par l'administrateur
  final Set<String> _selectedFeatures = {};
  
  @override
  void initState() {
    super.initState();
    
    // Remplir le formulaire avec les données de l'hôtel
    _currentEditingHotelId = widget.hotelToEdit['id'];
    _nameController.text = widget.hotelToEdit['name'] ?? '';
    _locationController.text = widget.hotelToEdit['location'] ?? '';
    _priceController.text = widget.hotelToEdit['price'] ?? '';
    _ratingController.text = widget.hotelToEdit['rating'] ?? '';
    _phoneController.text = widget.hotelToEdit['phone'] ?? ''; // Initialiser le numéro de téléphone
    
    // Initialiser les fonctionnalités sélectionnées
    if (widget.hotelToEdit['features'] != null) {
      if (widget.hotelToEdit['features'] is List) {
        for (var feature in widget.hotelToEdit['features']) {
          _selectedFeatures.add(feature.toString());
        }
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _phoneController.dispose(); // Libérer le contrôleur de téléphone
    _ratingController.dispose();
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

  Future<void> _updateHotel() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs requis')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      String? base64Image;
      
      // Convertir l'image en base64 seulement si une nouvelle image est sélectionnée
      if (_hotelImage != null) {
        List<int> imageBytes = await _hotelImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }
      
      // Générer description basée sur les fonctionnalités
      String description = 'Cet établissement';
      if (_selectedFeatures.isNotEmpty) {
        description += ' offre les services suivants : ${_selectedFeatures.join(', ')}.';
      } else {
        description += ' ne propose pas encore de services spécifiques.';
      }
      
      // Mise à jour de l'hôtel existant
      final hotelRef = FirebaseDatabase.instance.ref('hotels').child(_currentEditingHotelId!);
      
      // Créer le Map des données à mettre à jour
      final updates = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'price': _priceController.text.trim(),
        'rating': _ratingController.text.trim(),
        'phone': _phoneController.text.trim(), // Téléphone
        'description': description,
        'features': _selectedFeatures.toList(), // Fonctionnalités
        'updatedAt': ServerValue.timestamp,
      };
      
      // Ajouter l'image seulement si une nouvelle est fournie
      if (base64Image != null) {
        updates['imageData'] = base64Image;
      }
      
      // Mettre à jour l'hôtel
      await hotelRef.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hôtel mis à jour avec succès!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'hôtel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Mise à jour impossible de l\'hôtel: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier l\'hôtel'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
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
                              : widget.hotelToEdit['imageData'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        base64Decode(widget.hotelToEdit['imageData']),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.add_photo_alternate,
                                        size: 50,
                                        color: Colors.grey,
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
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un numéro de téléphone';
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
                            // ...
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _updateHotel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mettre à jour l\'hôtel'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
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