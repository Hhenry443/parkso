import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

class PaymentScreen extends StatefulWidget {
  final String stripeClientSecret;
  final double totalPrice;

  const PaymentScreen({
    super.key,
    required this.stripeClientSecret,
    required this.totalPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _isSheetInitialized = false;

  @override
  void initState() {
    super.initState();
    // Immediately initialize the payment sheet when the screen loads
    _initPaymentSheet();
  }

  // Step 1: Initialize the Payment Sheet
  Future<void> _initPaymentSheet() async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: widget.stripeClientSecret,
          merchantDisplayName: 'Parkso',
          style: ThemeMode.system,
        ),
      );
      setState(() {
        _isSheetInitialized = true;
      });
    } catch (e, stacktrace) {
      // Catch the exception and stacktrace
      // --- FIX: PRINT THE FULL ERROR TO THE CONSOLE ---
      print('Error initializing payment sheet: $e');
      print('Stacktrace: $stacktrace');
      // --- END FIX ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing payment sheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Step 2: Present the Payment Sheet and Handle the Result
  Future<void> _handlePayment() async {
    if (!_isSheetInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment sheet is not ready yet.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await Stripe.instance.presentPaymentSheet();
      setState(() {
        _isProcessing = false;
      });
      _showSuccessDialog();
    } on Exception catch (e, stacktrace) {
      // Catch the exception and stacktrace
      print('Error handling payment: $e');
      print('Stacktrace: $stacktrace');

      if (e is StripeException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment failed: ${e.error.localizedMessage ?? e.error.code}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Payment Successful'),
            content: Text(
              'Your payment of £${(widget.totalPrice / 100).toStringAsFixed(2)} was successful.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Total Amount to Pay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '£${(widget.totalPrice / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  _isProcessing || !_isSheetInitialized ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child:
                  _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Pay Now', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
