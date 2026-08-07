# Builder CRM — v2.0 Upgrade Plan

**Audit date:** 7 August 2026
**Current state:** v1.0.0+1 · 85 Dart files · ~7,600 LOC · Flutter + Riverpod + Firebase
**Target state:** v2.0.0 — subscription-monetised, production-hardened, advanced analytics dashboard

---

## Part 1 — Audit of the current app

### What's genuinely good

The bones are solid and worth keeping. Do not rewrite these.

| Area | Assessment |
|---|---|
| Layer separation | Textbook. `core → models → services → repositories → providers → screens`. No layer violations found. |
| Money maths | `Calc` centralises rounding so editor, Firestore doc and PDF agree to the penny. This is the right call and rare to see. |
| Auto-numbering | `_reserveCounter` uses a Firestore transaction — concurrent invoice creation can't collide. Correct. |
| Ownership model | Every doc carries `ownerId`; rules enforce `ownsExisting()` / `ownsIncoming()`. Sound. |
| Derived status | `Invoice.status` is computed from `amountPaid`/`dueDate`, not stored-and-drifted. Right. |
| Routing | `StatefulShellRoute.indexedStack` with per-branch navigator keys and an auth+setup redirect guard. Correct pattern. |
| Offline | Firestore persistence on; global search filters in-memory over already-streamed lists, so it works offline. Clever. |

### What blocks "industrial standard"

Ordered by severity.

**S1 — Blocking release**

1. **Zero tests.** `flutter_test` is declared; no `test/` directory exists. The money maths — the highest-risk code in the app — is completely unverified.
2. **No crash reporting.** A production crash is invisible. No Crashlytics, no Sentry, no non-fatal reporting.
3. **No app icon or splash.** Ships with the default Flutter icon. `assets/images/` contains only a README.
4. **No release signing config.** CI builds an unsigned APK. Not shippable to Play.
5. **`firebase_options.dart` is 52 lines** — likely placeholder/partial. Android config (`google-services.json`) absent; only iOS plist is committed.

**S2 — Will hurt at scale**

6. **Every list streams the entire collection.** `_watchOwned()` fetches all invoices/jobs/customers, sorts client-side, and filters in Dart. `AppConstants.listPageSize = 25` exists but is never used. At 500 invoices this is a multi-MB read on every dashboard open, billed per document.
7. **The dashboard rebuilds on any write.** `dashboardStatsProvider` watches four full-collection streams and recomputes everything. One expense edit re-renders the whole dashboard.
8. **`firestore.indexes.json` defines 16 composite indexes that nothing uses** — commit `6630f47` moved sorting on-device but left the indexes. Dead config that misleads the next reader.
9. **No error boundary.** An exception in a repository surfaces as a red screen or a silent `AsyncValue.error` with no user-facing recovery.
10. **Hand-rolled `fromMap`/`toMap`/`copyWith` on 11 models.** ~1,100 lines of boilerplate; a typo in a field name fails silently at runtime.

**S3 — Product gaps**

11. **No monetisation whatsoever.** No billing, no tiers, no entitlement checks, no paywall.
12. **Dashboard is six static tiles and two lists.** No charts, no time period selection, no trends, no comparisons, no actionable alerts.
13. **Reports uses hand-drawn `Container` bars.** Functional, but not a charting library — no axes, no tooltips, no legend, can't show two series.
14. **No data export.** A business owner cannot get their data out. This is a trust and lock-in problem, and in the UK also a GDPR portability question.
15. **No soft-delete.** `delete()` is permanent everywhere. One mis-tap destroys an invoice.
16. **No app lock.** Financial data, no biometric gate.
17. **Hardcoded English strings** throughout — no `flutter_localizations`, no ARB files.
18. **No recurring invoices, no payment reminders, no quote-expiry handling** despite `QuoteStatus.expired` existing as a value nothing ever sets.

---

## Part 2 — Design decisions

### Subscription: RevenueCat behind an interface

