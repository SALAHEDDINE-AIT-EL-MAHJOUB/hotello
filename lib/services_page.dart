import 'package:flutter/material.dart';
import 'package:flutter_application_1/tour_guide_service_page.dart'; // Ensure this import is present
import 'package:url_launcher/url_launcher.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Gérer l'erreur si l'URL ne peut pas être lancée
      // Vous pouvez afficher un SnackBar ou une boîte de dialogue ici
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos Services', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildServiceCard(
            context,
            icon: Icons.video_library_outlined,
            title: 'Apprendre le Darija',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliquez ci-dessous pour accéder à une ressource utile pour apprendre le Darija (dialecte marocain) sur YouTube.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_fill_outlined),
                  label: const Text('Voir la vidéo YouTube'),
                  onPressed: () {
                    _launchURL('https://youtu.be/2O7Vcw_pw_o?si=_ysYFc3AhUorrDaU'); // Remplacez par le vrai lien YouTube
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildServiceCard(
            context,
            icon: Icons.directions_car_filled_outlined,
            title: 'Services de Transport',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pour vos déplacements, vous pouvez utiliser des applications comme :',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launchURL('https://indrive.com/fr-ma/'),
                  child: const Text(
                    '- inDrive (Appuyez pour visiter le site)',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple,
                        decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _launchURL('https://www.careem.com/'),
                  child: const Text(
                    '- Careem (Appuyez pour visiter le site)',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple,
                        decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vérifiez leur disponibilité et téléchargez leurs applications respectives depuis les stores.',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildServiceCard(
            context,
            icon: Icons.support_agent_outlined,
            title: 'Service de Guide Touristique',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explorez la ville avec un guide local expérimenté. Nous proposons divers services de guide pour enrichir votre séjour.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Découvrir Nos Services de Guide'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TourGuideServicePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600, // Légère variation de couleur
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Pour des informations touristiques générales sur le Maroc :',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: const Text('Infos Tourisme Maroc (Site Officiel)'),
                  onPressed: () {
                    _launchURL('https://www.visitmorocco.com/fr');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, {required IconData icon, required String title, required Widget content}) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 30.0, color: Colors.deepPurple),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15.0),
            content,
          ],
        ),
      ),
    );
  }
}