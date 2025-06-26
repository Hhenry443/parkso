import 'package:flutter/material.dart';

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

  // This is where you will call the Stripe SDK
  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
    });

    // --- DUMMY PAYMENT LOGIC ---
    // In a real app, you would call Stripe.instance.presentPaymentSheet() here.
    // We will simulate a network delay.
    await Future.delayed(const Duration(seconds: 2));

    // --- DUMMY SUCCESS/FAILURE ---
    // Here you would check the result from Stripe. We'll just pretend it succeeded.
    final bool paymentSuccess = true;

    setState(() {
      _isProcessing = false;
    });

    if (paymentSuccess) {
      // Navigate to a success screen or show a success dialog
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Payment Successful'),
              content: Text(
                'Your payment of £${widget.totalPrice.toStringAsFixed(2)} was successful.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Pop the dialog and then pop the payment screen to go back to the map
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } else {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Payment'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Order Summary ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '£${widget.totalPrice.toStringAsFixed(2)}', // Formats the price to 2 decimal places
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Payment Form Placeholder ---
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.payment, size: 40, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  Text(
                    'The Stripe payment form will be presented when you click the button below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            const Spacer(), // Pushes the button to the bottom
            // --- Pay Now Button ---
            ElevatedButton.icon(
              icon:
                  _isProcessing
                      ? const SizedBox.shrink() // Don't show icon when loading
                      : const Icon(Icons.lock, color: Colors.white),
              label:
                  _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        'Pay £${widget.totalPrice.toStringAsFixed(2)} Securely',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
              onPressed:
                  _isProcessing
                      ? null
                      : _handlePayment, // Disable button when processing
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
