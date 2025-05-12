import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos de nous', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hotel_rounded,
                  size: 64,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Hotello',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Notre mission',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hotello a été créé avec une mission simple : rendre la réservation d\'hôtels plus simple, plus accessible et plus agréable pour tous. '
              'Notre application vous permet de découvrir, comparer et réserver des hôtels partout dans le monde, en quelques clics seulement.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notre équipe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nous sommes une équipe passionnée de développeurs et de professionnels du tourisme, '
              'déterminés à créer la meilleure expérience de voyage possible. '
              'Notre siège social est basé à Casablanca, mais notre équipe est répartie à travers le monde.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contactez-nous',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Email: contact@hotello.com\n'
              'Téléphone: +123 456 789\n'
              'Adresse: 123 Avenue Mohammed V, Casablanca, Maroc',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'Suivez-nous',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(Icons.facebook, Colors.blue),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.verified, Colors.lightBlueAccent),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.camera_alt, Colors.pink),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.play_arrow, Colors.red),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© ${DateTime.now().year} Hotello. Tous droits réservés.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}