import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user.dart';
import '../providers/auth_providers.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/customers/customer_form_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/expenses/expense_form_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/invoices/invoice_detail_screen.dart';
import '../screens/invoices/invoice_form_screen.dart';
import '../screens/invoices/invoices_screen.dart';
import '../screens/jobs/job_detail_screen.dart';
import '../screens/jobs/job_form_screen.dart';
import '../screens/jobs/job_photos_screen.dart';
import '../screens/jobs/jobs_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/payments/payments_screen.dart';
import '../screens/quotes/quote_detail_screen.dart';
import '../screens/quotes/quote_form_screen.dart';
import '../screens/quotes/quotes_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/setup/business_setup_wizard.dart';
import 'app_routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _dashboardKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _customersKey = GlobalKey<NavigatorState>(debugLabel: 'customers');
final _jobsKey = GlobalKey<NavigatorState>(debugLabel: 'jobs');
final _invoicesKey = GlobalKey<NavigatorState>(debugLabel: 'invoices');
final _moreKey = GlobalKey<NavigatorState>(debugLabel: 'more');

/// Bridges Riverpod auth state to go_router: refreshes the router whenever the
/// signed-in user or their company-profile status changes, and computes the
/// redirect for guarded routes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
    _ref.listen<AsyncValue<AppUser?>>(
      appUserProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final AsyncValue<User?> auth = _ref.read(authStateProvider);
    // While the very first auth check is in flight, don't bounce the user.
    if (auth.isLoading) return null;

    final bool loggedIn = auth.valueOrNull != null;
    final String loc = state.matchedLocation;
    const Set<String> authRoutes = <String>{
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
    };

    if (!loggedIn) {
      return authRoutes.contains(loc) ? null : Routes.login;
    }

    // Signed in — has the Business Setup Wizard been completed?
    final AppUser? appUser = _ref.read(appUserProvider).valueOrNull;
    final bool needsSetup = appUser != null && !appUser.hasCompanyProfile;
    if (needsSetup) {
      return loc == Routes.setup ? null : Routes.setup;
    }

    // Fully onboarded — keep the user out of the auth/onboarding screens.
    if (authRoutes.contains(loc) || loc == Routes.setup) {
      return Routes.dashboard;
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final _RouterNotifier notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.dashboard,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: <RouteBase>[
      // ---- Auth & onboarding (full screen, root navigator) ----
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.setup,
        builder: (_, __) => const BusinessSetupWizard(),
      ),

      // ---- Main app: bottom-nav shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // Dashboard
          StatefulShellBranch(
            navigatorKey: _dashboardKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.dashboard,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),

          // Customers (+ detail/form on root navigator)
          StatefulShellBranch(
            navigatorKey: _customersKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.customers,
                builder: (_, __) => const CustomersScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, __) => const CustomerFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) =>
                        CustomerDetailScreen(customerId: s.pathParameters['id']!),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) =>
                            CustomerFormScreen(customerId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Jobs
          StatefulShellBranch(
            navigatorKey: _jobsKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.jobs,
                builder: (_, __) => const JobsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => JobFormScreen(
                      customerId: s.uri.queryParameters['customerId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => JobDetailScreen(jobId: s.pathParameters['id']!),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) =>
                            JobFormScreen(jobId: s.pathParameters['id']),
                      ),
                      GoRoute(
                        path: 'photos',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) =>
                            JobPhotosScreen(jobId: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Invoices
          StatefulShellBranch(
            navigatorKey: _invoicesKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.invoices,
                builder: (_, __) => const InvoicesScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => InvoiceFormScreen(
                      customerId: s.uri.queryParameters['customerId'],
                      jobId: s.uri.queryParameters['jobId'],
                      fromQuoteId: s.uri.queryParameters['fromQuoteId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) =>
                        InvoiceDetailScreen(invoiceId: s.pathParameters['id']!),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) =>
                            InvoiceFormScreen(invoiceId: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // More (menu of everything else)
          StatefulShellBranch(
            navigatorKey: _moreKey,
            routes: <RouteBase>[
              GoRoute(
                path: Routes.more,
                builder: (_, __) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- Top-level sections reached from "More" (full screen) ----
      GoRoute(
        path: Routes.quotes,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const QuotesScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (_, s) => QuoteFormScreen(
              customerId: s.uri.queryParameters['customerId'],
              jobId: s.uri.queryParameters['jobId'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, s) => QuoteDetailScreen(quoteId: s.pathParameters['id']!),
            routes: <RouteBase>[
              GoRoute(
                path: 'edit',
                builder: (_, s) => QuoteFormScreen(quoteId: s.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.payments,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PaymentsScreen(),
      ),
      GoRoute(
        path: Routes.expenses,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ExpensesScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (_, s) =>
                ExpenseFormScreen(jobId: s.uri.queryParameters['jobId']),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (_, s) => ExpenseFormScreen(expenseId: s.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.documents,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const DocumentsScreen(),
      ),
      GoRoute(
        path: Routes.reports,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'company',
            builder: (_, __) => const BusinessSetupWizard(editing: true),
          ),
        ],
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SearchScreen(),
      ),
    ],
  );
});
