import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../theme/theme_service.dart';
import 'history_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gemini API Config — Ganti dengan API Key Anda dari Google AI Studio
// https://aistudio.google.com/app/apikey
// ─────────────────────────────────────────────────────────────────────────────
const _geminiApiKey   = 'GANTI_DENGAN_API_KEY_ANDA';
const _geminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent';

const _systemPrompt   =
    'Kamu adalah asisten robot pintar bernama MiniBot. Respons kamu WAJIB diawali dengan salah satu tag emosi berikut: [HAPPY], [SAD], [SCARED], atau [NORMAL] sesuai dengan nada jawabanmu. Kepribadianmu super excited, seru, gaul, dan friendly banget. Gunakan gaya bahasa anak muda ekspresif (seperti kata "Gue", "Lu", "Bro", atau "Wkwk"). Jawablah pertanyaan user dengan sangat singkat, MAKSIMAL 4 SAMPAI 6 KATA SAJA setelah tag emosi, tanpa karakter aneh. Contoh format: "[HAPPY] Halo Bro! Ada apa nih? Wkwk", "[HAPPY] Gue sehat banget dong, lu?", "[NORMAL] Semua aman terkendali kok, Bro."';

// ─────────────────────────────────────────────────────────────────────────────
// Cyberpunk / Dark SCADA Palette
// ─────────────────────────────────────────────────────────────────────────────


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── Getter Warna Dinamis untuk Tema & Warna Neon ──
  Color get _bgDeep => ThemeService.instance.isDark ? const Color(0xFF0D0E15) : const Color(0xFFF4F5F9);
  Color get _bgCard => ThemeService.instance.isDark ? const Color(0xFF12131E) : Colors.white;
  Color get _bgButton => ThemeService.instance.isDark ? const Color(0xFF161722) : const Color(0xFFE8EAF6);
  Color get _neonBlue => ThemeService.instance.primaryColor;
  Color get _neonGreen => ThemeService.instance.isDark ? const Color(0xFF00FF9C) : const Color(0xFF00B876);
  Color get _neonOrange => ThemeService.instance.isDark ? const Color(0xFFFF6B35) : const Color(0xFFE05315);
  Color get _neonRed => ThemeService.instance.isDark ? const Color(0xFFFF2D55) : const Color(0xFFD31F41);
  Color get _neonYellow => ThemeService.instance.isDark ? const Color(0xFFFFD60A) : const Color(0xFFC09000);
  Color get _dimText => ThemeService.instance.isDark ? const Color(0xFF6E7191) : const Color(0xFF8C90B0);

  MqttServerClient? _client;
  bool _isConnected = false;
  String _robotStatus = "Disconnected dari MQTT Broker";

  // ── SCADA Telemetry State ──────────────────────────────────────────────────
  String _currentEmotion  = "normal";
  int    _currentDistance = 0;
  int    _currentSignal   = 0;

  // ── Telemetry Throttling State untuk Firestore ─────────────────────────────
  String?   _lastSavedEmotion;
  int?      _lastSavedDistance;
  int?      _lastSavedSignal;
  DateTime? _lastSavedTime;

  final String _broker           = "test.mosquitto.org";
  final String _topic            = "minibot/trkj/zega";
  final String _clientIdentifier = "flutter_client_zega";

  // ── AI Voice Chat State ────────────────────────────────────────────────────
  final stt.SpeechToText _speech       = stt.SpeechToText();
  bool   _speechEnabled    = false;
  bool   _isListening      = false;
  bool   _isAiProcessing   = false;
  String _voiceInputText   = "";
  String _lastAiAnswer     = "";
  String _aiStatusMsg      = "Tekan mic untuk bertanya ke MiniBot AI";

  // ── Signal Quality Helper ──────────────────────────────────────────────────
  String _getSignalStatus(int dbm) {
    if (dbm >= -50) return "Excellent";
    if (dbm >= -70) return "Good";
    return "Poor";
  }

  Color _getSignalColor(int dbm) {
    if (dbm >= -50) return _neonGreen;
    if (dbm >= -70) return _neonOrange;
    return _neonRed;
  }

  // ── Emotion Helpers ────────────────────────────────────────────────────────
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":  return _neonGreen;
      case "sad":    return _neonBlue;
      case "scared": return _neonRed;
      default:       return _neonYellow;
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":  return Icons.sentiment_very_satisfied_rounded;
      case "sad":    return Icons.sentiment_very_dissatisfied_rounded;
      case "scared": return Icons.gpp_bad_rounded;
      default:       return Icons.smart_toy_rounded;
    }
  }

  // ── CONNECT MQTT ───────────────────────────────────────────────────────────
  Future<void> _connectMQTT() async {
    setState(() => _robotStatus = "Menghubungkan ke MQTT Broker...");

    try {
      _client = MqttServerClient(_broker, _clientIdentifier);
      _client!.port            = 1883;
      _client!.keepAlivePeriod = 60;
      _client!.logging(on: true);
      _client!.useWebSocket    = false;
      _client!.secure          = false;
      _client!.setProtocolV311();
      _client!.autoReconnect   = false;

      _client!.onDisconnected = () {
        setState(() {
          _isConnected = false;
          _robotStatus = "Koneksi Terputus";
        });
      };

      // keepAliveFor via connectionMessage sudah deprecated di versi baru;
      // nilai keepAlive diambil dari _client!.keepAlivePeriod di atas.
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientIdentifier)
          .startClean();
      _client!.connectionMessage = connMessage;

      await _client!.connect();
      final status = _client!.connectionStatus;

      if (status != null && status.state == MqttConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _robotStatus = "Terhubung ke MQTT Broker";
        });
        _showSnackBar("✓ MQTT Connected!", _neonGreen);

        // ── Subscribe & parse JSON telemetry from ESP32 ──────────────────
        _client!.subscribe(_topic, MqttQos.atMostOnce);
        _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
          final recMess       = c![0].payload as MqttPublishMessage;
          final payloadString = String.fromCharCodes(recMess.payload.message);

          debugPrint("Menerima dari ESP32: $payloadString");

          try {
            final Map<String, dynamic> data = jsonDecode(payloadString);
            setState(() {
              _currentEmotion  = (data['status'] ?? _currentEmotion).toString();
              _currentDistance = ((data['jarak']  ?? _currentDistance) as num).toInt();
              _currentSignal   = ((data['sinyal'] ?? _currentSignal)   as num).toInt();
            });
            _saveTelemetryToFirestore(_currentDistance, _currentSignal, _currentEmotion);
          } catch (_) {
            // Payload bukan JSON (misal ACK string biasa) — abaikan saja
            debugPrint("Payload bukan JSON, diabaikan: $payloadString");
          }
        });
      } else {
        _disconnectMQTT();
      }
    } catch (e) {
      debugPrint("MQTT ERROR: $e");
      _disconnectMQTT();
      _showSnackBar("✗ Gagal konek MQTT", _neonRed);
    }
  }

  // ── DISCONNECT ─────────────────────────────────────────────────────────────
  void _disconnectMQTT() {
    _client?.disconnect();
    setState(() {
      _isConnected = false;
      _robotStatus = "Disconnected";
    });
  }

  // ── SEND COMMAND (Manual Override) ────────────────────────────────────────
  void _sendCommand(String command) {
    if (_client == null ||
        !_isConnected ||
        _client!.connectionStatus?.state != MqttConnectionState.connected) {
      _showSnackBar("⚠ MQTT belum connect", _neonOrange);
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    _client!.publishMessage(_topic, MqttQos.atMostOnce, builder.payload!);
    _showSnackBar("▶ Sent: ${command.toUpperCase()}", _neonBlue);
  }

  // ── SNACKBAR ───────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    // Tampilkan dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _neonRed, size: 22),
            const SizedBox(width: 10),
            const Text(
              "Konfirmasi Logout",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Apakah kamu yakin ingin keluar dari sistem?",
          style: TextStyle(color: _dimText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: _dimText),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonRed.withValues(alpha: 0.15),
              foregroundColor: _neonRed,
              side: BorderSide(color: _neonRed.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Ya, Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _disconnectMQTT(); // Putuskan MQTT sebelum logout
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  // ── INIT SPEECH ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (e) => debugPrint('STT Error: $e'),
      debugLogging: true,
    );
    setState(() {});
  }

  // ── START VOICE → AI → MQTT ────────────────────────────────────────────────
  Future<void> _startVoiceAI() async {
    if (!_speechEnabled) {
      _showSnackBar('⚠ Mikrofon tidak tersedia', _neonOrange);
      return;
    }

    if (_isListening) {
      // Stop jika sedang mendengarkan
      await _speech.stop();
      setState(() { _isListening = false; });
      return;
    }

    setState(() {
      _isListening    = true;
      _voiceInputText = '';
      _aiStatusMsg    = '🎙 Mendengarkan...';
    });

    await _speech.listen(
      onResult: (result) async {
        setState(() => _voiceInputText = result.recognizedWords);

        // Ketika hasil akhir diterima
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          setState(() {
            _isListening  = false;
            _aiStatusMsg  = '⚡ Memproses: "${result.recognizedWords}"';
          });
          await _speech.stop();
          await _askGemini(result.recognizedWords);
        }
      },
      listenFor:     const Duration(seconds: 10),
      pauseFor:      const Duration(seconds: 3),
      localeId:      'id_ID',
      cancelOnError: true,
    );
  }

  // ── GEMINI API CALL ────────────────────────────────────────────────────────
  Future<void> _askGemini(String question) async {
    setState(() => _isAiProcessing = true);

    if (_geminiApiKey == 'GANTI_DENGAN_API_KEY_ANDA') {
      _showSnackBar('⚠ Set dulu Gemini API Key di kode!', _neonOrange);
      setState(() {
        _isAiProcessing = false;
        _aiStatusMsg    = '⚠ API Key belum diset';
      });
      return;
    }

    try {
      final uri = Uri.parse('$_geminiEndpoint?key=$_geminiApiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{ 'text': _systemPrompt }]
          },
          'contents': [
            {
              'parts': [{ 'text': question }]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 2048,
            'temperature': 0.3,
          }
        }),
      );

      debugPrint('=== GEMINI RESPONSE ===');
      debugPrint('Status Code : ${response.statusCode}');
      debugPrint('Body        : ${response.body}');

      if (response.statusCode == 200) {
        final json      = jsonDecode(response.body);
        final rawText   = json['candidates'][0]['content']['parts'][0]['text']
            .toString()
            .trim();

        // Tentukan emosi dan bersihkan jawaban
        String emotion = 'normal';
        String cleanAnswer = rawText;

        final emotionRegex = RegExp(r'^\[(HAPPY|SAD|SCARED|NORMAL)\]\s*(.*)', caseSensitive: false);
        final match = emotionRegex.firstMatch(rawText);
        if (match != null) {
          emotion = match.group(1)!.toLowerCase();
          cleanAnswer = match.group(2)!.trim();
        }

        // Hilangkan karakter aneh dari jawaban bersih
        cleanAnswer = cleanAnswer.replaceAll(RegExp(r'[^a-zA-Z0-9\s,.!?\-]'), '');

        // 1. Kirim ekspresi fisik robot terlebih dahulu ke MQTT
        _sendCommand(emotion);

        // 2. Kirim pesan OLED setelah delay singkat (1.5 detik) agar gerakan/suara ESP32 selesai
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            final mqttPayload = 'msg:$cleanAnswer';
            _sendCommand(mqttPayload);
            debugPrint('Publish ke MQTT: $mqttPayload');
          }
        });

        setState(() {
          _lastAiAnswer = cleanAnswer;
          _aiStatusMsg  = '✓ AI ($emotion): "$cleanAnswer"';
          _isAiProcessing = false;
        });
        _saveChatToFirestore(question, cleanAnswer, emotion);
      } else {
        final errorBody = jsonDecode(response.body);
        final errMsg = errorBody['error']['message'] ?? 'Error ${response.statusCode}';
        debugPrint('=== GEMINI ERROR === code:${response.statusCode} msg:$errMsg');
        setState(() {
          _aiStatusMsg    = '✗ [${response.statusCode}] $errMsg';
          _isAiProcessing = false;
        });
        _showSnackBar('✗ Gemini [${response.statusCode}]', _neonRed);
      }
    } catch (e) {
      setState(() {
        _aiStatusMsg    = '✗ Koneksi gagal';
        _isAiProcessing = false;
      });
      _showSnackBar('✗ Gagal hubungi AI: $e', _neonRed);
      debugPrint('Gemini Exception: $e');
    }
  }

  // ── Simpan Log Telemetri ke Firestore dengan Throttling ─────────────────────
  Future<void> _saveTelemetryToFirestore(int distance, int signal, String emotion) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    bool shouldSave = false;

    if (_lastSavedTime == null || _lastSavedEmotion == null || _lastSavedDistance == null || _lastSavedSignal == null) {
      shouldSave = true;
    } else {
      final timeDiff = now.difference(_lastSavedTime!);
      final distDiff = (distance - _lastSavedDistance!).abs();
      final sigDiff = (signal - _lastSavedSignal!).abs();

      // Hanya simpan jika emosi berubah, jarak berubah >= 5 cm, sinyal berubah >= 8 dBm, atau sudah lewat 15 detik
      if (emotion != _lastSavedEmotion || distDiff >= 5 || sigDiff >= 8 || timeDiff.inSeconds >= 15) {
        shouldSave = true;
      }
    }

    if (!shouldSave) return;

    _lastSavedEmotion = emotion;
    _lastSavedDistance = distance;
    _lastSavedSignal = signal;
    _lastSavedTime = now;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity_logs')
          .add({
        'type': 'telemetry',
        'timestamp': FieldValue.serverTimestamp(),
        'distance': distance,
        'signal': signal,
        'emotion': emotion,
      });
      debugPrint("Telemetri berhasil disimpan ke Firestore");
    } catch (e) {
      debugPrint("Gagal menyimpan telemetri ke Firestore: $e");
    }
  }

  // ── Simpan Log Chat AI ke Firestore ────────────────────────────────────────
  Future<void> _saveChatToFirestore(String question, String answer, String emotion) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity_logs')
          .add({
        'type': 'chat',
        'timestamp': FieldValue.serverTimestamp(),
        'question': question,
        'answer': answer,
        'emotion': emotion,
      });
      debugPrint("Chat AI berhasil disimpan ke Firestore");
    } catch (e) {
      debugPrint("Gagal menyimpan Chat AI ke Firestore: $e");
    }
  }

  // ── Helper: Item Menu Navigation Drawer ───────────────────────────────────
  Widget _drawerItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    Color textColor = Colors.white70,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
      ),
    );
  }

  // ── Helper: Dialog Edit Profil (Nama & Foto/Avatar) ──────────────────────
  void _showEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: user?.displayName ?? "");
    final photoController = TextEditingController(text: user?.photoURL ?? "");
    File? selectedImageFile;
    bool isUploading = false;

    // 4 Robot Avatar Pilihan Cepat dari Dicebear API
    final List<String> presetAvatars = [
      "https://api.dicebear.com/7.x/bottts/png?seed=RoboZega",
      "https://api.dicebear.com/7.x/bottts/png?seed=AlphaBot",
      "https://api.dicebear.com/7.x/bottts/png?seed=CyberBot",
      "https://api.dicebear.com/7.x/bottts/png?seed=NeonBot",
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _neonBlue.withValues(alpha: 0.3), width: 1),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit_rounded, color: _neonBlue, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "Edit Profil",
                    style: TextStyle(
                      color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Foto Profil dengan Tombol Pilih
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _neonBlue, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonBlue.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: _bgDeep,
                              backgroundImage: selectedImageFile != null
                                  ? FileImage(selectedImageFile!) as ImageProvider
                                  : (photoController.text.isNotEmpty
                                      ? NetworkImage(photoController.text) as ImageProvider
                                      : null),
                              child: (selectedImageFile == null && photoController.text.isEmpty)
                                  ? const Icon(Icons.person_rounded, color: Colors.white30, size: 40)
                                  : null,
                            ),
                          ),
                          if (!isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 512,
                                    maxHeight: 512,
                                    imageQuality: 75,
                                  );
                                  if (image != null) {
                                    setDialogState(() {
                                      selectedImageFile = File(image.path);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _neonBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.black,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        selectedImageFile != null ? "Gambar dipilih dari galeri" : "Pilih foto profil kustom",
                        style: TextStyle(color: _dimText, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Input Nama Tampilan
                    Text(
                      "NAMA TAMPILAN",
                      style: TextStyle(color: _dimText, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      enabled: !isUploading,
                      style: TextStyle(
                        color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _bgDeep,
                        hintText: "Masukkan nama profil...",
                        hintStyle: TextStyle(color: _dimText, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _neonBlue, width: 1),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Pilihan Cepat Avatar
                    Text(
                      "PILIH AVATAR CEPAT",
                      style: TextStyle(color: _dimText, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: presetAvatars.map((url) {
                        final isSelected = selectedImageFile == null && photoController.text == url;
                        return InkWell(
                          onTap: isUploading
                              ? null
                              : () {
                                  setDialogState(() {
                                    photoController.text = url;
                                    selectedImageFile = null;
                                  });
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _bgDeep,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? _neonBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.smart_toy_rounded,
                                  color: Colors.white30,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: _neonBlue, strokeWidth: 2.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Mengunggah foto profil...",
                              style: TextStyle(color: _neonBlue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: isUploading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(foregroundColor: _dimText),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (user != null) {
                            setDialogState(() {
                              isUploading = true;
                            });
                            try {
                              String? finalPhotoUrl = photoController.text.trim();

                              if (selectedImageFile != null) {
                                final storageRef = FirebaseStorage.instance
                                    .ref()
                                    .child('users/${user.uid}/profile.jpg');
                                await storageRef.putFile(selectedImageFile!);
                                finalPhotoUrl = await storageRef.getDownloadURL();
                              }

                              await user.updateDisplayName(nameController.text.trim());
                              if (finalPhotoUrl.isNotEmpty) {
                                await user.updatePhotoURL(finalPhotoUrl);
                              }
                              await user.reload();

                              setState(() {}); // Refresh dashboard

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showSnackBar("✓ Profil berhasil diperbarui!", _neonGreen);
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() {
                                  isUploading = false;
                                });
                                _showSnackBar("✗ Gagal memperbarui profil: $e", _neonRed);
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonBlue.withValues(alpha: 0.15),
                          foregroundColor: _neonBlue,
                          side: BorderSide(color: _neonBlue.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  // ── Helper: Widget Navigation Drawer (Drawer Kiri) ───────────────────────
  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? "Pengguna MiniBot";
    final String email = user?.email ?? "";
    final String? photoUrl = user?.photoURL;

    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return Drawer(
          backgroundColor: _bgDeep,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profil
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    border: Border(
                      bottom: BorderSide(color: _neonBlue.withValues(alpha: 0.3), width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _neonBlue, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonBlue.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: _bgButton,
                              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: (photoUrl == null || photoUrl.isEmpty)
                                  ? const Icon(Icons.person_rounded, color: Colors.white, size: 30)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Info Teks
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Item Menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      _drawerItem(
                        label: "Edit Profil",
                        icon: Icons.edit_rounded,
                        iconColor: _neonBlue,
                        textColor: ThemeService.instance.isDark ? Colors.white70 : Colors.black87,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          _showEditProfileDialog();
                        },
                      ),
                      _drawerItem(
                        label: "Histori Aktivitas",
                        icon: Icons.history_rounded,
                        iconColor: _neonGreen,
                        textColor: ThemeService.instance.isDark ? Colors.white70 : Colors.black87,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HistoryPage()),
                          );
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Divider(color: Colors.white10),
                      ),

                      // PENGATURAN TEMA
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          "PENGATURAN TEMA",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Light / Dark Mode Switcher
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _bgButton,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _dimText.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => ThemeService.instance.setThemeMode(ThemeMode.light),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(9),
                                    bottomLeft: Radius.circular(9),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !ThemeService.instance.isDark
                                          ? _neonBlue.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(9),
                                        bottomLeft: Radius.circular(9),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.light_mode_rounded,
                                          size: 14,
                                          color: !ThemeService.instance.isDark ? _neonBlue : _dimText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Terang",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: !ThemeService.instance.isDark
                                                ? (ThemeService.instance.isDark ? Colors.white : Colors.black87)
                                                : _dimText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 18,
                                color: _dimText.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => ThemeService.instance.setThemeMode(ThemeMode.dark),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(9),
                                    bottomRight: Radius.circular(9),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: ThemeService.instance.isDark
                                          ? _neonBlue.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(9),
                                        bottomRight: Radius.circular(9),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.dark_mode_rounded,
                                          size: 14,
                                          color: ThemeService.instance.isDark ? _neonBlue : _dimText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Gelap",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: ThemeService.instance.isDark
                                                ? Colors.white
                                                : _dimText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          "KOMBINASI WARNA NEON",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Color presets Wrap
                      ...ThemeService.colorPresets.map((preset) {
                        final isSelected = ThemeService.instance.primaryColor.value == preset.primary.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          child: InkWell(
                            onTap: () => ThemeService.instance.setColorTheme(preset.primary, preset.accent),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? preset.primary.withValues(alpha: 0.08)
                                    : _bgCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? preset.primary
                                      : _dimText.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [preset.primary, preset.accent],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      preset.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (ThemeService.instance.isDark ? Colors.white : Colors.black87)
                                            : _dimText,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: preset.primary, size: 14),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Divider(color: Colors.white10),
                      ),
                      _drawerItem(
                        label: "Keluar (Logout)",
                        icon: Icons.logout_rounded,
                        iconColor: _neonRed,
                        textColor: _neonRed,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          _handleLogout();
                        },
                      ),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "MiniBot App v1.2.0",
                    style: TextStyle(
                      color: _dimText.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _disconnectMQTT();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final emotionColor = _getEmotionColor(_currentEmotion);
        final signalColor  = _getSignalColor(_currentSignal);
        final signalStatus = _getSignalStatus(_currentSignal);

        return Scaffold(
          backgroundColor: _bgDeep,
          appBar: AppBar(
            backgroundColor: _bgCard,
            centerTitle: true,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(
                  Icons.menu_rounded,
                  color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                  size: 24,
                ),
                tooltip: 'Menu Utama',
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.developer_board_rounded, color: _neonBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  "MINIBOT TRKJ",
                  style: TextStyle(
                    color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: _neonBlue.withValues(alpha: 0.3),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── 1. MQTT STATUS CARD ────────────────────────────────────────
                _mqttStatusCard(),
                const SizedBox(height: 24),

                // ── 2. CURRENT EMOTION CARD ───────────────────────────────────
                _sectionLabel("EMOSI ROBOT SAAT INI"),
                const SizedBox(height: 10),
                _emotionCard(emotionColor),
                const SizedBox(height: 24),

                // ── 3. REAL-TIME HARDWARE MONITORING ─────────────────────────
                _sectionLabel("REAL-TIME HARDWARE MONITORING"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _telemetryCard(
                        label:     "Jarak Sensor",
                        value:     "$_currentDistance",
                        unit:      "cm",
                        icon:      Icons.radar_rounded,
                        glowColor: _neonBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _telemetryCard(
                        label:     "Kekuatan Sinyal",
                        value:     "$_currentSignal",
                        unit:      "dBm",
                        icon:      Icons.wifi_rounded,
                        glowColor: signalColor,
                        subtitle:  signalStatus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── 4. AI VOICE CHAT STATUS CARD ─────────────────────────────
                _sectionLabel("AI VOICE CHAT → OLED"),
                const SizedBox(height: 10),
                _aiVoiceChatCard(),
                const SizedBox(height: 28),

                // ── 5. MANUAL OVERRIDE CONTROL ────────────────────────────────
                _sectionLabel("MANUAL OVERRIDE CONTROL"),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.4,
                  children: [
                    _overrideBtn("HAPPY",  Icons.sentiment_very_satisfied_rounded,   _neonGreen,  "happy"),
                    _overrideBtn("SAD",    Icons.sentiment_very_dissatisfied_rounded, _neonBlue,   "sad"),
                    _overrideBtn("SCARED", Icons.gpp_bad_rounded,                    _neonRed,    "scared"),
                    _overrideBtn("NORMAL", Icons.smart_toy_rounded,                  _neonYellow, "normal"),
                  ],
                ),

                const SizedBox(height: 90), // ruang untuk FAB
              ],
            ),
          ),
          drawer: _buildDrawer(),
          // ── FAB MIC BUTTON ─────────────────────────────────────────────────────
          floatingActionButton: _micFab(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  // ── AI VOICE CHAT CARD ────────────────────────────────────────────────────
  Widget _aiVoiceChatCard() {
    final Color cardColor = _isListening
        ? _neonRed
        : _isAiProcessing
            ? _neonOrange
            : _lastAiAnswer.isNotEmpty
                ? _neonGreen
                : _neonBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isListening)
                _pulseIcon(Icons.mic_rounded, _neonRed)
              else if (_isAiProcessing)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: _neonOrange, strokeWidth: 2),
                )
              else
                Icon(Icons.smart_toy_rounded, color: cardColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _aiStatusMsg,
                  style: TextStyle(
                    color: cardColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          if (_voiceInputText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _neonBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _neonBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over_rounded,
                      color: _neonBlue, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"$_voiceInputText"',
                      style: TextStyle(
                        color: _neonBlue,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_lastAiAnswer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _neonGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _neonGreen.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.monitor_rounded,
                      color: _neonGreen, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OLED OUTPUT:',
                          style: TextStyle(
                            color: _dimText,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'msg:$_lastAiAnswer',
                          style: TextStyle(
                            color: _neonGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _speechEnabled
                ? 'Tekan tombol \ud83c\udf99 di kanan bawah untuk berbicara'
                : '\u26a0 Izin mikrofon diperlukan',
            style: TextStyle(
              color: _dimText.withValues(alpha: 0.6),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── PULSE ICON ────────────────────────────────────────────────────────────
  Widget _pulseIcon(IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      onEnd: () => setState(() {}),
      child: Icon(icon, color: color, size: 22),
    );
  }

  // ── FAB MIC BUTTON ────────────────────────────────────────────────────────
  Widget _micFab() {
    final Color fabColor = _isListening ? _neonRed : _neonBlue;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: fabColor.withValues(alpha: _isListening ? 0.5 : 0.3),
            blurRadius: _isListening ? 30 : 16,
            spreadRadius: _isListening ? 4 : 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _isAiProcessing ? null : _startVoiceAI,
        backgroundColor: _bgCard,
        shape: CircleBorder(
          side: BorderSide(color: fabColor, width: 1.5),
        ),
        tooltip: 'Bicara ke MiniBot AI',
        child: _isAiProcessing
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: _neonOrange, strokeWidth: 2.5),
              )
            : Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: fabColor,
                size: 28,
              ),
      ),
    );
  }

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
          style: TextStyle(
            color: _dimText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _mqttStatusCard() {
    final statusColor = _isConnected ? _neonGreen : _neonRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.12),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              _isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MQTT BROKER",
                  style: TextStyle(
                    color: _dimText,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _robotStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _isConnected ? _disconnectMQTT : _connectMQTT,
            style: TextButton.styleFrom(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              foregroundColor: statusColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              _isConnected ? "Disconnect" : "Connect",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emotionCard(Color emotionColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emotionColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: emotionColor.withValues(alpha: 0.1),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getEmotionIcon(_currentEmotion), color: emotionColor, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Status Aktif",
                style: TextStyle(
                  color: _dimText,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentEmotion.toUpperCase(),
                style: TextStyle(
                  color: emotionColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _telemetryCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color glowColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: glowColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _dimText,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: glowColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: glowColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: glowColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _overrideBtn(String label, IconData icon, Color color, String cmd) {
    return InkWell(
      onTap: () => _sendCommand(cmd),
      borderRadius: BorderRadius.circular(12),
      splashColor: color.withValues(alpha: 0.2),
      child: Container(
        decoration: BoxDecoration(
          color: _bgButton,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}