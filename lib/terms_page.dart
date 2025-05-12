import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conditions générales', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conditions générales d\'utilisation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Dernière mise à jour : ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Bienvenue sur Hotello ! Ces conditions générales d\'utilisation régissent '
              'votre utilisation de l\'application mobile Hotello et de tous les services associés. '
              'En utilisant notre application, vous acceptez d\'être lié par ces conditions. '
              'Veuillez les lire attentivement.',
            ),
            _buildSection(
              'Utilisation du service',
              'Hotello vous permet de rechercher, découvrir et réserver des hôtels. '
              'Vous vous engagez à utiliser ce service uniquement à des fins légales et '
              'conformément aux présentes conditions. Vous êtes responsable de toutes les '
              'activités qui se produisent sous votre compte.',
            ),
            _buildSection(
              'Comptes utilisateurs',
              'Pour utiliser certaines fonctionnalités de notre application, vous devrez '
              'créer un compte. Vous êtes responsable de maintenir la confidentialité de '
              'votre mot de passe et de votre compte, et acceptez d\'être responsable de '
              'toutes les activités qui s\'y déroulent. Vous devez nous informer immédiatement '
              'de toute utilisation non autorisée de votre compte.',
            ),
            _buildSection(
              'Réservations et paiements',
              'Lorsque vous effectuez une réservation via Hotello, vous acceptez de payer '
              'tous les frais associés à cette réservation. Toutes les réservations sont '
              'soumises aux politiques d\'annulation spécifiques des hôtels. Nous ne sommes '
              'pas responsables des erreurs de tarification affichées sur l\'application.',
            ),
            _buildSection(
              'Annulations et remboursements',
              'Les politiques d\'annulation varient selon les hôtels. Veuillez consulter '
              'les conditions spécifiques de chaque hôtel avant de réserver. Les remboursements, '
              'le cas échéant, seront traités conformément aux politiques de l\'hôtel concerné.',
            ),
            _buildSection(
              'Propriété intellectuelle',
              'L\'application Hotello et tout son contenu, fonctionnalités et fonctionnalités '
              'sont la propriété exclusive de Hotello et sont protégés par les lois internationales '
              'sur les droits d\'auteur, les marques déposées, les brevets, les secrets commerciaux '
              'et autres droits de propriété intellectuelle.',
            ),
            _buildSection(
              'Limitation de responsabilité',
              'Dans toute la mesure permise par la loi applicable, Hotello ne sera pas responsable '
              'des dommages indirects, accessoires, spéciaux, consécutifs ou punitifs, ou de toute '
              'perte de profits ou de revenus.',
            ),
            _buildSection(
              'Modifications des conditions',
              'Nous nous réservons le droit de modifier ces conditions à tout moment. Les modifications '
              'prendront effet dès leur publication. Il est de votre responsabilité de consulter '
              'régulièrement ces conditions pour rester informé des mises à jour.',
            ),
            _buildSection(
              'Contact',
              'Si vous avez des questions concernant ces conditions, veuillez nous contacter à '
              'legal@hotello.com.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}