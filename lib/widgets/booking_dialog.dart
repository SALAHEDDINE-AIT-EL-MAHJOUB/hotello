import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/booking.dart';

class BookingDialog extends StatefulWidget {
  final Map<String, dynamic> hotel;

  const BookingDialog({super.key, required this.hotel});

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  DateTime? checkInDate;
  DateTime? checkOutDate;
  bool isLoading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final double pricePerNight = double.tryParse(widget.hotel['price'].toString()) ?? 0;
    final int numberOfNights = checkOutDate != null && checkInDate != null
        ? checkOutDate!.difference(checkInDate!).inDays
        : 0;
    final double totalPrice = pricePerNight * numberOfNights;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Réserver ${widget.hotel['name']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date d\'arrivée'),
              subtitle: Text(checkInDate?.toString().split(' ')[0] ?? 'Sélectionner'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    checkInDate = date;
                    if (checkOutDate != null && checkOutDate!.isBefore(date)) {
                      checkOutDate = null;
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Date de départ'),
              subtitle: Text(checkOutDate?.toString().split(' ')[0] ?? 'Sélectionner'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                if (checkInDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionnez d\'abord la date d\'arrivée')),
                  );
                  return;
                }
                final date = await showDatePicker(
                  context: context,
                  initialDate: checkInDate!.add(const Duration(days: 1)),
                  firstDate: checkInDate!.add(const Duration(days: 1)),
                  lastDate: checkInDate!.add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() => checkOutDate = date);
                }
              },
            ),
            const SizedBox(height: 16),
            if (numberOfNights > 0) ...[
              Text(
                'Prix total: \$${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('$numberOfNights nuits à \$${pricePerNight.toStringAsFixed(2)}/nuit'),
              const SizedBox(height: 16),
            ],
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoading || checkInDate == null || checkOutDate == null
                      ? null
                      : () => _handleBooking(context, totalPrice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('Confirmer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBooking(BuildContext context, double totalPrice) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour réserver')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Créer la référence de la base de données
      final bookingsRef = FirebaseDatabase.instance.ref('bookings');
      
      // Générer un ID unique pour la réservation
      final newBookingRef = bookingsRef.push();
      final bookingId = newBookingRef.key;

      if (bookingId == null) throw Exception('Impossible de générer l\'ID de réservation');

      // Créer les données de réservation
      final bookingData = {
        'id': bookingId,
        'hotelId': widget.hotel['id'],
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'userEmail': user.email ?? 'No email',
        'hotelName': widget.hotel['name'],
        'checkIn': checkInDate!.millisecondsSinceEpoch,
        'checkOut': checkOutDate!.millisecondsSinceEpoch,
        'totalPrice': totalPrice,
        'status': 'confirmed',
        'createdAt': ServerValue.timestamp,
      };

      // Sauvegarder la réservation
      await newBookingRef.set(bookingData);

      if (context.mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservation confirmée!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur de réservation: $e');
      setState(() {
        errorMessage = 'Erreur lors de la réservation. Veuillez réessayer.';
        isLoading = false;
      });
    }
  }

  Future<bool> _checkBookedDates() async {
    final bookingsSnapshot = await FirebaseDatabase.instance
        .ref()
        .child('bookings')
        .orderByChild('hotelId')
        .equalTo(widget.hotel['id'])
        .get();

    if (bookingsSnapshot.exists) {
      final bookings = bookingsSnapshot.value as Map;
      for (var booking in bookings.values) {
        final bookingCheckIn = DateTime.fromMillisecondsSinceEpoch(booking['checkIn']);
        final bookingCheckOut = DateTime.fromMillisecondsSinceEpoch(booking['checkOut']);

        if (checkInDate!.isBefore(bookingCheckOut) &&
            checkOutDate!.isAfter(bookingCheckIn)) {
          return true; // Dates are already booked
        }
      }
    }
    return false; // Dates are available
  }
}