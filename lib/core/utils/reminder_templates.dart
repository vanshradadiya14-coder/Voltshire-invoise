import '../../models/company_profile.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/trade_enums.dart';
import 'formatters.dart';
import 'settlement.dart';

/// Pre-written chase messages for an overdue invoice.
///
/// Late payment is the single biggest cash-flow problem in UK construction, and
/// the reason builders don't chase is that writing the message is awkward. Three
/// escalating drafts remove that friction entirely.
///
/// **The final notice is business-to-business only.** Statutory interest under
/// the Late Payment of Commercial Debts (Interest) Act 1998 does not apply to
/// consumers, so quoting it at a homeowner would be a legally meaningless
/// threat. [ReminderTemplates.availableFor] enforces that.
class ReminderTemplates {
  const ReminderTemplates._();

  /// Which escalation levels may be offered for this customer.
  static List<ReminderStage> availableFor(Customer? customer) {
    final bool business = customer?.type.isBusiness ?? false;
    if (business) return ReminderStage.values;
    // Homeowners get the friendly and firm drafts only.
    return <ReminderStage>[ReminderStage.friendly, ReminderStage.firm];
  }

  /// Builds the message body.
  static String build({
    required ReminderStage stage,
    required Invoice invoice,
    required Customer? customer,
    required CompanyProfile? company,
  }) {
    final String symbol = company?.currencySymbol ?? '£';
    final String amount = Formatters.money(invoice.balanceDue, symbol: symbol);
    final String number = invoice.numberFormatted;
    final String from = company?.companyName.trim().isNotEmpty ?? false
        ? company!.companyName.trim()
        : 'us';
    final String greeting = _greeting(customer);
    final int days = invoice.daysOverdue;
    final String due = invoice.dueDate == null
        ? ''
        : Formatters.longDate(invoice.dueDate!);

    switch (stage) {
      case ReminderStage.friendly:
        return '''
$greeting

Just a quick reminder that invoice $number for $amount ${due.isEmpty ? 'is now due' : 'was due on $due'}.

If you've already sent it across, please ignore this — and thanks. If not, whenever you get a moment would be great.

${_bankBlock(company)}Many thanks,
$from''';

      case ReminderStage.firm:
        return '''
$greeting

Invoice $number for $amount is now $days ${days == 1 ? 'day' : 'days'} overdue.${due.isEmpty ? '' : ' It was due on $due.'}

Could you let me know when I can expect payment? If there's a problem with the invoice, tell me and I'll get it sorted.

${_bankBlock(company)}Thanks,
$from''';

      case ReminderStage.finalNotice:
        final LatePaymentClaim claim =
            LatePayment.claimFor(invoice.balanceDue, days);
        return '''
$greeting

FINAL NOTICE — invoice $number

This invoice for $amount is now $days days overdue.${due.isEmpty ? '' : ' Payment was due on $due.'} Despite previous reminders it remains unpaid.

Under the Late Payment of Commercial Debts (Interest) Act 1998 I am entitled to claim:

  • Statutory interest at ${claim.annualRatePercent.toStringAsFixed(0)}% per year — currently ${Formatters.money(claim.interest, symbol: symbol)}
  • Fixed compensation of ${Formatters.money(claim.compensation, symbol: symbol)}

  Total now claimable: ${Formatters.money(claim.total, symbol: symbol)}

Please settle the outstanding $amount within 7 days. If payment is not received I will pursue recovery of the full amount including interest and costs.

${_bankBlock(company)}Regards,
$from''';
    }
  }

  /// A short subject line for email.
  static String subject({
    required ReminderStage stage,
    required Invoice invoice,
  }) {
    return switch (stage) {
      ReminderStage.friendly =>
        'Reminder: invoice ${invoice.numberFormatted}',
      ReminderStage.firm =>
        'Overdue: invoice ${invoice.numberFormatted} '
            '(${invoice.daysOverdue} days)',
      ReminderStage.finalNotice =>
        'FINAL NOTICE: invoice ${invoice.numberFormatted}',
    };
  }

  static String _greeting(Customer? customer) {
    final String name = (customer?.contactName.trim().isNotEmpty ?? false)
        ? customer!.contactName.trim()
        : (customer?.name.trim() ?? '');
    if (name.isEmpty) return 'Hello,';
    // Use the first word only — "Hi Dave" reads better than "Hi Dave Wilson".
    return 'Hi ${name.split(' ').first},';
  }

  /// Repeats the bank details, so paying is one screen away rather than a hunt
  /// back through their email for the original invoice.
  static String _bankBlock(CompanyProfile? company) {
    if (company == null) return '';
    final List<String> lines = <String>[];
    if (company.accountName.trim().isNotEmpty) {
      lines.add('Account name: ${company.accountName}');
    }
    if (company.sortCode.trim().isNotEmpty) {
      lines.add('Sort code: ${company.sortCode}');
    }
    if (company.accountNumber.trim().isNotEmpty) {
      lines.add('Account number: ${company.accountNumber}');
    }
    if (lines.isEmpty) return '';
    return 'Payment details:\n${lines.join('\n')}\n\n';
  }
}
