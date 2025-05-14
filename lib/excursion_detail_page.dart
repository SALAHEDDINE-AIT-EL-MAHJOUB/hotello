import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour TextInputFormatter
import 'package:flutter_application_1/models/tour_service_model.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import pour l'authentification
import 'package:firebase_database/firebase_database.dart'; // Import pour la base de données
// import 'package:uuid/uuid.dart'; // Pas nécessaire si on utilise push() pour l'ID

class ExcursionDetailPage extends StatefulWidget {
  final TourService excursion;

  const ExcursionDetailPage({super.key, required this.excursion});

  @override
  State<ExcursionDetailPage> createState() => _ExcursionDetailPageState();
}

class _ExcursionDetailPageState extends State<ExcursionDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _numberOfPeopleController = TextEditingController(text: '1');
  int _numberOfPeople = 1;
  bool _isBooking = false; // Pour gérer l'état de chargement du bouton

  @override
  void initState() {
    super.initState();
    _numberOfPeopleController.addListener(() {
      final number = int.tryParse(_numberOfPeopleController.text);
      if (number != null && number > 0) {
        if (mounted) {
          setState(() {
            _numberOfPeople = number;
          });
        }
      }
    });
  }

  Widget _buildDetailImage(BuildContext context) {
    if (widget.excursion.imageUrl.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey[300],
        child: Icon(Icons.image_not_supported_outlined, size: 100, color: Colors.grey[500]),
      );
    }
    try {
      final UriData? data = Uri.tryParse(widget.excursion.imageUrl)?.data;
      final bytes = data != null && data.isBase64
          ? data.contentAsBytes()
          : base64Decode(widget.excursion.imageUrl.split(',').last);

      return Image.memory(
        bytes,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint("Error decoding base64 image for detail page '${widget.excursion.title}': $error");
          return Container(
            height: 250,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image_outlined, size: 100, color: Colors.grey[500]),
          );
        },
      );
    } catch (e) {
      debugPrint("Exception decoding base64 image for detail page '${widget.excursion.title}': $e");
      return Container(
        height: 250,
        color: Colors.grey[300],
        child: Icon(Icons.broken_image_outlined, size: 100, color: Colors.grey[500]),
      );
    }
  }

  void _incrementPeople() {
    if (mounted) {
      setState(() {
        _numberOfPeople++;
        _numberOfPeopleController.text = _numberOfPeople.toString();
      });
    }
  }

  void _decrementPeople() {
    if (_numberOfPeople > 1) {
      if (mounted) {
        setState(() {
          _numberOfPeople--;
          _numberOfPeopleController.text = _numberOfPeople.toString();
        });
      }
    }
  }

  Future<void> _handleExcursionBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez vous connecter pour réserver une excursion.')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isBooking = true);

    try {
      final DatabaseReference bookingRef = FirebaseDatabase.instance.ref('excursionBookings').push();
      final String bookingId = bookingRef.key!;
      final int numberOfPeople = int.tryParse(_numberOfPeopleController.text) ?? 1;

      final bookingData = {
        'id': bookingId,
        'excursionId': widget.excursion.id,
        'excursionName': widget.excursion.title,
        'userId': currentUser.uid,
        'userEmail': currentUser.email ?? 'N/A',
        'userName': currentUser.displayName ?? 'N/A',
        'numberOfPeople': numberOfPeople,
        'bookingDate': DateTime.now().millisecondsSinceEpoch, // Date de la réservation
        'excursionDate': DateTime.now().millisecondsSinceEpoch, // Placeholder: vous devriez ajouter un sélecteur de date pour l'excursion
        'status': 'confirmed', // ou 'pending'
        'createdAt': ServerValue.timestamp,
      };

      await bookingRef.set(bookingData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.excursion.title} réservée pour $numberOfPeople personne(s) !'),
            backgroundColor: Colors.green,
          ),
        );
        // Optionnel: Naviguer ailleurs ou fermer la page
        // Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Erreur lors de la réservation de l\'excursion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réservation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  void dispose() {
    _numberOfPeopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.excursion.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildDetailImage(context),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.excursion.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (widget.excursion.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Text(
                        widget.excursion.subtitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
                      ),
                    ],
                    if (widget.excursion.category != null && widget.excursion.category!.isNotEmpty) ...[
                       const SizedBox(height: 8.0),
                       Chip(
                         label: Text(widget.excursion.category!),
                         backgroundColor: Colors.teal.withOpacity(0.1),
                         labelStyle: const TextStyle(color: Colors.teal),
                       ),
                    ],
                    const SizedBox(height: 16.0),
                    const Text(
                      'Description:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      widget.excursion.description.isNotEmpty ? widget.excursion.description : "Aucune description disponible.",
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nombre de personnes:',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.teal),
                              onPressed: _isBooking ? null : _decrementPeople,
                              tooltip: 'Moins',
                            ),
                            SizedBox(
                              width: 50,
                              child: TextFormField(
                                controller: _numberOfPeopleController,
                                textAlign: TextAlign.center,
                                enabled: !_isBooking,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8.0)
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requis';
                                  }
                                  final n = int.tryParse(value);
                                  if (n == null || n <= 0) {
                                    return 'Invalide';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                              onPressed: _isBooking ? null : _incrementPeople,
                              tooltip: 'Plus',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: _isBooking
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.calendar_today_outlined),
                    label: Text(_isBooking ? 'Réservation...' : 'Réserver cette excursion'),
                    onPressed: _isBooking ? null : _handleExcursionBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16)
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}