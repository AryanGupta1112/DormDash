import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 for Clipboard & ClipboardData
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/payment_service.dart';
import '../services/order_service.dart';
import '../models/payment.dart';

class PaymentQrScreen extends ConsumerWidget {
  final String paymentId;
  final String orderId;
  final int amount;

  const PaymentQrScreen({
    super.key,
    required this.paymentId,
    required this.orderId,
    required this.amount,
  });

  Color _statusColor(String s, BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (s) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.redAccent;
      case 'expired':
        return Colors.orange;
      default:
        return cs.secondary;
    }
  }

  String? _extractParam(String deeplink, String key) {
    try {
      final uri = Uri.parse(deeplink);
      return uri.queryParameters[key];
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDeepLink(BuildContext context, String link) async {
    final uri = Uri.parse(link);
    final can = await canLaunchUrl(uri);
    final ok = can ? await launchUrl(uri, mode: LaunchMode.externalApplication) : false;
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found. You can scan the QR instead.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = PaymentService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via UPI'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '1) Open your UPI app using the button, or scan the QR.\n'
                        '2) Complete the payment in your UPI app.\n'
                        '3) Return to this screen; the status updates automatically.\n'
                        'Tip: If it doesn’t change immediately, tap “Check status”.',
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<PaymentIntent?>(
        stream: svc.watch(paymentId),
        builder: (context, snap) {
          final pi = snap.data;

          if (snap.connectionState == ConnectionState.waiting || pi == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Auto-handle success → mark order & go to tracking
          if (pi.status == 'success') {
            OrderService().markPaymentSuccess(orderId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              context.go('/track');
            });
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 10),
                  Text('Payment successful! Redirecting...',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final vpa = _extractParam(pi.upiDeepLink, 'pa') ?? 'campusbot@upi';
          final note = _extractParam(pi.upiDeepLink, 'tn') ?? 'Campus Order';
          final txnRef = _extractParam(pi.upiDeepLink, 'tr') ?? paymentId;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                // Header card with amount + status
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Amount to pay', style: Theme.of(context).textTheme.labelMedium),
                              Text('₹$amount',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(pi.status.toUpperCase()),
                          backgroundColor: _statusColor(pi.status, context).withOpacity(.12),
                          labelStyle: TextStyle(
                            color: _statusColor(pi.status, context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // QR
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: pi.upiDeepLink,
                        version: QrVersions.auto,
                        size: 240,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // VPA & Ref row
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Pay to (VPA)',
                          value: vpa,
                          onCopy: () => _copy(context, vpa),
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.numbers,
                          label: 'Reference',
                          value: txnRef,
                          onCopy: () => _copy(context, txnRef),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.note_outlined,
                            label: 'Note',
                            value: note,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openDeepLink(context, pi.upiDeepLink),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open UPI App'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        // No PaymentService.refresh(); just show a hint.
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Waiting for payment confirmation...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          // The StreamBuilder will auto-update when Firestore changes.
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check status'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Complete the payment in your UPI app. Return here; status updates automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black.withOpacity(.7)),
                ),

                if (pi.status == 'failed' || pi.status == 'expired') ...[
                  const SizedBox(height: 12),
                  Text(
                    pi.status == 'failed'
                        ? 'Payment failed. Please try again.'
                        : 'Payment link expired. Create a new payment.',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Clipboard.setData(ClipboardData(text: text)); // 👈 now resolved
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withOpacity(.75);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: onCopy,
          ),
      ],
    );
  }
}
