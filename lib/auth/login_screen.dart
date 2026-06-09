import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import '../pages/dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cyberpunk / Dark SCADA Palette (sama dengan dashboard)
// ─────────────────────────────────────────────────────────────────────────────
const _bgDeep     = Color(0xFF0D0E15);
const _bgCard     = Color(0xFF12131E);
const _bgField    = Color(0xFF1A1B2E);
const _neonBlue   = Color(0xFF00D4FF);
const _neonGreen  = Color(0xFF00FF9C);
const _neonRed    = Color(0xFFFF2D55);
const _dimText    = Color(0xFF6E7191);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading      = false;
  bool _isGoogleLoading = false;
  bool _isObscure      = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Navigasi ke Dashboard ──────────────────────────────────────────────────
  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  // ── Login Email ────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = await _authService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null && mounted) _goToDashboard();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = AuthService.translateError(e.code));
    } catch (_) {
      setState(() => _errorMessage = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Login Google ───────────────────────────────────────────────────────────
  Future<void> _handleGoogleLogin() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) _goToDashboard();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = AuthService.translateError(e.code));
    } catch (_) {
      setState(() => _errorMessage = 'Login Google gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // ── LOGO / ICON ──────────────────────────────────────
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _neonBlue.withValues(alpha: 0.08),
                          border: Border.all(
                            color: _neonBlue.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _neonBlue.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.developer_board_rounded,
                          size: 44,
                          color: _neonBlue,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── JUDUL ────────────────────────────────────────────
                      const Text(
                        "MINIBOT TRKJ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Sistem Kendali Telemetri Robot",
                        style: TextStyle(
                          color: _dimText,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 44),

                      // ── SECTION LABEL ────────────────────────────────────
                      _sectionLabel("MASUK KE SISTEM"),
                      const SizedBox(height: 16),

                      // ── EMAIL FIELD ──────────────────────────────────────
                      _buildTextField(
                        controller:  _emailController,
                        label:       "Email Address",
                        icon:        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email tidak boleh kosong';
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── PASSWORD FIELD ───────────────────────────────────
                      _buildTextField(
                        controller: _passwordController,
                        label:      "Password",
                        icon:       Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
                          if (v.length < 6) return 'Password minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── ERROR MESSAGE ────────────────────────────────────
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _neonRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _neonRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: _neonRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: _neonRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── TOMBOL LOGIN EMAIL ───────────────────────────────
                      _primaryButton(
                        label:     "Masuk Sekarang",
                        icon:      Icons.login_rounded,
                        color:     _neonBlue,
                        isLoading: _isLoading,
                        onTap:     _isLoading || _isGoogleLoading ? null : _handleLogin,
                      ),
                      const SizedBox(height: 20),

                      // ── DIVIDER OR ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "ATAU",
                              style: TextStyle(
                                color: _dimText,
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── TOMBOL GOOGLE ────────────────────────────────────
                      _googleButton(),
                      const SizedBox(height: 36),

                      // ── DAFTAR LINK ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Belum punya akun? ",
                            style: TextStyle(color: _dimText, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                            child: const Text(
                              "Daftar Disini",
                              style: TextStyle(
                                color: _neonBlue,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _neonBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _dimText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:    controller,
      obscureText:   isPassword ? _isObscure : false,
      keyboardType:  keyboardType,
      validator:     validator,
      style:         const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor:   _neonBlue,
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _dimText, fontSize: 13),
        prefixIcon: Icon(icon, color: _neonBlue.withValues(alpha: 0.7), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _dimText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _isObscure = !_isObscure),
              )
            : null,
        filled:          true,
        fillColor:       _bgField,
        contentPadding:  const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonBlue, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonRed, width: 1.2),
        ),
        errorStyle: const TextStyle(color: _neonRed, fontSize: 11),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:  color.withValues(alpha: 0.15),
          foregroundColor:  color,
          side:             BorderSide(color: color.withValues(alpha: 0.5), width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? "Memproses..." : label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading || _isGoogleLoading ? null : _handleGoogleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _bgCard,
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: _neonGreen,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo G warna-warni
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                      children: [
                        TextSpan(
                            text: "G",
                            style: TextStyle(color: Color(0xFF4285F4))),
                        TextSpan(
                            text: "o",
                            style: TextStyle(color: Color(0xFFEA4335))),
                        TextSpan(
                            text: "o",
                            style: TextStyle(color: Color(0xFFFBBC05))),
                        TextSpan(
                            text: "g",
                            style: TextStyle(color: Color(0xFF4285F4))),
                        TextSpan(
                            text: "l",
                            style: TextStyle(color: Color(0xFF34A853))),
                        TextSpan(
                            text: "e",
                            style: TextStyle(color: Color(0xFFEA4335))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Masuk dengan Google",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}