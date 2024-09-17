import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';

class OrderPaymentScreen extends StatefulWidget {
  const OrderPaymentScreen({super.key});

  @override
  _OrderPaymentScreenState createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen> {
  // Enumeración para los diferentes estados de pago
  enum PaymentState { initial, qrCode, paymentReceived, chatInitiated }

  PaymentState _currentState = PaymentState.initial;
  
  // Datos hardcodeados para el ejemplo
  final String _invoiceData = "lnbc1500n1ps36h3upp5h22hzfdphsswc4kku97zzn4qzx5jvfqa7h0lxf4uxcnwf9ncxarsdqqcqzpgxqyz5vqsp5usw3txnx8wut7mrmhc40rgdu9gzypz9ppcas3ugwwlvzu4vgnyuq9qyyssqgz5v4ndztc706lhjpznddhpj9nu4chd0l87d2g5h6sxln7u990h8l6lkuznmxws7vksytvsxaqrjqmqh8x89fmq98jqmtl4ssgpmeazlg";
  final int _satoshisAmount = 1293934;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PAYMENT'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case PaymentState.initial:
        return _buildInitialState();
      case PaymentState.qrCode:
        return _buildQRCodeState();
      case PaymentState.paymentReceived:
        return _buildPaymentReceivedState();
      case PaymentState.chatInitiated:
        return _buildChatInitiatedState();
    }
  }

  Widget _buildInitialState() {
    return Center(
      child: CustomButton(
        text: 'Show QR Code',
        onPressed: () {
          setState(() {
            _currentState = PaymentState.qrCode;
          });
        },
      ),
    );
  }

  Widget _buildQRCodeState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Pay this invoice to continue the exchange',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          QrImage(
            data: _invoiceData,
            version: QrVersions.auto,
            size: 200.0,
            foregroundColor: AppColors.mostroGreen,
          ),
          const SizedBox(height: 20),
          Text(
            'Expires in: 14:59s',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'OPEN WALLET',
            onPressed: () {
              // Implementar lógica para abrir la wallet
            },
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'CANCEL',
            onPressed: () {
              Navigator.pop(context);
            },
            isOutlined: true,
          ),
          const SizedBox(height: 20),
          // Simular recepción de pago después de 5 segundos
          CustomButton(
            text: 'Simulate Payment Received',
            onPressed: () {
              Future.delayed(const Duration(seconds: 5), () {
                setState(() {
                  _currentState = PaymentState.paymentReceived;
                });
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentReceivedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.mostroGreen,
            size: 100,
          ),
          const SizedBox(height: 20),
          Text(
            '$_satoshisAmount satoshis\nreceived',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'CONTINUE',
            onPressed: () {
              setState(() {
                _currentState = PaymentState.chatInitiated;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatInitiatedState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mostro (automatic)',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            '$_satoshisAmount satoshis were deposited and are held securely until your trading partner makes the fiat transfer.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'Please provide your fiat account information.',
            style: AppTextStyles.bodyMedium,
          ),
          const Spacer(),
          const TextField(
            decoration: InputDecoration(
              hintText: 'Type your message...',
              suffixIcon: Icon(Icons.send, color: AppColors.mostroGreen),
            ),
          ),
        ],
      ),
    );
  }
}