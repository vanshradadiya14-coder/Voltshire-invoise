# Builder CRM — v2.1: from CRUD app to working tool

**Date:** 10 August 2026
**Problem statement:** the app stores records correctly but does not help anyone
do a day's work. It reads as a demo because it *is* a demo — of a database.

---

## Part 1 — Why it feels like a demo

### The tell: every form is a dead end

`CustomerFormScreen._save()` ends like this:

```dart
await repo.create(Customer(...));   // returns the new id
showSnack(context, 'Customer added.');
context.pop();                      // ...and throws it away
```

The repository hands back the new document ID. The screen discards it and pops
to a list. The same pattern is in **all five** create forms:

| Screen | On save | What the builder actually wanted next |
|---|---|---|
| `customer_form_screen.dart` | `context.pop()` | Quote them. Or invoice them. |
| `job_form_screen.dart` | `context.pop()` | Add the photos. Price it. |
| `quote_form_screen.dart` | `context.pop()` | Send it to the customer. |
| `invoice_form_screen.dart` | `context.pop()` | Send it. Chase it. |
| `expense_form_screen.dart` | `context.pop()` | Snap the next receipt. |

Nobody creates a customer for the pleasure of having a customer. They create one
because they are about to quote, bill or book work. The app stops exactly where
the work starts.

### The second tell: entities don't know about each other

- Nothing links a **quote** to the **job** it became.
- Nothing links a **job** to the **invoices** raised against it.
- A completed job with no invoice is invisible except as one dashboard alert.
- `QuoteStatus.expired` exists as an enum value that **no code ever sets**.
- Photos, documents and expenses attach to a job but never surface on the
  invoice they justify.

### The third tell: it doesn't speak the trade

The app says "Customer", "Job", "Invoice". A UK builder says *client*,
*price work*, *day rate*, *variation*, *snagging*, *retention*, *CIS*,
*reverse charge*, *application for payment*. An app that doesn't know what
CIS is, is an app built by somebody who has never invoiced a main contractor.

### The fourth tell: everything is retyped

There is no saved price list. A builder puts "Labour — day rate" on ~200
invoices a year and types it 200 times, along with the rate, the unit and the
VAT. Every quoting tool that builders actually keep using has a price library.

---

## Part 2 — The spine

A builder's week is not five tabs. It is one pipeline:

```
   ENQUIRY → QUOTE → won? → JOB → work happens → INVOICE → PAID
                │                     │              │
              lost                variations      chased
                                  extra work      reminders
```

Every screen should answer one of three questions:

1. **What do I need to do next?** (the action centre, already built)
2. **Where is this piece of work up to?** (the job, as the spine)
3. **How do I move it one step forward?** (the continuation)

The change in this release is *(3)*: **nothing is allowed to dead-end.**

---

## Part 3 — Design decisions

### 3.1 Flow continuity — `SaveOutcome` and the next-step sheet

Every create form returns a typed outcome carrying the new ID, instead of
`void` + `pop()`:

```dart
class SaveOutcome {
  final EntityKind kind;   // customer | job | quote | invoice | expense
  final String id;
  final String label;      // "J. Smith", "INV-000042"
  final String? customerId;
  final String? jobId;
}
```

On save the app:

1. navigates to the **detail screen** for the thing just created — so the
   builder sees it exists, which is what builds trust in a money app;
2. presents a **next-step sheet** over it, offering the two or three things
   that actually follow.

Dismissing the sheet leaves them on a real screen with real actions, not back
at a list wondering whether it saved.

**Next steps by entity** — chosen from what follows in real life, not from
what is technically possible:

| Just created | Offered next |
|---|---|
| Customer | **Create invoice** · Create quote · Add job |
| Job | Add photos · Price it (quote) · **Invoice it** |
| Quote | **Send to customer** · Convert to job |
| Invoice | **Send to customer** · Record payment |
| Expense | Add another · Attach receipt |

The bolded action is primary. For **Customer**, "Create invoice" is primary
because that is what was explicitly asked for — and it is the right default:
a builder adding a client mid-job wants to bill them.

**Why a sheet rather than a "Save and…" split button:** a split button hides
its options behind a menu and only helps people who already know the flow. The
sheet *teaches* the pipeline to a first-time user, and costs one dismissal to
people who don't want it.

### 3.2 UK construction tax — the strongest "built for me" signal

Two things every UK builder deals with and no generic invoice app handles:

**CIS (Construction Industry Scheme).** When subcontracting to a main
contractor, the contractor deducts tax from the **labour element only** and
pays it to HMRC. Rates: **0%** (gross status), **20%** (registered),
**30%** (unregistered). Materials, plant and VAT are never deducted from.

This is only possible if line items know whether they are labour or materials —
so `LineItem` gains a **category**:

```
labour · materials · plant · subcontractor · other
```

Settlement maths becomes:

```
  labour net            (categorised lines, after discount, ex-VAT)
+ materials net
= subtotal
+ VAT                   (0 when reverse charge applies)
− CIS deduction         (labour net × rate)
= amount due
```

**VAT domestic reverse charge** (in force since 1 March 2021). Where both
parties are VAT-registered, the work is a CIS construction service, and the
customer is *not* the end user — the supplier charges **no VAT** and the
invoice must state that the customer accounts for it. The PDF must carry the
statutory wording:

> Reverse charge: VAT Act 1994 Section 55A applies.
> Customer to account for the VAT to HMRC.

...and still show the VAT amount the customer must account for.

