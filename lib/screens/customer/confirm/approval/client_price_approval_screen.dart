import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'client_price_approval_fields.dart';
part 'client_price_approval_helpers.dart';
part 'client_price_approval_actions.dart';
part 'client_price_approval_bill_section.dart';
part 'client_price_approval_materials_section.dart';
part 'client_price_approval_footer_section.dart';

class ClientPriceApprovalScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const ClientPriceApprovalScreen({
    super.key,
    required this.jobId,
    required this.job,
  });
  @override
  State<ClientPriceApprovalScreen> createState() =>
      _ClientPriceApprovalScreenState();
}

class _ClientPriceApprovalScreenState extends State<ClientPriceApprovalScreen>
    with
        FieldsMixin,
        HelpersMixin,
        ActionsMixin,
        BillSectionMixin,
        MaterialsSectionMixin,
        FooterSectionMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fundi Requests Change',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var job = snap.data!.data() as Map<String, dynamic>;
          var reneg = (job['renegotiation'] as Map<String, dynamic>?) ?? {};
          String renegStatus = (reneg['status'] ?? 'pending').toString();

          int oldLabor = _toInt(
            reneg['oldLabor'] ??
                reneg['oldPrice'] ??
                job['agreedPrice'] ??
                job['laborCost'] ??
                0,
          );
          int newLaborRaw = _toInt(
            reneg['newLaborTotal'] ?? reneg['newLaborPrice'] ?? 0,
          );
          if (newLaborRaw == 0)
            newLaborRaw = oldLabor + _toInt(reneg['extraLabor'] ?? 0);

          int acceptedCounterLabour = _toInt(
            reneg['acceptedCounterExtraLabor'] ??
                reneg['approvedExtra'] ??
                reneg['counterExtraLabor'] ??
                0,
          );
          int acceptedCounterToLock = _toInt(
            reneg['acceptedCounterExtraToLock'] ??
                reneg['approvedExtraToLock'] ??
                reneg['counterExtraToLock'] ??
                0,
          );
          bool isCounterAccepted =
              acceptedCounterLabour > 0 &&
              (renegStatus == 'approved' ||
                  renegStatus.contains('approved') ||
                  acceptedCounterToLock > 0);

          int newLabor = isCounterAccepted
              ? oldLabor + acceptedCounterLabour
              : newLaborRaw;
          int extraLabor = isCounterAccepted
              ? acceptedCounterLabour
              : (newLabor - oldLabor).clamp(0, 9999999);

          int oldTransport = _toInt(
            reneg['oldTransportFee'] ??
                widget.job['transportFee'] ??
                job['transportFee'] ??
                0,
          );
          int oldClientFee = (oldLabor * 0.05).round();
          int newClientFee = _toInt(
            reneg['newClientAppFee'] ?? (newLabor * 0.05).round(),
          );
          int extraAppFee = (newClientFee - oldClientFee).clamp(0, 999999);
          if (isCounterAccepted)
            extraAppFee = _toInt(
              reneg['acceptedCounterExtraAppFee'] ??
                  reneg['counterExtraAppFee'] ??
                  extraAppFee,
            );
          int alreadyLockedCorrect = oldLabor + oldTransport + oldClientFee;
          int extraToLock = extraLabor + extraAppFee;
          int newTotal = alreadyLockedCorrect + extraToLock;

          bool needsExtraEscrow =
              extraToLock > 0 &&
              (renegStatus.contains('pending_extra_escrow') ||
                  renegStatus == 'approved' ||
                  renegStatus == 'approved_pending_extra_escrow' ||
                  _toBool(job['clientNeedsToTopup']));

          List<String> reasons = List<String>.from(
            reneg['reasons'] ?? [reneg['reason'] ?? 'Extra work'],
          );
          String tillNumber = (reneg['tillNumber'] ?? '').toString();
          List<Map<String, dynamic>> partsNeeded =
              List<Map<String, dynamic>>.from(
                reneg['partsNeeded'] ?? reneg['parts'] ?? [],
              );
          List<String> evidence = List<String>.from(
            reneg['evidencePhotoUrls'] ?? [],
          );
          int partsEstimateTotal = _toInt(reneg['partsEstimateTotal']);
          int calc = 0;
          for (var p in partsNeeded)
            calc += _toInt(p['qty'], 1) * _toInt(p['estPrice']);
          if (partsEstimateTotal == 0) partsEstimateTotal = calc;

          bool isMaterialsOnly = extraLabor == 0 && partsNeeded.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMaterialsOnly)
                  buildMaterialsOnlySection(
                    partsNeeded,
                    partsEstimateTotal,
                    tillNumber,
                  )
                else
                  buildBillInfoSection(
                    newLabor,
                    oldLabor,
                    oldTransport,
                    alreadyLockedCorrect,
                    extraLabor,
                    extraAppFee,
                    extraToLock,
                  ),
                const SizedBox(height: 12),
                buildReasonsSection(reasons),
                const SizedBox(height: 12),
                if (!isMaterialsOnly && tillNumber.isNotEmpty)
                  buildTillBanner(tillNumber, partsEstimateTotal),
                if (!isMaterialsOnly && partsNeeded.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  buildMaterialsTableSection(partsNeeded, partsEstimateTotal),
                ],
                if (evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  buildEvidenceSection(evidence),
                ],
                const SizedBox(height: 20),
                if (needsExtraEscrow)
                  buildNeedsExtraEscrowSection(
                    job,
                    alreadyLockedCorrect,
                    extraToLock,
                    newTotal,
                    isCounterAccepted,
                    acceptedCounterLabour,
                    reneg,
                    extraLabor,
                  )
                else if (renegStatus == 'pending')
                  buildPendingActionsSection(
                    job,
                    newLabor,
                    extraLabor,
                    alreadyLockedCorrect,
                    oldTransport,
                    extraToLock,
                    newTotal,
                    partsNeeded,
                    isMaterialsOnly,
                    partsEstimateTotal,
                    tillNumber,
                    oldLabor,
                  )
                else
                  buildStatusDoneSection(renegStatus, newTotal),
              ],
            ),
          );
        },
      ),
    );
  }
}
