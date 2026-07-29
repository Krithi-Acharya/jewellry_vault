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
const kCard = Color(0xFFFFFFFF);

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
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return; // user cancelled

    setState(() => isUploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();

      const cloudName = 'umv4zdwz';
      const uploadPreset = 'profile_photos';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: picked.name));

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  // Clears the photo locally; actual removal happens on Save.
  Future<void> removePhoto() async {
    setState(() => photoUrl = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo removed — tap Save Changes to confirm')),
      );
    }
  }

  // Persists whatever photoUrl currently is (new photo, or null if removed)
  // plus the name, then reloads so the dashboard picks up the change.
  //
  // NOTE: passing an empty string instead of null when clearing the photo
  // is required — Firebase's native SDKs treat updatePhotoURL(null) as
  // "leave the field unchanged," not "clear it," so null alone silently
  // fails to remove the photo on the account.
  Future<void> saveChanges() async {
    await user?.updateDisplayName(nameController.text);
    await user?.updatePhotoURL(photoUrl ?? '');
    await user?.reload();
    setState(() => isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: kText, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: kText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with an edit button on top
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: kBorder,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, size: 52, color: Colors.white)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: isUploadingPhoto ? null : pickAndUploadPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kEmerald,
                                shape: BoxShape.circle,
                                border: Border.all(color: kCard, width: 2),
                              ),
                              child: isUploadingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Remove Photo — only shows up if there's actually a photo set
                    if (photoUrl != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: isUploadingPhoto ? null : removePhoto,
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text(
                          'Remove Photo',
                          style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Name — either plain text or an editable field
                    isEditing
                        ? TextField(
                            controller: nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kText),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              filled: true,
                              fillColor: kBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kEmerald, width: 1.5),
                              ),
                            ),
                          )
                        : Text(
                            nameController.text.isEmpty ? 'No name set' : nameController.text,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText),
                          ),

                    const SizedBox(height: 6),

                    // Email — read only, since it's tied to the login itself
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mail_outline, size: 14, color: kGrey),
                        const SizedBox(width: 6),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: kGrey, fontSize: 14),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Divider(color: kBorder, height: 1),
                    const SizedBox(height: 28),

                    // Edit / Save toggle button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isEditing ? saveChanges : () => setState(() => isEditing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEditing ? Icons.check : Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(isEditing ? 'Save Changes' : 'Edit Profile'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout, size: 18),
                            SizedBox(width: 8),
                            Text('Log Out'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}