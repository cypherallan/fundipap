part of 'client_price_approval_screen.dart';

mixin BillSectionMixin on State<ClientPriceApprovalScreen> {
  Widget buildBillInfoSection(
    int newLabor,
    int oldLabor,
    int oldTransport,
    int alreadyLockedCorrect,
    int extraLabor,
    int extraAppFee,
    int extraToLock,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fundi visited site - new labour KES $newLabor (was $oldLabor). Transport KES $oldTransport unchanged.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Already locked:',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  Text(
                    'KES $alreadyLockedCorrect',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Old Labour:', style: GoogleFonts.inter(fontSize: 11)),
                  Text('KES $oldLabor', style: GoogleFonts.inter(fontSize: 11)),
                ],
              ),
              if (oldTransport > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Transport:', style: GoogleFonts.inter(fontSize: 11)),
                    Text(
                      'KES $oldTransport',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Extra Labour Requested:',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  Text(
                    'KES $extraLabor',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New App Maintenance Cost (5%):',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                  Text(
                    'KES $extraAppFee',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Extra to lock now:',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'KES $extraToLock',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildReasonsSection(List<String> reasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reasons',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: reasons
              .map(
                (r) => Chip(
                  label: Text(r, style: GoogleFonts.inter(fontSize: 10)),
                  backgroundColor: FundipapColors.primaryYellow.withOpacity(
                    0.3,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget buildTillBanner(String tillNumber, int partsEstimateTotal) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            'Shop Till: $tillNumber',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            'KES $partsEstimateTotal direct to shop',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }
}
