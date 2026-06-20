import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/profile_avatar.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import 'history.dart';
import 'notification.dart';
import 'saved_address.dart';
import 'payment.dart';
import 'reports.dart';
import 'help_support.dart';
import 'rate_app.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final addressCount = provider.savedAddresses.length;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Dark green header with rounded bottom corners
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
                child: Column(
                  children: [
                    // Back + Edit row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white),
                            onPressed: () => _showEditSheet(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Avatar with camera badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: ProfileAvatar(
                            imageUrl: provider.profileImageUrl,
                            radius: 50,
                            fallbackInitial: provider.displayInitial,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditSheet(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      provider.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (provider.currentUser?['email'] as String?) ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (provider.currentUser?['phone'] as String?) ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('ACCOUNT'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _tile(
                      context,
                      icon: Icons.location_on_outlined,
                      label: 'Saved Addresses',
                      badge: addressCount > 0 ? '$addressCount' : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SavedAddressesPage()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      context,
                      icon: Icons.credit_card_outlined,
                      label: 'Payment Methods',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PaymentMethodsPage()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      context,
                      icon: Icons.notifications_none_outlined,
                      label: 'Notifications',
                      badge: provider.unreadNotifications > 0
                          ? '${provider.unreadNotifications}'
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationPage()),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _sectionLabel('ACTIVITY'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _tile(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'Service History',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ServiceHistoryPage()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      context,
                      icon: Icons.campaign_outlined,
                      label: 'Dumping Reports',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DumpingReportsPage()),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _sectionLabel('SUPPORT'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _tile(
                      context,
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HelpSupportPage()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      context,
                      icon: Icons.star_outline_rounded,
                      label: 'Rate the App',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RateAppPage()),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await provider.logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/', (_) => false);
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _kTextGray,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _menuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: _kLightGreen,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: _kPrimary, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: _kTextDark,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.chevron_right, color: _kTextGray),
        ],
      ),
    );
  }
}

// ── Edit profile bottom sheet ───────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _firstCtrl  = TextEditingController();
  final _lastCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  bool _saving = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().currentUser;
    _firstCtrl.text = (user?['first_name'] as String?) ?? '';
    _lastCtrl.text  = (user?['last_name']  as String?) ?? '';
    _emailCtrl.text = (user?['email']      as String?) ?? '';
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    final first = _firstCtrl.text.trim();
    final last  = _lastCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final provider = context.read<AppProvider>();
      if (_imageFile != null) {
        await ApiService.patchMultipart(
          ApiConstants.customerProfileUpdate,
          {
            'first_name': first,
            'last_name': last,
            if (email.isNotEmpty) 'email': email,
          },
          imageFile: _imageFile,
        );
        await provider.refreshProfileImageFromServer();
        provider.setCurrentUser({
          ...?provider.currentUser,
          'first_name': first,
          'last_name': last,
          if (email.isNotEmpty) 'email': email,
        });
      } else {
        await provider.updateProfile({
          'first_name': first,
          'last_name': last,
          if (email.isNotEmpty) 'email': email,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Profile',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark)),
            const SizedBox(height: 16),
            // Profile image picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _kPrimary.withOpacity(0.1),
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : null,
                      child: _imageFile == null
                          ? Text(
                              context.read<AppProvider>().displayInitial,
                              style: const TextStyle(color: _kPrimary, fontSize: 32, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _field(label: 'First Name', ctrl: _firstCtrl, hint: 'Kwame'),
            const SizedBox(height: 14),
            _field(label: 'Last Name', ctrl: _lastCtrl, hint: 'Mensah'),
            const SizedBox(height: 14),
            _field(
              label: 'Email Address',
              ctrl: _emailCtrl,
              hint: 'kwame@example.com',
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _kTextDark)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          textCapitalization: type == TextInputType.emailAddress
              ? TextCapitalization.none
              : TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextGray),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _kPrimary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
