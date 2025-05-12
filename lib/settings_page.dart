import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/settings_page.dart';
import 'package:flutter_application_1/profile_page.dart';  // Ajoutez cet import

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'Français';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
      _selectedCurrency = prefs.getString('currency') ?? 'USD';
      _selectedLanguage = prefs.getString('language') ?? 'Français';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('darkModeEnabled', _darkModeEnabled);
    await prefs.setString('currency', _selectedCurrency);
    await prefs.setString('language', _selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Préférences'),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Recevoir des notifications de réservation et de promotions'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.notifications_active, color: Colors.deepPurple),
          ),
          SwitchListTile(
            title: const Text('Mode sombre'),
            subtitle: const Text('Changer l\'apparence de l\'application'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
              _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cette fonctionnalité sera bientôt disponible')),
              );
            },
            secondary: const Icon(Icons.dark_mode, color: Colors.deepPurple),
          ),
          _buildSectionHeader('Affichage'),
          ListTile(
            title: const Text('Devise'),
            subtitle: Text(_selectedCurrency),
            leading: const Icon(Icons.currency_exchange, color: Colors.deepPurple),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showCurrencyPicker(),
          ),
          ListTile(
            title: const Text('Langue'),
            subtitle: Text(_selectedLanguage),
            leading: const Icon(Icons.language, color: Colors.deepPurple),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showLanguagePicker(),
          ),
          _buildSectionHeader('Confidentialité & Sécurité'),
          ListTile(
            title: const Text('Données personnelles'),
            subtitle: const Text('Gérer vos informations personnelles'),
            leading: const Icon(Icons.security, color: Colors.deepPurple),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          ListTile(
            title: const Text('Effacer l\'historique de recherche'),
            leading: const Icon(Icons.history, color: Colors.deepPurple),
            onTap: _clearSearchHistory,
          ),
          _buildSectionHeader('À propos'),
          ListTile(
            title: const Text('Version de l\'application'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info_outline, color: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _showCurrencyPicker() async {
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'MAD', 'CAD'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une devise'),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) => RadioListTile<String>(
              title: Text(currencies[index]),
              value: currencies[index],
              groupValue: _selectedCurrency,
              onChanged: (value) {
                Navigator.of(context).pop();
                setState(() {
                  _selectedCurrency = value!;
                });
                _saveSettings();
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final languages = ['Français', 'English', 'Español', 'Deutsch', 'العربية'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une langue'),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) => RadioListTile<String>(
              title: Text(languages[index]),
              value: languages[index],
              groupValue: _selectedLanguage,
              onChanged: (value) {
                Navigator.of(context).pop();
                setState(() {
                  _selectedLanguage = value!;
                });
                _saveSettings();
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _clearSearchHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear history logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historique de recherche effacé')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}