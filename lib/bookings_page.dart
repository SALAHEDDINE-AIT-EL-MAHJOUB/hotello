import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final bookingsSnapshot = await FirebaseDatabase.instance
          .ref('bookings')
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      final List<Map<String, dynamic>> loadedBookings = [];

      if (bookingsSnapshot.exists) {
        final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
        bookingsData.forEach((key, value) {
          loadedBookings.add({
            'id': key,
            'hotelName': value['hotelName'] ?? 'Unknown Hotel',
            'checkIn': DateTime.fromMillisecondsSinceEpoch(value['checkIn']),
            'checkOut': DateTime.fromMillisecondsSinceEpoch(value['checkOut']),
            'totalPrice': value['totalPrice'] ?? 0.0,
            'status': value['status'] ?? 'pending',
          });
        });
      }

      setState(() {
        _bookings.clear();
        _bookings.addAll(loadedBookings);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      await FirebaseDatabase.instance
          .ref('bookings')
          .child(bookingId)
          .update({'status': 'cancelled'});
      
      _loadBookings(); // Reload bookings after cancellation
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation annulée')),
        );
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'annulation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Réservations', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(
                  child: Text('Aucune réservation trouvée'),
                )
              : ListView.builder(
                  itemCount: _bookings.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final isUpcoming = booking['checkIn'].isAfter(DateTime.now());
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          booking['hotelName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('dd/MM/yyyy').format(booking['checkIn'])} - '
                                  '${DateFormat('dd/MM/yyyy').format(booking['checkOut'])}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on, size: 16),
                                const SizedBox(width: 8),
                                Text('\$${booking['totalPrice'].toStringAsFixed(2)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(booking['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(booking['status']),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (isUpcoming && booking['status'] == 'confirmed')
                                  TextButton(
                                    onPressed: () => _showCancelDialog(booking['id']),
                                    child: const Text(
                                      'Annuler',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmée';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Inconnue';
    }
  }

  Future<void> _showCancelDialog(String bookingId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelBooking(bookingId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}