import 'package:flutter_riverpod/flutter_riverpod.dart';

class DrawerNotifier extends StateNotifier<bool> {
  DrawerNotifier() : super(false);

  void openDrawer() => state = true;
  void closeDrawer() => state = false;
  void toggleDrawer() => state = !state;
}

final drawerProvider = StateNotifierProvider<DrawerNotifier, bool>((ref) {
  return DrawerNotifier();
});
