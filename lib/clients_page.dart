import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _bookingCounts = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final clientsSnapshot = await FirebaseDatabase.instance.ref('users').get();
      
      if (clientsSnapshot.exists) {
        final clientsData = clientsSnapshot.value as Map<dynamic, dynamic>;
        final loadedClients = <Map<String, dynamic>>[];

        clientsData.forEach((key, value) {
          // Conversion des données du client
          loadedClients.add({
            'id': key,
            'username': value['username'] ?? 'Sans nom',
            'email': value['email'] ?? 'Email non disponible',
            'isAdmin': value['isAdmin'] ?? false,
            'createdAt': value['createdAt'] != null 
                ? DateTime.fromMillisecondsSinceEpoch(value['createdAt'] as int) 
                : null,
            'profileImageBase64': value['profileImageBase64'],
            // Ajouter d'autres champs selon votre structure de données
          });
        });

        // Trier par date de création (plus récent en premier)
        loadedClients.sort((a, b) {
          final dateA = a['createdAt'];
          final dateB = b['createdAt'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        setState(() {
          _clients = loadedClients;
        });
      } else {
        setState(() {
          _clients = [];
        });
      }
      
      // Après avoir chargé tous les clients, compter leurs réservations
      await _loadBookingCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des clients: $e')),
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

  Future<void> _loadBookingCounts() async {
    try {
      final Map<String, int> counts = {};
      final bookingsSnapshot = await FirebaseDatabase.instance.ref('bookings').get();
      
      if (bookingsSnapshot.exists) {
        final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
        
        for (var client in _clients) {
          int count = 0;
          final String clientId = client['id'];
          
          bookingsData.forEach((key, value) {
            if (value['userId'] == clientId) {
              count++;
            }
          });
          
          counts[clientId] = count;
        }
      }
      
      setState(() {
        _bookingCounts = counts;
      });
    } catch (e) {
      print('Error loading booking counts: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    if (_searchQuery.isEmpty) {
      return _clients;
    }
    
    return _clients.where((client) {
      final username = client['username'].toString().toLowerCase();
      final email = client['email'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return username.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Clients'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barre de recherche
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un client...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Compteur de clients
                      Text(
                        '${_filteredClients.length} clients trouvés',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _clients.isEmpty
                      ? const Center(
                          child: Text('Aucun client enregistré pour le moment'),
                        )
                      : _filteredClients.isEmpty
                          ? const Center(
                              child: Text('Aucun résultat trouvé'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _filteredClients.length,
                              itemBuilder: (context, index) {
                                final client = _filteredClients[index];
                                return _buildClientCard(client);
                              },
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadClients,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
        tooltip: 'Actualiser la liste',
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final bool isAdmin = client['isAdmin'] == true;
    final DateTime? createdAt = client['createdAt'];
    final String formattedDate = createdAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(createdAt)
        : 'Date inconnue';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: isAdmin ? Colors.deepPurple[100] : Colors.grey[200],
              child: client['profileImageBase64'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.memory(
                        base64Decode(client['profileImageBase64']),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildAvatarContent(client, isAdmin);
                        },
                      ),
                    )
                  : _buildAvatarContent(client, isAdmin),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    client['username'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 16, color: Colors.deepPurple),
                        SizedBox(width: 4),
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(client['email'])),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text('Inscrit le $formattedDate'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Badge avec le nombre de réservations
                if (_bookingCounts.containsKey(client['id']) && _bookingCounts[client['id']]! > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_bookingCounts[client['id']]} réservation(s)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                Expanded(
                  child: Row(
                    children: [
                      // Bouton pour voir les réservations  
                      TextButton.icon(
                        onPressed: () {
                          _showClientBookings(client['id'], client['username']);
                        },
                        icon: const Icon(Icons.bookmark, size: 16),
                        label: const Text('Voir les réservations'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                      ),
                      
                      // Ne pas permettre de supprimer un administrateur
                      if (!isAdmin)
                        TextButton.icon(
                          onPressed: () {
                            _deleteClient(client['id'], client['username']);
                          },
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Supprimer'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(Map<String, dynamic> client, bool isAdmin) {
    if (client['username'].toString().isNotEmpty) {
      return Text(
        client['username'][0].toUpperCase(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isAdmin ? Colors.deepPurple : Colors.grey[600],
        ),
      );
    } else {
      return Icon(
        Icons.person,
        size: 30,
        color: isAdmin ? Colors.deepPurple : Colors.grey[600],
      );
    }
  }

  Future<void> _showClientBookings(String clientId, String clientName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final bookingsSnapshot = await FirebaseDatabase.instance
          .ref('bookings')
          .orderByChild('userId')
          .equalTo(clientId)
          .get();
      
      final List<Map<String, dynamic>> clientBookings = [];
      
      if (bookingsSnapshot.exists) {
        final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
        bookingsData.forEach((key, value) {
          clientBookings.add({
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
        
        // Trier les réservations par date (plus récentes d'abord)
        clientBookings.sort((a, b) {
          if (a['createdAt'] == null && b['createdAt'] == null) return 0;
          if (a['createdAt'] == null) return 1;
          if (b['createdAt'] == null) return -1;
          return b['createdAt'].compareTo(a['createdAt']);
        });
      }
      
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      // Regrouper les réservations par statut
      final confirmedBookings = clientBookings.where((b) => b['status'] == 'confirmed').toList();
      final pendingBookings = clientBookings.where((b) => b['status'] == 'pending').toList();
      final cancelledBookings = clientBookings.where((b) => b['status'] == 'cancelled').toList();
      
      // Afficher les réservations dans une boîte de dialogue améliorée avec séparations
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Réservations de ${clientName}'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: clientBookings.isEmpty
                ? const Center(
                    child: Text('Aucune réservation trouvée pour ce client'),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Afficher les statistiques de réservation
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatistic('Total', clientBookings.length, Colors.blue),
                              _buildStatistic('Confirmées', confirmedBookings.length, Colors.green),
                              _buildStatistic('En attente', pendingBookings.length, Colors.orange),
                              _buildStatistic('Annulées', cancelledBookings.length, Colors.red),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Section des réservations confirmées
                        if (confirmedBookings.isNotEmpty) ...[
                          _buildSectionHeader('Réservations confirmées', Colors.green),
                          ...confirmedBookings.map((b) => _buildBookingItem(b)),
                          const SizedBox(height: 16),
                        ],
                        
                        // Section des réservations en attente
                        if (pendingBookings.isNotEmpty) ...[
                          _buildSectionHeader('Réservations en attente', Colors.orange),
                          ...pendingBookings.map((b) => _buildBookingItem(b)),
                          const SizedBox(height: 16),
                        ],
                        
                        // Section des réservations annulées
                        if (cancelledBookings.isNotEmpty) ...[
                          _buildSectionHeader('Réservations annulées', Colors.red),
                          ...cancelledBookings.map((b) => _buildBookingItem(b)),
                        ],
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des réservations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: color,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistic(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          booking['hotelName'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(booking['checkIn'])} - '
                  '${DateFormat('dd/MM/yyyy').format(booking['checkOut'])}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${booking['totalPrice'].toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        // Le statut est maintenant implicite par la section
      ),
    );
  }

  Future<void> _deleteClient(String clientId, String clientName) async {
    // Confirmation avant suppression
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation de suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le client "$clientName" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Vérifier si l'utilisateur a des réservations
      final bookingsSnapshot = await FirebaseDatabase.instance
          .ref('bookings')
          .orderByChild('userId')
          .equalTo(clientId)
          .get();

      // 2. Option de supprimer aussi les réservations
      if (bookingsSnapshot.exists) {
        final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
        bool deleteBookings = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Réservations détectées'),
            content: Text('Ce client possède ${bookingsData.length} réservation(s).\n\nVoulez-vous également supprimer ses réservations?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Conserver les réservations'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Supprimer tout'),
              ),
            ],
          ),
        ) ?? false;

        // Supprimer les réservations si confirmé
        if (deleteBookings) {
          for (var key in bookingsData.keys) {
            await FirebaseDatabase.instance.ref('bookings').child(key).remove();
          }
        }
      }

      // 3. Supprimer le client
      await FirebaseDatabase.instance.ref('users').child(clientId).remove();
      
      // 4. Actualiser la liste des clients
      await _loadClients();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression du client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}