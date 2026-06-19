import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/theme_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // ── Getter Warna Dinamis untuk Tema & Warna Neon ──
  Color get _bgDeep => ThemeService.instance.isDark ? const Color(0xFF0D0E15) : const Color(0xFFF4F5F9);
  Color get _bgCard => ThemeService.instance.isDark ? const Color(0xFF12131E) : Colors.white;
  Color get _neonBlue => ThemeService.instance.primaryColor;
  Color get _neonGreen => ThemeService.instance.isDark ? const Color(0xFF00FF9C) : const Color(0xFF00B876);
  Color get _neonRed => ThemeService.instance.isDark ? const Color(0xFFFF2D55) : const Color(0xFFD31F41);
  Color get _neonYellow => ThemeService.instance.isDark ? const Color(0xFFFFD60A) : const Color(0xFFC09000);
  Color get _dimText => ThemeService.instance.isDark ? const Color(0xFF6E7191) : const Color(0xFF8C90B0);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime? _selectedFilterDate;

  // ── Helper: Format Tanggal dalam Bahasa Indonesia ────────────────────────
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    final List<String> realMonths = [
      "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ];

    String formattedDate = "${dt.day} ${realMonths[dt.month]} ${dt.year}";
    if (dateToCheck == today) {
      return "Hari ini - $formattedDate";
    } else if (dateToCheck == yesterday) {
      return "Kemarin - $formattedDate";
    } else {
      return formattedDate;
    }
  }

  // ── Helper: Format Waktu (Jam:Menit) ────────────────────────────────────
  String _formatTime(DateTime dt) {
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  // ── Helper: Mendapatkan Warna Emosi ──────────────────────────────────────
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":  return _neonGreen;
      case "sad":    return _neonBlue;
      case "scared": return _neonRed;
      default:       return _neonYellow;
    }
  }

  // ── Helper: Mendapatkan Icon Emosi ───────────────────────────────────────
  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":  return Icons.sentiment_very_satisfied_rounded;
      case "sad":    return Icons.sentiment_very_dissatisfied_rounded;
      case "scared": return Icons.gpp_bad_rounded;
      default:       return Icons.smart_toy_rounded;
    }
  }

  // ── Pilihan Filter Tanggal ───────────────────────────────────────────────
  Future<void> _selectDateFilter() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedFilterDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ThemeService.instance.isDark
                ? ColorScheme.dark(
                    primary: _neonBlue,
                    onPrimary: Colors.black,
                    surface: _bgCard,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: _neonBlue,
                    onPrimary: Colors.white,
                    surface: _bgCard,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: _bgDeep,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedFilterDate = pickedDate;
      });
    }
  }

  // ── Widget Banner Filter Tanggal Terpilih ─────────────────────────────────
  Widget _buildFilterBanner() {
    final List<String> realMonths = [
      "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ];
    final dateStr = "${_selectedFilterDate!.day} ${realMonths[_selectedFilterDate!.month]} ${_selectedFilterDate!.year}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(
          bottom: BorderSide(color: _neonBlue.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, color: _neonBlue, size: 16),
              const SizedBox(width: 8),
              Text(
                "Filter: $dateStr",
                style: TextStyle(
                  color: _neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedFilterDate = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _neonRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _neonRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.close_rounded, color: _neonRed, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "Hapus Filter",
                    style: TextStyle(
                      color: _neonRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  // ── Hapus Semua Histori Aktivitas ─────────────────────────────────────────
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _neonRed, size: 22),
            const SizedBox(width: 10),
            const Text(
              "Hapus Semua Histori",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin menghapus seluruh riwayat aktivitas MiniBot? Tindakan ini tidak dapat dikembalikan.",
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
            child: const Text("Hapus", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      try {
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('activity_logs');

        final snapshots = await collection.get();
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✓ Seluruh histori berhasil dihapus!",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: _neonRed.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✗ Gagal menghapus histori: $e"),
              backgroundColor: _neonRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: _bgDeep,
        body: const Center(
          child: Text(
            "User tidak terautentikasi.",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _bgDeep,
          appBar: AppBar(
            backgroundColor: _bgCard,
            centerTitle: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, color: _neonBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  "HISTORI AKTIVITAS",
                  style: TextStyle(
                    color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _selectDateFilter,
                icon: Icon(Icons.calendar_month_rounded, color: _neonBlue, size: 22),
                tooltip: 'Filter Tanggal',
              ),
              IconButton(
                onPressed: _clearHistory,
                icon: Icon(Icons.delete_sweep_rounded, color: _neonRed, size: 22),
                tooltip: 'Hapus Semua Histori',
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: _neonBlue.withValues(alpha: 0.3),
              ),
            ),
          ),
          body: Column(
            children: [
              if (_selectedFilterDate != null) _buildFilterBanner(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('activity_logs')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: _neonBlue),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Terjadi kesalahan: ${snapshot.error}",
                          style: TextStyle(color: _neonRed),
                        ),
                      );
                    }

                    var docs = snapshot.data?.docs ?? [];

                    // Filter berdasarkan tanggal yang dipilih
                    if (_selectedFilterDate != null) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['timestamp'];
                        if (timestamp == null) return false;

                        DateTime dt;
                        if (timestamp is Timestamp) {
                          dt = timestamp.toDate();
                        } else {
                          try {
                            dt = DateTime.parse(timestamp.toString());
                          } catch (_) {
                            return false;
                          }
                        }
                        return dt.year == _selectedFilterDate!.year &&
                            dt.month == _selectedFilterDate!.month &&
                            dt.day == _selectedFilterDate!.day;
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      final isFiltered = _selectedFilterDate != null;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isFiltered ? Icons.event_busy_rounded : Icons.history_toggle_off_rounded,
                              color: _dimText.withValues(alpha: 0.4),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isFiltered ? "Tidak ada histori di tanggal ini" : "Belum ada histori aktivitas",
                              style: TextStyle(
                                color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFiltered
                                  ? "Cobalah pilih tanggal lain atau hapus filter."
                                  : "Log telemetri robot dan chat AI akan muncul di sini.",
                              style: TextStyle(color: _dimText.withValues(alpha: 0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    // ── LOGIKA GROUPING BERDASARKAN TANGGAL ──────────────────────────────
                    Map<String, List<QueryDocumentSnapshot>> groupedLogs = {};
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'];
                      if (timestamp == null) continue;

                      DateTime dt;
                      if (timestamp is Timestamp) {
                        dt = timestamp.toDate();
                      } else {
                        try {
                          dt = DateTime.parse(timestamp.toString());
                        } catch (_) {
                          continue;
                        }
                      }

                      String dateKey = _formatDate(dt);
                      if (!groupedLogs.containsKey(dateKey)) {
                        groupedLogs[dateKey] = [];
                      }
                      groupedLogs[dateKey]!.add(doc);
                    }

                    final keys = groupedLogs.keys.toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: keys.length,
                      itemBuilder: (context, index) {
                        final dateGroup = keys[index];
                        final groupDocs = groupedLogs[dateGroup]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Label Grup Tanggal ─────────────────────────────────────────
                            _dateGroupLabel(dateGroup),
                            const SizedBox(height: 10),

                            // ── List Log di Tanggal Terkait ──────────────────────────────
                            ...groupDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final type = data['type'] ?? 'telemetry';

                              final timestamp = data['timestamp'];
                              DateTime dt = DateTime.now();
                              if (timestamp is Timestamp) {
                                dt = timestamp.toDate();
                              } else if (timestamp != null) {
                                dt = DateTime.parse(timestamp.toString());
                              }
                              final timeStr = _formatTime(dt);

                              if (type == 'chat') {
                                return _chatLogCard(data, timeStr);
                              } else {
                                return _telemetryLogCard(data, timeStr);
                              }
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── WIDGET: Label Tanggal SCADA Style ──────────────────────────────────────
  Widget _dateGroupLabel(String dateText) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _neonBlue,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: _neonBlue.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dateText.toUpperCase(),
          style: TextStyle(
            color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: _dimText.withValues(alpha: 0.25),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  // ── WIDGET: Kartu Histori Chat AI ──────────────────────────────────────────
  Widget _chatLogCard(Map<String, dynamic> data, String timeStr) {
    final question = data['question'] ?? '';
    final answer   = data['answer'] ?? '';
    final emotion  = data['emotion'] ?? 'normal';
    final emotionColor = _getEmotionColor(emotion);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonBlue.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: _neonBlue.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.forum_rounded, color: _neonBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "INTERAKSI AI GEMINI",
                    style: TextStyle(
                      color: _dimText,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: TextStyle(
                  color: _dimText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pertanyaan User
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bgDeep,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: _dimText.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.record_voice_over_rounded, color: _neonBlue, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$question"',
                    style: TextStyle(
                      color: ThemeService.instance.isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Jawaban Gemini AI
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: emotionColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              border: Border.all(color: emotionColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.smart_toy_rounded, color: emotionColor, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer,
                    style: TextStyle(
                      color: emotionColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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

  // ── WIDGET: Kartu Histori Telemetri ────────────────────────────────────────
  Widget _telemetryLogCard(Map<String, dynamic> data, String timeStr) {
    final int distance = (data['distance'] ?? 0) as int;
    final int signal   = (data['signal'] ?? 0) as int;
    final String emotion = data['emotion'] ?? 'normal';
    final emotionColor = _getEmotionColor(emotion);

    // Kategori Sinyal
    String signalStatus = "Poor";
    if (signal >= -50) {
      signalStatus = "Excellent";
    } else if (signal >= -70) {
      signalStatus = "Good";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emotionColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          // Waktu
          Text(
            timeStr,
            style: TextStyle(
              color: _dimText,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 14),

          // Pembatas Vertikal
          Container(
            width: 1,
            height: 30,
            color: _dimText.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 14),

          // Wajah Robot Icon
          Icon(
            _getEmotionIcon(emotion),
            color: emotionColor,
            size: 24,
          ),
          const SizedBox(width: 12),

          // Detail Telemetri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "EMOSI: ${emotion.toUpperCase()}",
                      style: TextStyle(
                        color: emotionColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Jarak: ${distance}cm  •  Sinyal: ${signal}dBm ($signalStatus)",
                  style: TextStyle(
                    color: ThemeService.instance.isDark ? Colors.white70 : Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Radar Icon
          Icon(Icons.radar_rounded, color: _neonBlue.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }
}
