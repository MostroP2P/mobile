import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';
import 'package:mostro_mobile/data/models/session.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradesProvider);

    return tradesAsync.when(
      data: (sessions) {
        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: const MostroAppBar(),
          drawer: const MostroAppDrawer(),
          body: RefreshIndicator(
            onRefresh: () async {
              // Force a refresh of sessions
              ref.refresh(tradesProvider);
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.dark2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'My Trades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily:
                            GoogleFonts.robotoCondensed().fontFamily,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildOrderList(sessions),
                  ),
                  const BottomNavBar(),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppTheme.cream1),
          ),
        ),
      ),
    );
  }

  /// If your Session contains a full order snapshot, you could convert it.
  /// Otherwise, update TradesList to accept a List<Session>.
  Widget _buildOrderList(List<Session> sessions) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'No trades available for this type',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return TradesList(sessions: sessions);
  }
}
