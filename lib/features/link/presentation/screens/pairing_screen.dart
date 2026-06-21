import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/pairing_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Lets the user pair this device with another by scanning a QR code
/// (mobile) or displaying one (desktop / the device being scanned).
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _pairingService = PairingService();
  String? _qrData;
  bool _scanMode = Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    final keyPair = await _pairingService.generateKeyPair();
    final pkBase64 = await _pairingService.publicKeyToBase64(keyPair);
    final payload = PairingPayload(
      deviceId: const Uuid().v4(),
      deviceName: Platform.localHostname,
      ip: '0.0.0.0', // populated from NetworkInfo in a full build
      port: 7531,
      publicKeyBase64: pkBase64,
    );
    setState(() => _qrData = payload.toQrData());
  }

  void _onScan(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    final remote = PairingPayload.fromQrData(code);
    // Hand off to NearLinkSession.connect(...) with remote.ip/port/publicKeyBase64.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Paired with ${remote.deviceName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NearLink Pairing'),
        actions: [
          IconButton(
            icon: Icon(_scanMode ? Icons.qr_code_rounded : Icons.qr_code_scanner_rounded),
            onPressed: () => setState(() => _scanMode = !_scanMode),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: _scanMode
              ? SizedBox(
                  width: 320,
                  height: 320,
                  child: MobileScanner(onDetect: _onScan),
                )
              : _qrData == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: QrImageView(
                        data: _qrData!,
                        size: 240,
                        backgroundColor: Colors.white,
                      ),
                    ),
        ),
      ),
    );
  }
}
