import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import 'customer_signup.dart';
import 'password_screen.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

/// Used for the login OTP flow only.
/// For collector sign-up OTP, use [CollectorOtpWidget] inside collector_signup.dart.
class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _otpSubmitted = false;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == 4;

  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _resendOtp() async {
    try {
      await ApiService.post(
        ApiConstants.sendOtp,
        {'phone': widget.phone},
        authenticated: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend OTP')),
      );
    }
  }

  Future<void> _verify() async {
    if (!_isComplete || _otpSubmitted || _isLoading) return;
    _otpSubmitted = true;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.post(
        ApiConstants.verifyOtp,
        {'phone': widget.phone, 'otp_code': _otp},
        authenticated: false,
      );
      if (!mounted) return;

      if (data['is_new_user'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerSignupPage(initialPhone: widget.phone),
          ),
        );
        return;
      }

      // Existing account — use password login instead of OTP
      final hasPassword = data['has_password'] == true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordScreen(
            phone: widget.phone,
            mode: hasPassword
                ? PasswordScreenMode.login
                : PasswordScreenMode.setPassword,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _otpSubmitted = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      _otpSubmitted = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to connect. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 20, color: _kTextDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.message_outlined,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Verify your number',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _kTextDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 4-digit code sent to\n${widget.phone}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _kTextGray, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.all(28),
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
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(4, (i) {
                                  final filled =
                                      _controllers[i].text.isNotEmpty;
                                  return SizedBox(
                                    width: 60,
                                    height: 64,
                                    child: TextField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _kTextDark,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: filled
                                            ? _kLightGreen
                                            : const Color(0xFFF5F5F5),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: filled
                                                ? _kPrimary
                                                : const Color(0xFFE0E0E0),
                                            width: filled ? 1.5 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: _kPrimary, width: 2),
                                        ),
                                      ),
                                      onChanged: (v) => _onDigitEntered(i, v),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      (_isComplete && !_isLoading) ? _verify : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kPrimary,
                                    disabledBackgroundColor:
                                        const Color(0xFFE0E0E0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Verify & Login',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Didn't receive code? ",
                                    style: TextStyle(
                                        color: _kTextGray, fontSize: 13),
                                  ),
                                  GestureDetector(
                                    onTap: _resendOtp,
                                    child: const Text(
                                      'Resend',
                                      style: TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
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
}
