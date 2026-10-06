part of 'client_price_approval_screen.dart';

mixin FieldsMixin on State<ClientPriceApprovalScreen> {
  final counterPriceCtrl = TextEditingController();
  final counterReasonCtrl = TextEditingController();
  bool loading = false;
  String whoBuys = 'client';
}
