// lib/widgets/upi_qr_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UpiQrSheet extends StatelessWidget {
  final String upiUri;
  final int amount;
  const UpiQrSheet({super.key, required this.upiUri, required this.amount});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan to Pay (UPI)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 220,
              gapless: true,
            ),
            const SizedBox(height: 8),
            Text('Amount: ₹$amount'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: upiUri));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI link copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: upiUri));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI link copied. Open your UPI app and paste in “Pay by UPI ID/QR”.')));
                      }
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Open UPI'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'After paying, tap “I have paid” so the runner/vendor can confirm.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
