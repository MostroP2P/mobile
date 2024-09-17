import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'custom_button.dart';

class CustomTabBar extends StatelessWidget {
  final Function() onBuyPressed;
  final Function() onSellPressed;
  final bool isBuySelected;

  const CustomTabBar({
    super.key,
    required this.onBuyPressed,
    required this.onSellPressed,
    required this.isBuySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark2,
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              text: 'BUY BTC',
              onPressed: onBuyPressed,
              isOutlined: !isBuySelected,
            ),
          ),
          Expanded(
            child: CustomButton(
              text: 'SELL BTC',
              onPressed: onSellPressed,
              isOutlined: isBuySelected,
            ),
          ),
        ],
      ),
    );
  }
}
