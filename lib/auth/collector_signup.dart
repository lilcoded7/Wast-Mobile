import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import 'password_screen.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

/// Multi-step collector sign-up:
/// Step 1 — name + vehicle type
/// Step 2 — phone number → Send OTP
/// Step 3 — OTP verification
/// Step 4 — submit registration → success screen
class CollectorSignupPage extends StatefulWidget {
  const CollectorSignupPage({super.key});

  @override
  State<CollectorSignupPage> createState() => _CollectorSignupPageState();
}

enum _Step { info, phone, otp, success }

class _CollectorSignupPageState extends State<CollectorSignupPage> {
  _Step _step = _Step.info;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(4, (_) => FocusNode());

  String _selectedVehicle = 'Pickup Truck';
  static const List<String> _vehicleTypes = [
    'Pickup Truck',
    'Mini Van',
    'Large Van',
    'Tipper Truck',
  ];

  bool _isLoading = false;
  bool _otpSubmitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpCtrls.map((c) => c.text).join();
  bool get _otpComplete => _otpCode.length == 4;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Step 1 → Step 2
  void _goToPhone() {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your full name');
      return;
    }
    setState(() => _step = _Step.phone);
  }

  Future<void> _goToPassword(String phone, bool hasPassword) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordScreen(
          phone: phone,
          mode: hasPassword
              ? PasswordScreenMode.login
              : PasswordScreenMode.setPassword,
        ),
      ),
    );
  }

  // Step 2 → Step 3: check phone first, OTP only for new numbers
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showSnack('Please enter your phone number');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final check = await ApiService.post(
        ApiConstants.checkPhone,
        {'phone': phone},
        authenticated: false,
      );
      if (!mounted) return;

      if (check['exists'] == true) {
        final role = check['role'] as String? ?? '';
        if (role != 'collector' && role.isNotEmpty) {
          _showSnack('This number belongs to a $role account. Use customer login.');
          return;
        }
        await _goToPassword(phone, check['has_password'] == true);
        return;
      }

      await ApiService.post(
        ApiConstants.sendOtp,
        {'phone': phone},
        authenticated: false,
      );
      if (!mounted) return;
      setState(() {
        _otpSubmitted = false;
        _step = _Step.otp;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to connect. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Resend OTP from step 3
  Future<void> _resendOtp() async {
    try {
      await ApiService.post(
        ApiConstants.sendOtp,
        {'phone': _phoneCtrl.text.trim()},
        authenticated: false,
      );
      if (!mounted) return;
      _showSnack('OTP resent successfully');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to resend OTP');
    }
  }

  // Step 3 → verify OTP then register
  Future<void> _verifyAndRegister() async {
    if (!_otpComplete || _otpSubmitted || _isLoading) return;
    _otpSubmitted = true;
    setState(() => _isLoading = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final verifyData = await ApiService.post(
        ApiConstants.verifyOtp,
        {'phone': phone, 'otp_code': _otpCode},
        authenticated: false,
      );
      if (!mounted) return;

      if (verifyData['is_new_user'] != true) {
        await _goToPassword(
          phone,
          verifyData['has_password'] == true,
        );
        return;
      }
      final regData = await ApiService.post(
        ApiConstants.registerCollector,
        {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'vehicle_type': _selectedVehicle,
        },
        authenticated: false,
      );
      if (!mounted) return;

      // Save tokens so the user is logged in
      await ApiService.saveTokens(
        access: regData['tokens']['access'] as String,
        refresh: regData['tokens']['refresh'] as String,
      );
      if (!mounted) return;

      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.setCurrentUser(
          Map<String, dynamic>.from(regData['user'] as Map));

      setState(() => _step = _Step.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      _otpSubmitted = false;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _otpSubmitted = false;
      _showSnack('Unable to connect. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpDigit(int index, String value) {
    if (value.length == 1 && index < 3) {
      _otpFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _handleBack() {
    switch (_step) {
      case _Step.info:
        Navigator.pop(context);
      case _Step.phone:
        setState(() => _step = _Step.info);
      case _Step.otp:
        setState(() => _step = _Step.phone);
      case _Step.success:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kLightGreen, _kBg, _kBg],
                stops: [0.0, 0.40, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step != _Step.success)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 20, color: _kTextDark),
                      onPressed: _handleBack,
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _Step.info:
        return _buildInfoStep();
      case _Step.phone:
        return _buildPhoneStep();
      case _Step.otp:
        return _buildOtpStep();
      case _Step.success:
        return _buildSuccessStep();
    }
  }

  // ── Step 1: Name + Vehicle ────────────────────────────────────────────────

  Widget _buildInfoStep() {
    return Column(
      key: const ValueKey('info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _stepIndicator(1, 3),
        const SizedBox(height: 16),
        const Text(
          'Register as Collector',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _kTextDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tell us a bit about yourself',
          style: TextStyle(color: _kTextGray, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _card(children: [
          _label('Full Name'),
          const SizedBox(height: 8),
          _field(
            controller: _nameCtrl,
            hint: 'e.g. Kofi Mensah',
            icon: Icons.person_outline,
            type: TextInputType.name,
          ),
          const SizedBox(height: 16),
          _label('Vehicle Type'),
          const SizedBox(height: 8),
          _vehicleDropdown(),
          const SizedBox(height: 10),
          const Text(
            'Your application will be reviewed before activation.',
            style: TextStyle(color: _kTextGray, fontSize: 12),
          ),
          const SizedBox(height: 28),
          _primaryButton(
            label: 'Next',
            onPressed: _goToPhone,
            isLoading: false,
          ),
          const SizedBox(height: 20),
          _centeredLink(
            prefix: 'Already registered? ',
            linkText: 'Login',
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 2: Phone number ─────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _stepIndicator(2, 3),
        const SizedBox(height: 16),
        const Text(
          'Your phone number',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _kTextDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'ll send a verification code to confirm it',
          style: TextStyle(color: _kTextGray, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _card(children: [
          _label('Phone Number'),
          const SizedBox(height: 8),
          _field(
            controller: _phoneCtrl,
            hint: '+233 24 000 0000',
            icon: Icons.phone_android_outlined,
            type: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          const Text(
            'A 4-digit OTP will be sent to this number',
            style: TextStyle(color: _kTextGray, fontSize: 12),
          ),
          const SizedBox(height: 28),
          _primaryButton(
            label: 'Send OTP',
            onPressed: _isLoading ? null : _sendOtp,
            isLoading: _isLoading,
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 3: OTP verification ─────────────────────────────────────────────

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      children: [
        const SizedBox(height: 16),
        _stepIndicator(3, 3),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.message_outlined,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verify your number',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _kTextDark,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 4-digit code sent to\n${_phoneCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: _kTextGray, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        _card(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              final filled = _otpCtrls[i].text.isNotEmpty;
              return SizedBox(
                width: 60,
                height: 64,
                child: TextField(
                  controller: _otpCtrls[i],
                  focusNode: _otpFocus[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _kTextDark),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor:
                        filled ? _kLightGreen : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: filled ? _kPrimary : const Color(0xFFE0E0E0),
                        width: filled ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _kPrimary, width: 2),
                    ),
                  ),
                  onChanged: (v) => _onOtpDigit(i, v),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          _primaryButton(
            label: 'Verify & Register',
            onPressed: (_otpComplete && !_isLoading)
                ? _verifyAndRegister
                : null,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Didn't receive code? ",
                  style: TextStyle(color: _kTextGray, fontSize: 13)),
              GestureDetector(
                onTap: _resendOtp,
                child: const Text('Resend',
                    style: TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 4: Success ───────────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _kLightGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              color: _kPrimary, size: 56),
        ),
        const SizedBox(height: 24),
        const Text(
          'Application Submitted!',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _kTextDark),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Your application is under review. You will be notified once your account is approved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kTextGray, fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _primaryButton(
            label: 'Go to Collector Dashboard',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/collector-home', (_) => false),
            isLoading: false,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _stepIndicator(int current, int total) => Row(
        children: List.generate(total, (i) {
          final active = i < current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? _kPrimary : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14, color: _kTextDark),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: _kTextDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kTextGray),
          prefixIcon: Icon(icon, size: 20, color: _kTextGray),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
        ),
      );

  Widget _vehicleDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedVehicle,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: _kTextGray),
            style: const TextStyle(color: _kTextDark, fontSize: 14),
            items: _vehicleTypes
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Row(children: [
                        const Icon(Icons.local_shipping_outlined,
                            color: _kPrimary, size: 18),
                        const SizedBox(width: 10),
                        Text(v),
                      ]),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedVehicle = v);
            },
          ),
        ),
      );

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
        ),
      );

  Widget _centeredLink({
    required String prefix,
    required String linkText,
    required VoidCallback onTap,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(prefix,
              style: const TextStyle(color: _kTextGray, fontSize: 13)),
          GestureDetector(
            onTap: onTap,
            child: Text(linkText,
                style: const TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      );
}
