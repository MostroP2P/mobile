import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class AddOrderButton extends StatefulWidget {
  const AddOrderButton({super.key});

  @override
  State<AddOrderButton> createState() => _AddOrderButtonState();
}

class _AddOrderButtonState extends State<AddOrderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_animationController.isAnimating) {
      return;
    }

    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _navigateToCreateOrder(BuildContext context, String type) {
    _toggleMenu();
    if (type == 'buy') {
      context.push('/add_order', extra: {'orderType': 'buy'});
    } else {
      context.push('/add_order', extra: {'orderType': 'sell'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isMenuOpen ? 45 : 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ElevatedButton.icon(
                        key: const Key('buyButton'),
                        onPressed: _isMenuOpen
                            ? () => _navigateToCreateOrder(context, 'buy')
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.buyColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const SizedBox(width: 16, height: 16),
                        label: Text(S.of(context)!.buy,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_isMenuOpen)
                        const Positioned(
                          left: 16,
                          child: Icon(Icons.arrow_downward,
                              size: 16, color: Colors.black),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ElevatedButton.icon(
                        key: const Key('sellButton'),
                        onPressed: _isMenuOpen
                            ? () => _navigateToCreateOrder(context, 'sell')
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.sellColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const SizedBox(width: 16, height: 16),
                        label: Text(S.of(context)!.sell,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_isMenuOpen)
                        const Positioned(
                          left: 16,
                          child: Icon(Icons.arrow_upward,
                              size: 16, color: Colors.black),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FloatingActionButton(
            key: const Key('addOrderButton'),
            onPressed: _toggleMenu,
            backgroundColor:
                _isMenuOpen ? Colors.grey.shade700 : AppTheme.activeColor,
            elevation: 6,
            shape: const CircleBorder(),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 0.785 * 2,
                  child: Icon(
                    _isMenuOpen ? Icons.close : Icons.add,
                    color: Colors.black,
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
