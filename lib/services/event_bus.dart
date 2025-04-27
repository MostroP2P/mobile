import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'event_bus.g.dart';

class EventBus {
  final _controller = StreamController<MostroMessage>.broadcast();

  Stream<MostroMessage> get stream => _controller.stream;

  void emit(MostroMessage message) => _controller.add(message);

  void dispose() => _controller.close();
}

@riverpod
EventBus eventBus(Ref ref) {
  final bus = EventBus();
 // ref.onDispose(bus.dispose);
  return bus;
}