```
UI (paywall, gates)
      ↓
EntitlementProvider ── reads ──> SubscriptionState
      ↓
BillingService  «abstract»
   ├── RevenueCatBillingService   (production)
   └── MockBillingService         (tests, local dev, CI)
```

Why the abstraction rather than calling `purchases_flutter` directly: it keeps every widget test runnable without a store connection, lets the app boot and function before store products are configured, and means swapping providers later touches one file.

RevenueCat handles receipt validation, entitlement state, grace periods, billing retry, and cross-platform restore — all of which are weeks of Cloud Functions work to do correctly by hand.

**Entitlement is cached to Firestore** (`subscriptions/{uid}`) so the app knows the tier while offline and at cold start before the SDK finishes its network call. RevenueCat remains the source of truth; Firestore is a read-through cache.

### Tiers

| | **Free** | **Pro** — £9.99/mo · £99/yr | **Business** — £24.99/mo · £249/yr |
|---|---|---|---|
| Customers | 5 | Unlimited | Unlimited |
| Jobs | 5 | Unlimited | Unlimited |
| Invoices + quotes | 5 total | Unlimited | Unlimited |
| PDF | Watermarked | Clean, own logo | Full custom branding |
| Dashboard | Basic tiles | Advanced + charts | Advanced + forecasting |
| Reports | — | Full | Full + P&L export |
| Data export | — | CSV | CSV + accounting formats |
| Job photos | 10 total | Unlimited | Unlimited |
| Documents | — | Unlimited | Unlimited |
| Recurring invoices | — | — | Yes |
| Payment reminders | — | Manual | Automatic |
| Team seats | 1 | 1 | 5 |

14-day Pro trial on first launch — no card required, handled as a RevenueCat introductory offer.

**Gate placement principle:** never block *reading* data the user already created. If someone downgrades with 40 customers, all 40 stay visible and editable; only *creating the 41st* is blocked. Locking people out of their own records is how apps earn one-star reviews.

### Dashboard architecture

The current provider recomputes six numbers from four full collections on every frame. Replacing it with:

```
dashboardPeriodProvider      StateProvider<DashboardPeriod>   today/week/month/quarter/year/custom
        ↓
dashboardMetricsProvider     computes current + previous window, emits deltas
        ↓
├── revenueSeriesProvider    time-bucketed revenue vs expenses  → line chart
├── cashFlowSeriesProvider   money in vs out per bucket         → grouped bars
├── expenseBreakdownProvider by category                        → donut
├── jobPipelineProvider      count + value per JobStatus        → funnel
└── actionCentreProvider     overdue / expiring / uninvoiced    → alert cards
```

Each is a separate provider so a chart only rebuilds when its own slice changes. Metrics are computed once per period change, not per widget.

**Action centre** surfaces work, not just numbers:
- Invoices overdue → total at risk, one-tap "send reminder"
- Quotes expiring within 7 days → one-tap "follow up"
- Completed jobs with no invoice → one-tap "create invoice"
- Quotes accepted but no job created → one-tap "start job"

**Customisable layout** stores an ordered list of section IDs plus visibility flags in `SharedPreferences` (device-local — layout preference doesn't need to sync and doesn't warrant a Firestore write). Reorder via `ReorderableListView` in an edit mode, not always-on drag, so normal scrolling stays unambiguous.

---

## Part 3 — Execution phases

### Phase 1 — Foundation
- Dependencies: `fl_chart`, `purchases_flutter`, `firebase_crashlytics`, `firebase_analytics`, `flutter_launcher_icons`, `flutter_native_splash`, `local_auth`, `csv`, `flutter_animate`, `shimmer`
- Design tokens: spacing scale, radius scale, elevation, semantic colour roles, typography ramp
- Theme v2: refined surfaces, consistent card treatment, tuned dark mode
- App icon + adaptive icon + splash generated from the supplied logo
- Version → `2.0.0+2`

