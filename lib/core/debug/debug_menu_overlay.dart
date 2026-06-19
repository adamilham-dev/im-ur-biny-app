import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Overlay yang menampilkan tombol debug melayang di pojok kanan atas.
/// Klik untuk membuka panel navigasi cepat ke setiap screen.
/// Hanya muncul di debug mode (`kDebugMode`).
///
/// Cara pakai: bungkus `child` di `MaterialApp.router(builder: ...)`
/// dan pass instance `GoRouter` agar navigasi tidak bergantung pada
/// context lookup (context di level ini berada di atas Router sehingga
/// `GoRouter.of(context)` tidak akan menemukan instance).
class DebugMenuOverlay extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const DebugMenuOverlay({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<DebugMenuOverlay> createState() => _DebugMenuOverlayState();
}

class _DebugMenuOverlayState extends State<DebugMenuOverlay> {
  bool _menuOpen = false;

  void _toggleMenu() {
    debugPrint('[DebugMenu] FAB tapped, menuOpen=${!_menuOpen}');
    setState(() => _menuOpen = !_menuOpen);
  }

  void _closeMenu() {
    if (_menuOpen) setState(() => _menuOpen = false);
  }

  void _navigate(String path) {
    debugPrint('[DebugMenu] Navigating to $path');
    setState(() => _menuOpen = false);
    widget.router.go(path);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    return Stack(
      children: [
        widget.child,
        // FAB toggle
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: FloatingActionButton.small(
              heroTag: 'debug_menu_fab',
              backgroundColor:
                  _menuOpen ? Colors.grey.shade800 : Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: _toggleMenu,
              child: Icon(
                _menuOpen ? Icons.close_rounded : Icons.bug_report_rounded,
                size: 20,
              ),
            ),
          ),
        ),
        // Panel (rendered on top of everything when open)
        if (_menuOpen)
          _DebugMenuPanel(
            onClose: _closeMenu,
            onNavigate: _navigate,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Panel — di-render sebagai child dari Stack utama (bukan OverlayEntry)
// agar tidak ada lifecycle error saat rebuild / navigate.
// ─────────────────────────────────────────────────────────────────────

class _DebugMenuPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String path) onNavigate;

  const _DebugMenuPanel({
    required this.onClose,
    required this.onNavigate,
  });

  static const _groups = <_DebugGroup>[
    _DebugGroup(title: 'Pembuka', routes: [
      _Route('01 · Idle', '/'),
      _Route('02 · Welcome', '/welcome'),
      _Route('03 · Onboarding', '/onboarding'),
    ]),
    _DebugGroup(title: 'Mode & Kategori', routes: [
      _Route('04 · Mode Select', '/mode-select'),
      _Route('05 · Category Select', '/category-select'),
    ]),
    _DebugGroup(title: 'Kamera & Pemindaian', routes: [
      _Route('06 · Camera Guide', '/camera-guide'),
      _Route('06b · Countdown', '/countdown'),
      _Route('07 · Scanning', '/scanning'),
    ]),
    _DebugGroup(title: 'Hasil Deteksi', routes: [
      _Route('08 · Result', '/result'),
      _Route('09 · Multi-Result', '/multi-result'),
      _Route('11 · Unknown Detected', '/unknown-detected'),
      _Route('12 · Analyzing', '/analyzing'),
      _Route('21 · Low Confidence', '/low-confidence'),
    ]),
    _DebugGroup(title: 'Conclusion & Dataset', routes: [
      _Route('13 · Conclusion New', '/conclusion-new'),
      _Route('14 · Conclusion Existing', '/conclusion-existing'),
      _Route('15 · Dataset Saved', '/dataset-saved'),
    ]),
    _DebugGroup(title: 'Akhir Sesi', routes: [
      _Route('17 · Thank You', '/thank-you'),
      _Route('Feedback', '/feedback'),
      _Route('18 · Manual Correction', '/manual-correction'),
    ]),
    // Hidden — already tidak dipakai lagi di flow app:
    // - 16 Continue Session (sekarang langsung ke Feedback → Thank You)
    // - Edge Case: 19 Out of Frame, 20 Too Large
    // - Mixed Waste: 23-26
  ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 56,
                right: 12,
                left: 12,
                bottom: 24,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: mq.size.height - 80,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bug_report_rounded,
                              color: Colors.red.shade700, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Debug Navigator',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 22),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Flexible(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children:
                              _groups.map((g) => _buildGroup(g)).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(_DebugGroup g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              g.title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: g.routes
                .map((r) => ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => onNavigate(r.path),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────

class _Route {
  final String label;
  final String path;
  const _Route(this.label, this.path);
}

class _DebugGroup {
  final String title;
  final List<_Route> routes;
  const _DebugGroup({required this.title, required this.routes});
}
