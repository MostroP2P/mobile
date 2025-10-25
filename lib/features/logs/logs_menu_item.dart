import 'package:flutter/material.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'logs_screen.dart';

class LogsMenuItem extends StatelessWidget {
  const LogsMenuItem({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!; // <-- localización

    return ListTile(
      leading: const Icon(Icons.bug_report, color: Colors.orangeAccent),
      title: Text(s.logsMenuTitle, style: const TextStyle(color: Colors.white)),
      subtitle: Text(s.logsMenuSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogsScreen()),
        );
      },
    );
  }
}
