import 'package:mockito/annotations.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([MostroService, OpenOrdersRepository, SharedPreferencesAsync])
void main() {}
