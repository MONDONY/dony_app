import 'package:dony/features/payments/cash/data/datasources/commission_method_remote_datasource.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';

class CommissionMethodRepository {
  final CommissionMethodRemoteDatasource _ds;

  CommissionMethodRepository(this._ds);

  Future<String> startSetup() => _ds.setup();
  Future<void> savePaymentMethod(String paymentMethodId) => _ds.save(paymentMethodId);
  Future<CommissionMethod?> load() => _ds.get();
  Future<void> remove() => _ds.delete();
}
