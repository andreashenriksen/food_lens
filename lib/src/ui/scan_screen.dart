import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../data/diary_repository.dart';
import '../data/kassal_api.dart';
import '../models/product.dart';
import 'settings_screen.dart';

/// Live barcode scanning. Pops the resolved [Product] back to the caller.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// Restricted to the retail formats printed on grocery packaging. Narrowing
  /// the set makes detection noticeably faster and avoids picking up QR codes.
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _busy = false;
  String? _status;
  String? _lastFailedEan;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null || raw == _lastFailedEan) return;

    setState(() {
      _busy = true;
      _status = 'Slår opp $raw…';
    });

    final api = context.read<KassalApi>();
    final diary = context.read<DiaryRepository>();

    try {
      var product = await api.productByEan(raw);
      // Fall back to a previously scanned copy so a poor signal in the shop
      // does not block logging something already known.
      product ??= await diary.cachedProductByEan(raw);

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _busy = false;
          _lastFailedEan = raw;
          _status =
              'Fant ikke $raw i Kassalapp. Prøv søk, eller legg inn manuelt.';
        });
        return;
      }

      Navigator.of(context).pop(product);
    } on KassalException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastFailedEan = raw;
        _status = e.message;
      });
      if (e.isAuthFailure) _promptForKey();
    }
  }

  void _promptForKey() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skann strekkode'),
        actions: [
          IconButton(
            tooltip: 'Lommelykt',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Bytt kamera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          const _ScanReticle(),
          if (_busy)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_status != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Material(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.inverseSurface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _status!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                          ),
                        ),
                      ),
                      if (_lastFailedEan != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _status = null;
                            _lastFailedEan = null;
                          }),
                          child: const Text('Prøv igjen'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A framing guide, so the user knows where to hold the barcode.
class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Food Lens trenger tilgang til kameraet for å skanne strekkoder. '
            'Gi tilgang i systeminnstillingene.',
      MobileScannerErrorCode.unsupported =>
        'Denne enheten støtter ikke skanning. Bruk søk i stedet.',
      _ => 'Kunne ikke starte kameraet: ${error.errorDetails?.message ?? ''}',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
