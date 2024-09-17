import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORDER DETAILS'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfo(),
              const SizedBox(height: 20),
              _buildOrderInfo(),
              const SizedBox(height: 20),
              _buildYourOrder(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        const CircleAvatar(
          backgroundImage: AssetImage('assets/images/user_avatar.png'),
          radius: 30,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jack Footsey',
              style: AppTextStyles.bodyLarge.copyWith(fontSize: 18),
            ),
            Row(
              children: [
                Text('5/5', style: AppTextStyles.bodyMedium),
                const SizedBox(width: 8),
                Text('(42)', style: AppTextStyles.bodyMedium),
              ],
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            // Implementar lógica para leer reseñas
          },
          child: const Text('Read reviews',
              style: TextStyle(color: AppColors.mostroGreen)),
        ),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('6 000 MXN (+1%)',
              style: AppTextStyles.bodyLarge.copyWith(fontSize: 18)),
          Text('1 293 934 sats', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: AppColors.grey2, size: 16),
              const SizedBox(width: 8),
              Text('Revolut', style: AppTextStyles.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYourOrder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your order',
              style: AppTextStyles.bodyLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text('1 293 934 sats', style: AppTextStyles.bodyMedium),
          Text('\$ 609.73', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flash_on, color: AppColors.yellow, size: 16),
              const SizedBox(width: 8),
              Text('Bitcoin Lightning Network',
                  style: AppTextStyles.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'CANCEL',
            onPressed: () {
              // Implementar lógica para cancelar
            },
            isOutlined: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomButton(
            text: 'CONTINUE',
            onPressed: () {
              // Implementar lógica para continuar
            },
          ),
        ),
      ],
    );
  }
}
