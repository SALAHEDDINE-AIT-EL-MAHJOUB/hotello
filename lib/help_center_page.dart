import 'package:flutter/material.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre d\'aide', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comment pouvons-nous vous aider ?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildFaqSection(),
            
            const SizedBox(height: 32),
            _buildContactSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Questions fréquentes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildExpandableQuestion(
          'Comment réserver un hôtel ?',
          'Pour réserver un hôtel, parcourez les options disponibles dans l\'onglet Explore, '
          'sélectionnez l\'hôtel qui vous intéresse, puis cliquez sur le bouton "Réserver". '
          'Choisissez ensuite vos dates de séjour et confirmez votre réservation.',
        ),
        _buildExpandableQuestion(
          'Comment annuler une réservation ?',
          'Pour annuler une réservation, accédez à l\'onglet "Mes Réservations", '
          'trouvez la réservation que vous souhaitez annuler et appuyez sur le bouton '
          '"Annuler". Veuillez noter que certaines réservations peuvent être soumises '
          'à des frais d\'annulation selon les politiques de l\'hôtel.',
        ),
        _buildExpandableQuestion(
          'Comment mettre à jour mes informations de profil ?',
          'Pour mettre à jour vos informations de profil, accédez à l\'onglet Profil, '
          'puis appuyez sur "Modifier le profil". Vous pourrez alors modifier votre '
          'nom d\'utilisateur, votre photo de profil et d\'autres informations personnelles.',
        ),
        _buildExpandableQuestion(
          'Comment puis-je contacter le service client ?',
          'Vous pouvez contacter notre service client par email à support@hotello.com '
          'ou par téléphone au +123 456 789. Notre équipe est disponible 7j/7 de 8h à 20h.',
        ),
      ],
    );
  }

  Widget _buildExpandableQuestion(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Besoin d\'aide supplémentaire ?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  leading: Icon(Icons.email, color: Colors.deepPurple),
                  title: Text('Email'),
                  subtitle: Text('support@hotello.com'),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.phone, color: Colors.deepPurple),
                  title: Text('Téléphone'),
                  subtitle: Text('+123 456 789'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.deepPurple),
                  title: const Text('Chat en direct'),
                  subtitle: const Text('Discutez avec un conseiller'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Ouvrir le chat en direct
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat en direct bientôt disponible')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}