**Where the settings live:** on the **customer**, not on each invoice. A
builder sets "Barratt — contractor, CIS 20%, reverse charge" once, and every
invoice to them is right forever. For a homeowner none of it appears anywhere
in the UI. That is the whole design: **invisible until relevant.**

```
Customer
  type: domestic | contractor
  cisStatus: notApplicable | gross(0%) | registered(20%) | unregistered(30%)
  reverseCharge: bool
  vatNumber, companyNumber, utr
```

### 3.3 Price list

`PriceItem`: description, unit (each / hour / day / m² / m / load), unit price,
category, VAT rate, optional default quantity.

Wired into the line-items editor as an "Add from price list" action, with
search and a most-used-first ordering. Adding an item to a document copies its
values — editing a saved price later never rewrites a historic invoice, which
would silently change what a customer was billed.

**Seeded on first run** with ~20 realistic UK trade defaults (day rate, labour
hourly, skip hire, plasterboard, mixed ballast, waste disposal, scaffold week)
so the library is useful before the builder has typed anything. Every seeded
item is editable and deletable.

### 3.4 Variations

"While you're here, could you also…" is how builders lose money — the work gets
done and never gets billed.

```
Variation { jobId, description, amount, category, status, approvedAt }
status: proposed → approved → invoiced   (or rejected)
```

Approved-but-not-yet-invoiced variations appear:
- on the **job** as a running "extras" total,
- as an **action centre alert** when the job completes,
- as **pre-filled line items** when raising the invoice for that job.

That last one is the point: the extra work flows onto the invoice by default
instead of being remembered or forgotten.

### 3.5 Deposits and payment stages

A payment schedule on a job:

```
PaymentStage { label, percent | fixed amount, dueOn, status, invoiceId? }
```

Presets that match how the trade actually bills:
- **50 / 50** — deposit and completion
- **40 / 30 / 30** — deposit, first fix, completion
- **25 / 25 / 25 / 25** — monthly on longer jobs
- Custom

Each stage raises an invoice in one tap, pre-filled with the stage amount and a
description referencing the job. The job shows invoiced-vs-total so it is
obvious what is still to bill.

### 3.6 Chasing payment

The single biggest cash-flow problem in UK construction. Three escalating
templates, each one tap from the invoice or the action centre:

| Stage | Tone | Content |
|---|---|---|
| **Reminder** | Friendly | "Just a nudge — invoice X is now due." |
| **Second notice** | Firm | Days overdue, restates the terms. |
| **Final notice** | Formal | References the **Late Payment of Commercial Debts (Interest) Act 1998** — statutory interest at 8% over base, plus the fixed compensation of £40/£70/£100 by debt size. |

Sent via the existing share service (SMS/email/WhatsApp — a builder chases on
whatever the customer answers on). Each send is recorded on the invoice so the
history is defensible if it ever goes to a county court claim.

Statutory late-payment entitlement only applies **business-to-business**, so
the final-notice template is offered for contractor customers and suppressed
for domestic ones. Getting that wrong would put a legally meaningless threat in
front of a homeowner.

### 3.7 Quick add

A single context-aware sheet from the FAB: New invoice · New quote · New job ·
New customer · Log expense · Record payment · Add photo. Two taps to anything
from anywhere, instead of navigating to the right tab first.

### 3.8 Empty states that teach

Current: *"No jobs — Create your first job to track work."*

Replacement: explain the pipeline position and offer the real next step. An
empty invoice list on an account that *has* completed jobs should say so and
offer to bill one — that is a live, useful prompt, not a placeholder.

---

## Part 4 — Execution order

Layers, because each depends on the one before:

**A. Domain** — `CustomerType`, `CisStatus`, `LineCategory`, `Settlement`
(the CIS/reverse-charge calculator), `PriceItem`, `Variation`, `PaymentStage`,
`ReminderStage`. Pure Dart, fully unit tested.

**B. Data** — repositories and providers for price items, variations and
payment stages; `Customer` and `LineItem` extended with back-compatible
`fromMap` defaults so existing documents keep working.

**C. Flow** — `SaveOutcome`, the next-step sheet, and all five create forms
rewired.

**D. Screens** — price list manager, variation editor, stage scheduler, chase
sheet, quick-add sheet.

**E. Integration** — line-items editor gains the price-list picker and category
selector; invoice form pulls in approved variations; customer form gains the
contractor block; invoice detail shows the settlement breakdown and chase
actions; PDF renders CIS and the reverse-charge declaration.

**F. Verification** — unit tests for every branch of the settlement maths, then
the full static pass.

## Part 5 — Backwards compatibility

Every existing Firestore document must keep working untouched:

- `Customer.type` defaults to `domestic` → no contractor UI, no behaviour change.
- `LineItem.category` defaults to `other` → excluded from CIS labour, so an
  un-categorised legacy invoice computes exactly as it does today.
- `Settlement` with no CIS and no reverse charge reduces to
  `subtotal + VAT = total`, which is the current behaviour.

No migration is required, and no historic invoice changes value.

## Deliberately not in this release

- **Snagging lists** — deserves its own model and photo flow; a half version is
  worse than none.
- **Timesheets / labour hours** — needs a worker concept, which needs the team
  seats from the Business tier.
- **Retention** — commonly 5% held for 12 months. It needs a release schedule
  and its own reminders; bolting it onto the invoice total would misreport
  outstanding balances.
- **Mileage** — trivial to add later as an expense category with a per-mile rate.
