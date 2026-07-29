import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/auth_service.dart';

final Map<String, dynamic> _localProfileStore = {};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  bool isEditing = false;
  bool isUploadingPhoto = false;
  bool isLoadingPrefs = true;

  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController mottoController;
  String? photoUrl;

  // ── Style Preferences ──
  String selectedUndertone = 'Warm Gold';
  String selectedMetal = 'Yellow Gold';
  String selectedRingSize = 'US 7';
  String selectedApparelSize = 'M';
  String selectedCurrency = 'USD (\$)';
  final Set<String> selectedAesthetics = {'Minimalist', 'Modern Chic'};

  // ── Notification Preferences ──
  bool notifyRecommendations = true;
  bool notifyPairingAlerts = true;
  bool notifySecurityLogs = false;

  final List<String> undertones = [
    'Warm Gold',
    'Cool Silver',
    'Neutral / Rose',
    'Olive',
  ];

  final List<String> metals = [
    'Yellow Gold',
    'White Gold',
    'Rose Gold',
    'Sterling Silver',
    'Platinum & Diamond',
    'Kundan & Antique',
  ];

  final List<String> aesthetics = [
    'Minimalist',
    'Traditional / Ethnic',
    'Modern Chic',
    'Vintage Royalty',
    'Boho / Layered',
    'Statement Party',
  ];

  final List<String> ringSizes = ['US 5', 'US 6', 'US 7', 'US 8', 'US 9', 'Custom'];
  final List<String> apparelSizes = ['XS', 'S', 'M', 'L', 'XL', 'Custom'];
  final List<String> currencies = ['USD (\$)', 'INR (₹)', 'EUR (€)', 'GBP (£)'];

  @override
  void initState() {
    super.initState();
    final initialName = user?.displayName != null && user!.displayName!.isNotEmpty
        ? user!.displayName!
        : (user?.email != null && user!.email!.contains('@')
            ? user!.email!.split('@')[0][0].toUpperCase() + user!.email!.split('@')[0].substring(1)
            : 'Annika');

    nameController = TextEditingController(text: initialName);
    phoneController = TextEditingController(text: '+1 (555) 234-5678');
    mottoController = TextEditingController(
      text: 'Lover of timeless gold jewelry and minimalist ethnic wear.',
    );
    photoUrl = user?.photoURL;
    _loadPreferences();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    mottoController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      selectedUndertone = _localProfileStore['pref_undertone'] as String? ?? 'Warm Gold';
      selectedMetal = _localProfileStore['pref_metal'] as String? ?? 'Yellow Gold';
      selectedRingSize = _localProfileStore['pref_ring_size'] as String? ?? 'US 7';
      selectedApparelSize = _localProfileStore['pref_apparel_size'] as String? ?? 'M';
      selectedCurrency = _localProfileStore['pref_currency'] as String? ?? 'USD (\$)';
      phoneController.text = _localProfileStore['pref_phone'] as String? ?? '+1 (555) 234-5678';
      mottoController.text = _localProfileStore['pref_motto'] as String? ??
          'Lover of timeless gold jewelry and minimalist ethnic wear.';

      final savedAesthetics = _localProfileStore['pref_aesthetics'] as List<String>?;
      if (savedAesthetics != null) {
        selectedAesthetics.clear();
        selectedAesthetics.addAll(savedAesthetics);
      }

      notifyRecommendations = _localProfileStore['pref_notify_rec'] as bool? ?? true;
      notifyPairingAlerts = _localProfileStore['pref_notify_pairing'] as bool? ?? true;
      notifySecurityLogs = _localProfileStore['pref_notify_sec'] as bool? ?? false;

      isLoadingPrefs = false;
    });
  }

  Future<void> _savePreferences() async {
    _localProfileStore['pref_undertone'] = selectedUndertone;
    _localProfileStore['pref_metal'] = selectedMetal;
    _localProfileStore['pref_ring_size'] = selectedRingSize;
    _localProfileStore['pref_apparel_size'] = selectedApparelSize;
    _localProfileStore['pref_currency'] = selectedCurrency;
    _localProfileStore['pref_phone'] = phoneController.text;
    _localProfileStore['pref_motto'] = mottoController.text;
    _localProfileStore['pref_aesthetics'] = selectedAesthetics.toList();

    _localProfileStore['pref_notify_rec'] = notifyRecommendations;
    _localProfileStore['pref_notify_pairing'] = notifyPairingAlerts;
    _localProfileStore['pref_notify_sec'] = notifySecurityLogs;
  }

  Future<void> pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> removePhoto() async {
    setState(() => photoUrl = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo removed — tap Save Changes to confirm')),
      );
    }
  }

  Future<void> saveChanges() async {
    final nameToSave = nameController.text.trim().isEmpty ? 'Annika' : nameController.text.trim();
    await user?.updateDisplayName(nameToSave);
    await user?.updatePhotoURL(photoUrl ?? '');
    await user?.reload();

    await _savePreferences();

    setState(() => isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile & Preferences updated successfully'),
          backgroundColor: AppColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = nameController.text.isEmpty ? 'Annika' : nameController.text;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText, size: 18),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text('Profile & Preferences', style: AppTypography.headingMedium),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check_circle : Icons.edit_note_rounded, color: AppColors.primaryEmerald, size: 24),
            onPressed: isEditing ? saveChanges : () => setState(() => isEditing = true),
            tooltip: isEditing ? 'Save Changes' : 'Edit Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoadingPrefs
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    children: [
                      // ── HERO PROFILE HEADER CARD ──
                      _buildHeaderCard(displayName),
                      const SizedBox(height: 24),

                      // ── PERSONAL INFO & STYLE PREFERENCES SECTION ──
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          final personalCard = _buildPersonalInfoCard();
                          final preferencesCard = _buildStylePreferencesCard();

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: personalCard),
                                const SizedBox(width: 24),
                                Expanded(child: preferencesCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              personalCard,
                              const SizedBox(height: 24),
                              preferencesCard,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── SIZES & NOTIFICATIONS CARD ──
                      _buildApparelAndNotificationCard(),
                      const SizedBox(height: 32),

                      // ── BOTTOM ACTIONS ──
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isEditing ? saveChanges : () => setState(() => isEditing = true),
                              icon: Icon(isEditing ? Icons.check : Icons.edit_outlined, size: 18),
                              label: Text(isEditing ? 'Save Profile' : 'Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: AppTypography.labelLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: logout,
                            icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                            label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: AppTypography.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(String displayName) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentGold, width: 3),
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.accentGoldLight,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: AppTypography.headingLarge.copyWith(color: AppColors.accentGold),
                        )
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
                      color: AppColors.primaryEmerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: isUploadingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (photoUrl != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isUploadingPhoto ? null : removePhoto,
              icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
              label: const Text(
                'Remove Photo',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),

          isEditing
              ? SizedBox(
                  width: 260,
                  child: TextField(
                    controller: nameController,
                    textAlign: TextAlign.center,
                    style: AppTypography.headingSmall,
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                )
              : Text(displayName, style: AppTypography.headingMedium),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline, size: 14, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Text(
                user?.email ?? 'annika@example.com',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentGoldLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentGold.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 14, color: AppColors.accentGold),
                const SizedBox(width: 6),
                Text(
                  'VIP Vault Member',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.primaryEmerald, size: 20),
              const SizedBox(width: 10),
              Text('Personal Details', style: AppTypography.headingSmall.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Phone
          Text('PHONE NUMBER', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          isEditing
              ? TextField(
                  controller: phoneController,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                )
              : Text(phoneController.text, style: AppTypography.labelLarge),

          const SizedBox(height: 18),

          // Style Motto / Bio
          Text('STYLE MOTTO / BIO', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          isEditing
              ? TextField(
                  controller: mottoController,
                  maxLines: 3,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                )
              : Text(
                  mottoController.text,
                  style: AppTypography.bodyMedium.copyWith(height: 1.5),
                ),
        ],
      ),
    );
  }

  Widget _buildStylePreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AppColors.accentGold, size: 20),
              const SizedBox(width: 10),
              Text('Jewelry & Style Profile', style: AppTypography.headingSmall.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Skin Undertone
          Text('SKIN UNDERTONE', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: undertones.map((u) => _choiceChip(
              label: u,
              selected: selectedUndertone == u,
              onTap: isEditing ? () => setState(() => selectedUndertone = u) : null,
            )).toList(),
          ),
          const SizedBox(height: 18),

          // Preferred Metal
          Text('PREFERRED METAL / MATERIAL', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metals.map((m) => _choiceChip(
              label: m,
              selected: selectedMetal == m,
              onTap: isEditing ? () => setState(() => selectedMetal = m) : null,
            )).toList(),
          ),
          const SizedBox(height: 18),

          // Aesthetics
          Text('FAVORITE AESTHETICS', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: aesthetics.map((a) {
              final isSel = selectedAesthetics.contains(a);
              return _choiceChip(
                label: a,
                selected: isSel,
                onTap: isEditing ? () {
                  setState(() {
                    if (isSel) {
                      selectedAesthetics.remove(a);
                    } else {
                      selectedAesthetics.add(a);
                    }
                  });
                } : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildApparelAndNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_outlined, color: AppColors.primaryEmerald, size: 20),
              const SizedBox(width: 10),
              Text('Sizes & Vault Settings', style: AppTypography.headingSmall.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ring Size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEFAULT RING SIZE', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ringSizes.map((rs) => _choiceChip(
                        label: rs,
                        selected: selectedRingSize == rs,
                        onTap: isEditing ? () => setState(() => selectedRingSize = rs) : null,
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Apparel Size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('APPAREL SIZE', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: apparelSizes.map((as) => _choiceChip(
                        label: as,
                        selected: selectedApparelSize == as,
                        onTap: isEditing ? () => setState(() => selectedApparelSize = as) : null,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 18),

          // Currency & Notification Preferences
          Text('VAULT PREFERENCES', style: AppTypography.labelSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text('Vault Currency', style: AppTypography.labelLarge),
              ),
              DropdownButton<String>(
                value: selectedCurrency,
                underline: const SizedBox(),
                dropdownColor: AppColors.surface,
                style: AppTypography.labelLarge.copyWith(color: AppColors.primaryEmerald),
                onChanged: isEditing ? (v) => setState(() => selectedCurrency = v!) : null,
                items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              ),
            ],
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Outfit Recommendations', style: AppTypography.labelLarge),
            subtitle: Text('Receive AI style suggestions and pairing tips', style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText)),
            value: notifyRecommendations,
            activeColor: AppColors.primaryEmerald,
            onChanged: isEditing ? (v) => setState(() => notifyRecommendations = v) : null,
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Jewelry Pairing Alerts', style: AppTypography.labelLarge),
            subtitle: Text('Get notified when new jewelry matches your closet', style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText)),
            value: notifyPairingAlerts,
            activeColor: AppColors.primaryEmerald,
            onChanged: isEditing ? (v) => setState(() => notifyPairingAlerts = v) : null,
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryEmerald : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryEmerald : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: 11,
            color: selected ? Colors.white : AppColors.primaryText,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
