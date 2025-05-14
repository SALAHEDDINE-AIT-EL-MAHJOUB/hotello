import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_application_1/add_edit_tour_service_page.dart'; // Cet import devrait fournir TourService

class AdminTourServicesPage extends StatefulWidget {
  const AdminTourServicesPage({super.key});

  @override
  State<AdminTourServicesPage> createState() => _AdminTourServicesPageState();
}

class _AdminTourServicesPageState extends State<AdminTourServicesPage> {
  List<TourService> _tourServices = []; // TourService devrait maintenant être correctement résolu
  bool _isLoading = true;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('tourServices'); // Ligne 14

  @override
  void initState() {
    super.initState();
    _loadTourServices();
  }

  Future<void> _loadTourServices() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _dbRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final List<TourService> loadedServices = [];
        data.forEach((key, value) {
          loadedServices.add(TourService.fromJson(value, key));
        });
        setState(() {
          _tourServices = loadedServices;
        });
      } else {
        setState(() {
          _tourServices = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tour services: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateAndRefresh(Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _loadTourServices();
    }
  }

  Future<void> _deleteService(String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this tour service?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbRef.child(serviceId).remove();
        _loadTourServices(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete service: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tour Services'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tourServices.isEmpty
              ? const Center(child: Text('No tour services found. Add some!'))
              : ListView.builder(
                  itemCount: _tourServices.length,
                  itemBuilder: (context, index) {
                    final service = _tourServices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: service.imageUrl.isNotEmpty
                            ? Image.network(service.imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image))
                            : const Icon(Icons.image_not_supported, size: 50),
                        title: Text(service.title),
                        subtitle: Text(service.subtitle),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _navigateAndRefresh(AddEditTourServicePage(tourService: service)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteService(service.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const AddEditTourServicePage()),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        tooltip: 'Add Tour Service',
      ),
    );
  }
}