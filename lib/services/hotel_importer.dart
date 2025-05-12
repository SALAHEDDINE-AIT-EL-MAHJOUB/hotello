import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class HotelImporter {
  static Future<void> importHotelsFromCsv() async {
    final String csvAssetPath = 'assets/marrakech_hotels.csv'; // Ensure this is in pubspec.yaml assets
    int hotelsAddedCount = 0;
    int hotelsSkippedCount = 0;

    try {
      final String csvString = await rootBundle.loadString(csvAssetPath);
      final List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n').convert(csvString);

      if (csvTable.length < 2) { // Needs header + at least one data row
        print('HotelImporter: CSV file is empty or has no data rows.');
        return;
      }

      final List<dynamic> headerRow = csvTable[0];
      // Dynamically find column indices
      final int nameIndex = headerRow.indexOf('Nom_Hotel');
      final int cityIndex = headerRow.indexOf('Ville'); // Maps to 'location' in Firebase
      final int priceIndex = headerRow.indexOf('Prix');
      final int ratingIndex = headerRow.indexOf('Note');
      final int phoneIndex = headerRow.indexOf('Telephone');
      final int descriptionIndex = headerRow.indexOf('Description');
      final int imageUrlIndex = headerRow.indexOf('Image_URL');
      final int equipementsIndex = headerRow.indexOf('Equipements');
      // Add other indices as needed

      // Basic validation of critical column indices
      if (nameIndex == -1 || cityIndex == -1) {
          print('HotelImporter: Critical columns (Nom_Hotel, Ville) not found in CSV header.');
          return;
      }

      final dbRef = FirebaseDatabase.instance.ref('hotels');

      for (int i = 1; i < csvTable.length; i++) { // Start from 1 to skip header
        final List<dynamic> row = csvTable[i];
        
        // Ensure row has enough columns to prevent RangeError
        if (row.length <= nameIndex || row.length <= cityIndex ) continue;


        final String hotelName = row[nameIndex].toString();
        final String hotelCity = row[cityIndex].toString(); // This is 'location' in Firebase

        // Check for existing hotel in Firebase
        final query = dbRef.orderByChild('name').equalTo(hotelName);
        final DataSnapshot snapshot = await query.once().then((event) => event.snapshot);

        bool hotelExists = false;
        if (snapshot.exists && snapshot.value != null) {
          final Map<dynamic, dynamic> hotels = snapshot.value as Map<dynamic, dynamic>;
          for (var hotelKey in hotels.keys) {
            final hotelData = hotels[hotelKey] as Map<dynamic, dynamic>;
            if (hotelData['location'] == hotelCity) {
              hotelExists = true;
              break;
            }
          }
        }

        if (hotelExists) {
          print('HotelImporter: Hotel "$hotelName" in "$hotelCity" already exists. Skipping.');
          hotelsSkippedCount++;
        } else {
          // Prepare data for Firebase
          List<String> features = [];
          if (equipementsIndex != -1 && row.length > equipementsIndex && row[equipementsIndex] != null && row[equipementsIndex].toString().isNotEmpty && row[equipementsIndex].toString() != 'N/A') {
            features = row[equipementsIndex].toString().split(',').map((e) => e.trim()).toList();
          }

          final newHotelData = {
            'name': hotelName,
            'location': hotelCity,
            'price': priceIndex != -1 && row.length > priceIndex ? row[priceIndex].toString() : 'N/A',
            'rating': ratingIndex != -1 && row.length > ratingIndex ? row[ratingIndex].toString() : 'N/A',
            'phone': phoneIndex != -1 && row.length > phoneIndex ? row[phoneIndex].toString() : 'N/A',
            'description': descriptionIndex != -1 && row.length > descriptionIndex ? row[descriptionIndex].toString() : 'N/A',
            'imageUrl': imageUrlIndex != -1 && row.length > imageUrlIndex ? row[imageUrlIndex].toString() : 'N/A', // Storing URL
            // 'imageData': 'base64_image_data_if_downloaded_and_converted', // If you handle image conversion
            'features': features,
            'createdAt': ServerValue.timestamp,
          };

          await dbRef.push().set(newHotelData);
          print('HotelImporter: Added hotel "$hotelName" in "$hotelCity" to Firebase.');
          hotelsAddedCount++;
        }
      }
      print('HotelImporter: Import process finished. Added: $hotelsAddedCount, Skipped: $hotelsSkippedCount');

    } catch (e) {
      print('HotelImporter: Error during CSV import: $e');
      // Optionally, rethrow or handle more gracefully
      throw Exception('Failed to import hotels from CSV: $e');
    }
  }
}

class HotelImportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Optionally, show a loading indicator
        await HotelImporter.importHotelsFromCsv();
        // Optionally, show a success message or hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotel import process initiated. Check console for details.')),
        );
      },
      child: const Text('Import Hotels from CSV'),
    );
  }
}