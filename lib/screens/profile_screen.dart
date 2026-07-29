import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const kBg = Color(0xFFFCF9F4);
const kEmerald = Color(0xFF1B4332);
const kBorder = Color(0xFFE5DDD0);
const kText = Color(0xFF1A1815);
const kGrey = Color(0xFF6B6258);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  bool isEditing = false;
  bool isUploadingPhoto = false;

  late TextEditingController nameController;
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: user?.displayName ?? '');
    photoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // Opens the gallery, uploads the picked photo to Cloudinary, and saves
  // the resulting URL so it can be shown + persisted to the Firebase profile.
  Future<void> pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return; // user cancelled

    setState(() => isUploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();

      const cloudName = 'umv4zdwz';
      const uploadPreset = 'profile_photos';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: picked.name),
        );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      setState(() {
        photoUrl = data['secure_url'];
        isUploadingPhoto = false;
      });
    } catch (e) {
      setState(() => isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  // Clears the photo, both locally and on the Firebase profile.
  Future<void> removePhoto() async {
    setState(() => photoUrl = null);
    await user?.updatePhotoURL(null);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo removed')));
    }
  }

  // Sends the updated name + photo to Firebase so it's actually saved.
  Future<void> saveChanges() async {
    await user?.updateDisplayName(nameController.text);
    await user?.updatePhotoURL(photoUrl);
    setState(() => isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: kText)),
        iconTheme: const IconThemeData(color: kText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar with an edit button on top
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: kBorder,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: isUploadingPhoto ? null : pickAndUploadPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: kEmerald,
                        shape: BoxShape.circle,
                      ),
                      child: isUploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),

            // Remove Photo — only shows up if there's actually a photo set
            if (photoUrl != null)
              TextButton(
                onPressed: isUploadingPhoto ? null : removePhoto,
                child: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 24),

            // Name — either plain text or an editable field
            isEditing
                ? TextField(
                    controller: nameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(hintText: 'Your name'),
                  )
                : Text(
                    nameController.text.isEmpty
                        ? 'No name set'
                        : nameController.text,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
            const SizedBox(height: 4),

            // Email — read only, since it's tied to the login itself
            Text(user?.email ?? '', style: const TextStyle(color: kGrey)),
            const SizedBox(height: 32),

            // Edit / Save toggle button
            ElevatedButton(
              onPressed: isEditing
                  ? saveChanges
                  : () => setState(() => isEditing = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEditing ? 'Save Changes' : 'Edit Profile'),
            ),
            const SizedBox(height: 16),

            // Logout
            OutlinedButton(
              onPressed: logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
