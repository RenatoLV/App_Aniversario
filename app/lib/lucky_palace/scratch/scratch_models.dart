import '../data/lucky_models.dart';
import 'scratch_catalog.dart';
import 'scratch_engine.dart';
import 'scratch_mask.dart';

class ScratchReceipt {
  ScratchReceipt(
    Map<String, dynamic> data, {
    ScratchMask? mask,
    this.revealed = false,
  }) : data = Map.unmodifiable(data),
       mask = mask ?? ScratchMask() {
    if (data['rules'] != ScratchRules.version ||
        data['origin'] != 'local' ||
        data['id'] is! String ||
        data['cost'] != ScratchRules.cost) {
      throw const FormatException('Recibo de raspe incompatible');
    }
    ScratchTheme.byId(data['themeId']);
    outcome = ScratchOutcome(List<int>.from(data['cells']));
    if (outcome.gross != data['gross'] ||
        data['net'] != outcome.gross - ScratchRules.cost ||
        luckyInt(data['balance']) < 0 ||
        data['balance'] != luckyInt(data['balanceBefore']) + data['net']) {
      throw const FormatException('Recibo de raspe inconsistente');
    }
  }
  final Map<String, dynamic> data;
  final ScratchMask mask;
  final bool revealed;
  late final ScratchOutcome outcome;
  String get id => data['id'];
  ScratchTheme get theme => ScratchTheme.byId(data['themeId']);
  int get cost => data['cost'];
  int get gross => data['gross'];
  int get net => data['net'];
  int get balance => data['balance'];
}