### Phase 2 — Subscription layer
- `models/subscription.dart` — `SubscriptionTier`, `SubscriptionStatus`, `Entitlements`, `UsageLimits`
- `services/billing_service.dart` — abstract interface
- `services/revenuecat_billing_service.dart` + `services/mock_billing_service.dart`
- `repositories/subscription_repository.dart` — Firestore entitlement cache
- `providers/subscription_providers.dart` — `entitlementsProvider`, `usageProvider`, `canCreateProvider(entity)`
- `screens/subscription/paywall_screen.dart` — tier comparison, annual/monthly toggle, purchase, restore
- `screens/subscription/manage_subscription_screen.dart`
- `widgets/upgrade_prompt.dart`, `widgets/pro_badge.dart`, `widgets/usage_meter.dart`
- Enforcement at every create path: customers, jobs, invoices, quotes, photos, documents
- PDF watermark on Free tier

### Phase 3 — Advanced dashboard
- `models/dashboard_period.dart`, `models/dashboard_metrics.dart`, `models/dashboard_layout.dart`
- `providers/dashboard_v2_provider.dart` — the five providers above
- `widgets/charts/` — `revenue_chart.dart`, `cash_flow_chart.dart`, `expense_donut.dart`, `pipeline_funnel.dart`, `sparkline.dart`
- `widgets/dashboard/` — `metric_tile.dart` (with delta indicator), `action_card.dart`, `period_selector.dart`, `section_header_v2.dart`
- `screens/dashboard/dashboard_screen.dart` — rebuilt
- `screens/dashboard/customize_dashboard_screen.dart`
- Reports screen upgraded to real charts

### Phase 4 — Hardening
- Crashlytics + Analytics init, `FlutterError.onError`, `PlatformDispatcher.onError`, zone guard
- `core/errors/error_boundary.dart` + `AsyncValueView` upgraded with retry
- `core/telemetry/analytics_service.dart` — typed event names, no string literals at call sites
- Offline write-queue banner via connectivity + pending-write count
- Soft delete: `deletedAt` field, filtered from queries, restore from a trash screen
- CSV export of every collection, shared via `share_plus`
- Biometric app lock with `local_auth`, opt-in in Settings
- Firestore rules v2: field type validation, `ownerId` immutability, size caps
- `firestore.indexes.json` pruned to what is actually queried
- Release signing config + ProGuard rules

### Phase 5 — Tests + CI
- `test/unit/` — calculations (the critical one), models round-trip, entitlement gating, dashboard aggregation, period maths
- `test/widget/` — paywall, dashboard, invoice form, line-item editor
- `.github/workflows/ci.yml` — `dart analyze` + `flutter test` on push and PR
- Existing `build-apk.yml` gated behind CI passing

---

## Part 4 — Risks and how they're handled

| Risk | Mitigation |
|---|---|
| RevenueCat API key absent at build time | `MockBillingService` is the fallback; app boots and grants Free tier. Never crashes on missing config. |
| User downgrades while over the limit | Read/edit always allowed; only creation gated. No data is ever hidden or deleted. |
| Entitlement check races app start | Firestore cache read is synchronous-ish and returns last known tier; SDK reconciles after. Default is Free, never Pro — fail closed. |
| Full-collection streams still costly | Phase 3 providers compute over already-cached lists; pagination is scoped as a follow-up (see below), not silently skipped. |
| Charts on empty data | Every chart has an explicit empty state; no division by zero, no `NaN` in axis ranges. |
| Store products not yet created | Paywall reads offerings dynamically and shows a clear "not available" state rather than an empty screen. |

## Deliberately deferred

Named so they're decisions rather than oversights:

- **Cursor pagination** on list screens — needs Firestore indexes restored and a scroll-controller refactor per screen. Worth doing at ~500 documents; unnecessary below that.
- **`freezed`/`json_serializable`** for models — would delete ~1,100 lines of boilerplate but touches all 11 models and requires build_runner in CI. High value, high churn; better as its own focused change.
- **Localization** — string extraction across 45 screens. Do it when a second market is real.
- **Multi-user / team seats** — Business tier advertises it; enforcement needs a `members` sub-collection and a rules rewrite. Ship the tier, implement seats in 2.1.
- **Cloud Functions** for automatic payment reminders — needs a Blaze plan. Manual reminders ship now.
