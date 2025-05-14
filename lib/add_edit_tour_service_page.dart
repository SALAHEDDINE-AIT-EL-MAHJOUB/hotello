import 'dart:io';
import 'dart:convert'; // Import for base64 encoding
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/models/tour_service_model.dart';

class AddEditTourServicePage extends StatefulWidget {
  final TourService? tourService;

  const AddEditTourServicePage({super.key, this.tourService});

  @override
  State<AddEditTourServicePage> createState() => _AddEditTourServicePageState();
}

class _AddEditTourServicePageState extends State<AddEditTourServicePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;

  File? _serviceImageFile; // Holds the picked image file
  String? _imageBase64; // Holds the base64 string of the current image (newly picked or existing)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.tourService?.title ?? '');
    _subtitleController = TextEditingController(text: widget.tourService?.subtitle ?? '');
    _descriptionController = TextEditingController(text: widget.tourService?.description ?? '');
    _categoryController = TextEditingController(text: widget.tourService?.category ?? '');
    if (widget.tourService?.imageUrl != null && widget.tourService!.imageUrl.isNotEmpty) {
      _imageBase64 = widget.tourService!.imageUrl; // Assuming imageUrl from DB is base64
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800); // Added quality and size constraints
    if (pickedFile != null) {
      setState(() {
        _serviceImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation: Image is required for a new service
    if (_serviceImageFile == null && (_imageBase64 == null || _imageBase64!.isEmpty) && widget.tourService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une image pour le service.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    String? finalImageData;

    if (_serviceImageFile != null) {
      // New image picked, convert to base64
      try {
        final bytes = await _serviceImageFile!.readAsBytes();
        finalImageData = base64Encode(bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la conversion de l\'image: $e')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    } else {
      // No new image picked, use existing image data (already in _imageBase64 from initState)
      finalImageData = _imageBase64;
    }
    
    // Ensure there's image data if it's a new service or if it was required
    if ((finalImageData == null || finalImageData.isEmpty) && widget.tourService == null) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'image est requise.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // This object holds all data. For a new service, its 'id' field will be initially null.
    final tourServiceInstance = TourService(
      id: widget.tourService?.id, 
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrl: finalImageData ?? widget.tourService?.imageUrl ?? '', // Store base64 string
      category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
    );

    try {
      final dbRef = FirebaseDatabase.instance.ref('tourServices');
      if (widget.tourService?.id != null) {
        // Editing existing service: tourServiceInstance.id is already correct.
        await dbRef.child(widget.tourService!.id!).update(tourServiceInstance.toJson());
      } else {
        // Adding new service
        final newServiceRef = dbRef.push();
        // Create a new TourService instance for saving, 
        // using data from tourServiceInstance but with the 'id' field set to the new Firebase key.
        final serviceToSave = TourService(
          id: newServiceRef.key, // Assign the generated key as the ID
          title: tourServiceInstance.title,
          subtitle: tourServiceInstance.subtitle,
          description: tourServiceInstance.description,
          imageUrl: tourServiceInstance.imageUrl,
          category: tourServiceInstance.category,
          // Ensure all fields defined in the TourService constructor are copied here
        );
        await newServiceRef.set(serviceToSave.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Service ${widget.tourService == null ? "ajouté" : "mis à jour"} avec succès!')),
        );
        Navigator.pop(context, true); // Indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'enregistrement du service: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tourService == null ? 'Ajouter un Service Touristique' : 'Modifier le Service'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un titre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(labelText: 'Sous-titre (ex: Prix, Durée)', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un sous-titre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Veuillez entrer une description' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Catégorie (Optionnel)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Image display and picker
              Column(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7.0),
                      child: _serviceImageFile != null
                          ? Image.file(_serviceImageFile!, fit: BoxFit.cover)
                          : (_imageBase64 != null && _imageBase64!.isNotEmpty
                              ? Image.memory(base64Decode(_imageBase64!), fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Center(child: Text("Erreur d'affichage", textAlign: TextAlign.center,)))
                              : Center(
                                  child: Icon(Icons.photo_camera_back_outlined, size: 50, color: Colors.grey.shade500),
                                )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_search_outlined),
                    label: Text(_serviceImageFile != null || (_imageBase64 != null && _imageBase64!.isNotEmpty) ? 'Changer l\'Image' : 'Choisir une Image'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined),
                      onPressed: _saveService,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16)
                      ),
                      label: Text(widget.tourService == null ? 'Ajouter le Service' : 'Mettre à Jour'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dans votre fichier models/tour_service_model.dart
class TourService {
  final String? id;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl; // Doit être String
  final String? category;
  // ... autres champs potentiels comme price, location, duration

  TourService({
    this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    this.category,
    // ... initialisez les autres champs
  });

  // Assurez-vous que fromJson gère correctement imageUrl (qui sera une chaîne base64)
  factory TourService.fromJson(Map<dynamic, dynamic> json, String id) {
    return TourService(
      id: id,
      title: json['title'] ?? 'N/A',
      subtitle: json['subtitle'] ?? 'N/A',
      description: json['description'] ?? 'N/A',
      imageUrl: json['imageUrl'] ?? '', // Attendez-vous à une chaîne ici
      category: json['category'],
      // ... parsez les autres champs
    );
  }

  // Assurez-vous que toJson inclut imageUrl
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'imageUrl': imageUrl, // Assurez-vous que cela est inclus
      'category': category,
      // ... ajoutez les autres champs
    };
  }
}