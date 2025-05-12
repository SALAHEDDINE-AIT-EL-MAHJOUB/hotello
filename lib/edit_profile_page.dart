import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isPasswordExpanded = false;
  File? _profileImage;
  String? _errorMessage;
  String? _successMessage;
  String? _profileImageUrl;
  String? _profileImageBase64;
  
  // Firebase references
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load basic user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final isGuestMode = prefs.getBool('isGuestMode') ?? false;
      
      _usernameController.text = prefs.getString('username') ?? '';
      
      if (!isGuestMode && _currentUser != null) {
        _emailController.text = prefs.getString('email') ?? _currentUser!.email ?? '';
        
        // Charger l'image depuis Realtime Database
        final userSnapshot = await _database.child('users/${_currentUser!.uid}').get();
        
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>?;
          if (userData != null && userData.containsKey('profileImageBase64')) {
            setState(() {
              _profileImageBase64 = userData['profileImageBase64'] as String?;
            });
          }
        }
      } else {
        // In guest mode, set email field to empty or disabled
        _emailController.text = 'Guest Mode (No Email)';
      }
    } catch (e) {
      print('Error loading user data: $e');
      _errorMessage = 'Failed to load user data';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show a bottom sheet with options
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 500,
                      maxHeight: 500,
                      imageQuality: 85,
                    );
                    
                    if (pickedFile != null) {
                      setState(() {
                        _profileImage = File(pickedFile.path);
                      });
                      _showImagePreview(); // Show preview of selected image
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      maxWidth: 500,
                      maxHeight: 500,
                      imageQuality: 85,
                    );
                    
                    if (pickedFile != null) {
                      setState(() {
                        _profileImage = File(pickedFile.path);
                      });
                      _showImagePreview(); // Show preview of selected image
                    }
                  },
                ),
                if (_profileImageUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Remove Current Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _profileImage = null;
                        _profileImageUrl = null;
                      });
                    },
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null || _currentUser == null) return null;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      print('Preparing to encode image to base64');
      
      // Lire l'image en tant que bytes
      final bytes = await _profileImage!.readAsBytes();
      
      // Redimensionner l'image pour réduire sa taille
      final Uint8List resizedBytes = await _resizeImage(bytes);
      
      // Convertir en base64
      final String base64Image = base64Encode(resizedBytes);
      print('Image encoded to base64: ${base64Image.substring(0, 50)}... (${base64Image.length} chars)');
      
      // Générer un ID unique pour l'image
      final String imageId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      
      // Stocker directement dans Realtime Database
      final userRef = _database.child('users/${_currentUser!.uid}');
      
      // Stocker l'image et les métadonnées
      await userRef.update({
        'profileImageBase64': base64Image,
        'profileImageId': imageId,
        'lastUpdated': ServerValue.timestamp,
      });
      
      print('Image saved directly to Realtime Database');
      return imageId;  // Retourner l'ID comme référence
      
    } catch (e) {
      print('Error saving image to database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
      return null;
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // Ajouter cette méthode pour redimensionner l'image
  Future<Uint8List> _resizeImage(Uint8List imageBytes) async {
    // Utilisez un package comme flutter_image_compress ou image pour redimensionner l'image
    // Exemple simplifié (vous devrez implémenter la logique de redimensionnement réelle)
    
    // Pour l'instant, on retourne simplement les bytes originaux
    // Dans une vraie implémentation, vous devriez redimensionner l'image à une taille plus petite
    return imageBytes;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Check if we're in guest mode
      final prefs = await SharedPreferences.getInstance();
      final isGuestMode = prefs.getBool('isGuestMode') ?? false;
      
      if (isGuestMode) {
        // Just call the guest mode save method
        await _saveUserData();
      } else {
        // Original authentication-based code
        // 1. Save username to SharedPreferences
        await prefs.setString('username', _usernameController.text.trim());

        // 2. Upload profile image if changed
        String? downloadUrl;
        if (_profileImage != null) {
          print('About to upload profile image to Database');
          downloadUrl = await _uploadProfileImage(); // Cette méthode retourne maintenant un ID
          
          if (downloadUrl != null) {
            print('Image saved to database with ID: $downloadUrl');
          }
        } else {
          print('No new profile image to upload, using existing: $_profileImageUrl');
        }

        // 3. Save to Firebase Realtime Database
        if (_currentUser != null) {
          final userRef = _database.child('users/${_currentUser!.uid}');
          print('Database path: users/${_currentUser!.uid}');
          
          // Create a temporary map that we'll add the profileImageUrl to if needed
          final Map<String, dynamic> userData = {
            'username': _usernameController.text.trim(),
            'email': _emailController.text,
            'lastUpdated': ServerValue.timestamp,
          };
          
          // IMPORTANT: Fix for profileImageUrl handling
          if (downloadUrl != null) {
            userData['profileImageUrl'] = downloadUrl;
            print('Adding new image URL to userData: $downloadUrl');
          } else if (_profileImageUrl != null) {
            userData['profileImageUrl'] = _profileImageUrl;
            print('Keeping existing image URL in userData: $_profileImageUrl');
          } else {
            // Explicitly set to null if the user removed their profile image
            userData['profileImageUrl'] = null;
            print('Setting profileImageUrl to null in userData');
          }
          
          print('Complete userData to save: $userData');
          
          // Use update() instead of set() to only change specified fields
          try {
            await userRef.update(userData);
            print('Database update completed successfully');
            
            // Verify the data was updated correctly
            final updatedSnapshot = await userRef.get();
            if (updatedSnapshot.exists) {
              final updatedData = updatedSnapshot.value as Map<dynamic, dynamic>?;
              print('Profile updated successfully. Image URL in DB: ${updatedData?['profileImageUrl']}');
              
              // Force refresh the UI with data from database
              setState(() {
                _profileImageUrl = updatedData?['profileImageUrl'] as String?;
              });
            }
          } catch (dbError) {
            print('Error updating database: $dbError');
            rethrow;
          }
        } else {
          print('No current user found, cannot save to database');
        }

        // 4. Update password if provided (remaining code unchanged)
        if (_isPasswordExpanded && 
            _currentPasswordController.text.isNotEmpty &&
            _newPasswordController.text.isNotEmpty) {
          
          // Get current user
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Reauthenticate first
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: _currentPasswordController.text,
            );
            
            await user.reauthenticateWithCredential(credential);
            await user.updatePassword(_newPasswordController.text);
          }
        }
      }
      
      if (!isGuestMode) {
        setState(() {
          _successMessage = 'Profile updated successfully';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          _errorMessage = 'Current password is incorrect';
        } else {
          _errorMessage = 'Authentication error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      print('Error in _saveProfile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    // In guest mode, save only to local storage or show a message
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved locally (Guest Mode)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Return true as a result to indicate changes were made
            Navigator.of(context).pop(true);  
          },
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo at the top
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                    ),
                  ),
                  
                  // Profile Image
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _getProfileImage(),
                          child: _profileImage == null && _profileImageUrl == null
                            ? Text(
                                _usernameController.text.isNotEmpty
                                  ? _usernameController.text[0].toUpperCase()
                                  : 'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              )
                            : null,
                        ),
                      ),
                      if (_isUploadingImage)
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple.withOpacity(0.7)
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to change profile photo',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Success/Error Messages
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Username Field
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Email (cannot be changed)',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Change Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPasswordExpanded = !_isPasswordExpanded;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Change Password',
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  _isPasswordExpanded 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                ),
                              ],
                            ),
                          ),
                          if (_isPasswordExpanded) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (_newPasswordController.text.isNotEmpty) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your current password';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (_currentPasswordController.text.isNotEmpty) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a new password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (_newPasswordController.text.isNotEmpty) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return 'Passwords do not match';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        if (_currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No user logged in')),
                          );
                          return;
                        }
                        
                        final userRef = _database.child('users/${_currentUser!.uid}');
                        final snapshot = await userRef.get();
                        
                        if (snapshot.exists) {
                          final userData = snapshot.value as Map<dynamic, dynamic>?;
                          String message = 'Current DB data: \n';
                          userData?.forEach((key, value) {
                            message += '$key: $value\n';
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message), duration: const Duration(seconds: 10)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No user data found in database')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error checking database: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: const Text('Debug: Check Database'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  // Helper method to get the profile image
  ImageProvider? _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (_profileImageBase64 != null) {
      // Convertir base64 en image
      return MemoryImage(base64Decode(_profileImageBase64!));
    }
    return null;
  }

  void _showImagePreview() {
    if (_profileImage == null) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _profileImage!,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Use This Photo', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Choose Again'),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}