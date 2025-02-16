import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class OrderFilter extends StatelessWidget {
  const OrderFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cream1,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const HeroIcon(HeroIcons.funnel,
                      style: HeroIconStyle.outline, color: AppTheme.dark2),
                  SizedBox(width: 8),
                  Text(
                    'FILTER',
                    style: AppTheme.theme.textTheme.headlineSmall!.copyWith(
                      color: AppTheme.dark2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppTheme.dark2, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          SizedBox(height: 20),
          buildDropdownSection(context, 'Fiat currencies', []),
          buildDropdownSection(context, 'Payment methods', []),
          buildDropdownSection(context, 'Countries', []),
          buildDropdownSection(context, 'Rating', []),
        ],
      ),
    );
  }

  Widget buildDropdownSection(
      BuildContext context, String title, List<DropdownMenuItem<String>> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: title,
              labelStyle: const TextStyle(color: AppTheme.mostroGreen),
            ),
            dropdownColor: AppTheme.dark1,
            style: TextStyle(color: AppTheme.cream1),
            items: items,
            value: '', onChanged: (String? value) {  },
          ),
          SizedBox(height: 4),
        ],
      ),
    );
  }
}
