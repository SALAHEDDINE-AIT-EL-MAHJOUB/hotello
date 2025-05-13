import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LeaveReviewPage extends StatefulWidget {
  final String bookingId;
  final String hotelName;
  final String hotelId; // AJOUTER CECI

  const LeaveReviewPage({
    super.key,
    required this.bookingId,
    required this.hotelName,
    required this.hotelId, // AJOUTER CECI
  });

  @override
  State<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends State<LeaveReviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  final _ratingController = TextEditingController(); // Pour une note simple (ex: 1-5)
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté.'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final reviewData = {
        'userId': user.uid,
        'bookingId': widget.bookingId,
        'hotelName': widget.hotelName,
        'hotelId': widget.hotelId, // AJOUTER CECI
        'reviewText': _reviewController.text,
        'rating': int.tryParse(_ratingController.text) ?? 0, // Assurez-vous que c'est un nombre
        'timestamp': ServerValue.timestamp, // Pour trier par date
      };

      await FirebaseDatabase.instance.ref('reviews').push().set(reviewData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis soumis avec succès !'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Revenir à la page précédente
      }
    } catch (e) {
      print('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la soumission de l\'avis: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laisser un avis pour ${widget.hotelName}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // ListView pour éviter les problèmes de débordement avec le clavier
            children: [
              Text(
                'Vous évaluez : ${widget.hotelName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  labelText: 'Votre avis',
                  hintText: 'Décrivez votre expérience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer votre avis.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ratingController,
                decoration: const InputDecoration(
                  labelText: 'Note (1-5)',
                  hintText: 'Ex: 4',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une note.';
                  }
                  final rating = int.tryParse(value);
                  if (rating == null || rating < 1 || rating > 5) {
                    return 'Veuillez entrer une note entre 1 et 5.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitReview,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Soumettre l\'avis', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)
                        )
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}