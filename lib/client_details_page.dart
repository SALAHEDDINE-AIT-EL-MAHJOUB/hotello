import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ClientDetailsPage extends StatefulWidget {
  final Map<String, dynamic> client;
  
  const ClientDetailsPage({super.key, required this.client});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  late TabController _tabController;
  
  // Listes filtrées des réservations par statut
  List<Map<String, dynamic>> get _confirmedBookings => 
      _bookings.where((booking) => booking['status'] == 'confirmed').toList();
  
  List<Map<String, dynamic>> get _pendingBookings => 
      _bookings.where((booking) => booking['status'] == 'pending').toList();
  
  List<Map<String, dynamic>> get _cancelledBookings => 
      _bookings.where((booking) => booking['status'] == 'cancelled').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookings();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    
    try {
      final bookingsSnapshot = await FirebaseDatabase.instance
          .ref('bookings')
          .orderByChild('userId')
          .equalTo(widget.client['id'])
          .get();
      
      final List<Map<String, dynamic>> loadedBookings = [];
      
      if (bookingsSnapshot.exists) {
        final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
        bookingsData.forEach((key, value) {
          loadedBookings.add({
            'id': key,
            'hotelName': value['hotelName'] ?? 'Hôtel inconnu',
            'checkIn': DateTime.fromMillisecondsSinceEpoch(value['checkIn']),
            'checkOut': DateTime.fromMillisecondsSinceEpoch(value['checkOut']),
            'totalPrice': value['totalPrice'] ?? 0.0,
            'status': value['status'] ?? 'pending',
            'createdAt': value['createdAt'] != null 
                ? DateTime.fromMillisecondsSinceEpoch(value['createdAt']) 
                : null,
          });
        });
        
        // Trier par date de réservation
        loadedBookings.sort((a, b) => b['checkIn'].compareTo(a['checkIn']));
      }
      
      setState(() {
        _bookings = loadedBookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des réservations: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Client: ${widget.client['username']}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Toutes (${_bookings.length})'),
            Tab(text: 'Confirmées (${_confirmedBookings.length})'),
            Tab(text: 'En attente (${_pendingBookings.length})'),
            Tab(text: 'Annulées (${_cancelledBookings.length})'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(_bookings),
              _buildBookingsList(_confirmedBookings),
              _buildBookingsList(_pendingBookings),
              _buildBookingsList(_cancelledBookings),
            ],
          ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return const Center(
        child: Text('Aucune réservation dans cette catégorie'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
    );
  }
  
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final checkInDate = DateFormat('dd/MM/yyyy').format(booking['checkIn']);
    final checkOutDate = DateFormat('dd/MM/yyyy').format(booking['checkOut']);
    
    // Calculer la durée du séjour
    final nights = booking['checkOut'].difference(booking['checkIn']).inDays;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hotel, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking['hotelName'],
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                _getStatusChip(booking['status']),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arrivée',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkInDate,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.nightlight_round, size: 14),
                      const SizedBox(width: 4),
                      Text('$nights nuits'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Départ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkOutDate,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${booking['totalPrice'].toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('Détails'),
                  onPressed: () {
                    // Ouvrir les détails de la réservation (à implémenter)
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        label = 'Confirmée';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'En attente';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulée';
        break;
      default:
        color = Colors.grey;
        label = 'Inconnue';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}