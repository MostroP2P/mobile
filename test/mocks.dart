import 'package:mockito/annotations.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';

@GenerateMocks([MostroService, MostroRepository, OpenOrdersRepository])
void main() {}
