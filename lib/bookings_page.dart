import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'leave_review_page.dart'; // Ajoutez cette importation

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
        title: const Text('Mes Réservations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)), // Style
        backgroundColor: Colors.deepPurple,
        elevation: 2, // Style
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white), // Icône différente
            onPressed: _loadBookings,
            tooltip: 'Rafraîchir', // Tooltip
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple.shade300)) // Style
          : _bookings.isEmpty
              ? Center(
                  child: Padding( // Amélioration de l'état vide
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey.shade400), // Icône
                        const SizedBox(height: 20),
                        const Text(
                          'Aucune réservation pour le moment', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black54), // Style
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vos réservations apparaîtront ici.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600), // Style
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _bookings.length,
                  padding: const EdgeInsets.all(12), // Ajusté
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final isUpcoming = booking['checkIn'].isAfter(DateTime.now());
                    final isPast = booking['checkOut'].isBefore(DateTime.now().subtract(const Duration(days: 1)));

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), // Ajusté
                      elevation: 3, // Style
                      shadowColor: _getStatusColor(booking['status']).withOpacity(0.2), // Style
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Style
                        side: BorderSide(color: _getStatusColor(booking['status']).withOpacity(0.5), width: 0.5) // Bordure subtile
                      ),
                      child: Padding( // Padding à l'intérieur de la Card
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['hotelName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19, // Style
                                color: Colors.deepPurple.shade700, // Style
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade700), // Style
                                const SizedBox(width: 10),
                                Expanded( // Pour gérer les textes longs
                                  child: Text(
                                    '${DateFormat('EEE, dd MMM yyyy', 'fr_FR').format(booking['checkIn'])} - ' // Format de date plus lisible
                                    '${DateFormat('EEE, dd MMM yyyy', 'fr_FR').format(booking['checkOut'])}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800), // Style
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.monetization_on_outlined, size: 18, color: Colors.grey.shade700), // Style
                                const SizedBox(width: 10),
                                Text(
                                  '${booking['totalPrice'].toStringAsFixed(2)} €', // Supposant que c'est en euros
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade800), // Style
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip( // Utilisation de Chip pour le statut
                                  label: Text(
                                    _getStatusText(booking['status']),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), // Style
                                  ),
                                  backgroundColor: _getStatusColor(booking['status']),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Style
                                ),
                                if (isUpcoming && booking['status'] == 'confirmed')
                                  TextButton.icon( // Bouton avec icône
                                    onPressed: () => _showCancelDialog(booking['id']),
                                    icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400), // Style
                                    label: Text(
                                      'Annuler',
                                      style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w500), // Style
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10) // Style
                                    ),
                                  ),
                                if (isPast && booking['status'] == 'confirmed') // Exemple: Laisser un avis
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LeaveReviewPage(
                                            bookingId: booking['id'],
                                            hotelName: booking['hotelName'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.rate_review_outlined, size: 18, color: Colors.deepPurple.shade400),
                                    label: Text('Laisser un avis', style: TextStyle(color: Colors.deepPurple.shade600)),
                                     style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10)
                                    ),
                                  )
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Style
        title: const Text('Annuler la réservation ?', style: TextStyle(fontWeight: FontWeight.w600)), // Style
        content: const Text('Cette action est irréversible.'), // Style
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Style
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Non', style: TextStyle(color: Colors.grey)), // Style
          ),
          ElevatedButton( // Bouton plus visible pour l'action principale
            onPressed: () {
              Navigator.of(context).pop();
              _cancelBooking(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400, // Style
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) // Style
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}