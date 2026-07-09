/// Centralised route path constants and helpers.
///
/// Using helpers (rather than string literals scattered across the codebase)
/// keeps navigation type-safe-ish and refactor-friendly.
class Routes {
  const Routes._();

  // Auth & onboarding
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String setup = '/setup';

  // Shell tabs
  static const String dashboard = '/dashboard';
  static const String customers = '/customers';
  static const String jobs = '/jobs';
  static const String invoices = '/invoices';
  static const String more = '/more';

  // Section roots reachable from "More"
  static const String quotes = '/quotes';
  static const String payments = '/payments';
  static const String expenses = '/expenses';
  static const String documents = '/documents';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String search = '/search';

  // ---- Builders for parameterised routes ----
  static String customerDetail(String id) => '/customers/$id';
  static String customerEdit(String id) => '/customers/$id/edit';
  static const String customerNew = '/customers/new';

  static String jobDetail(String id) => '/jobs/$id';
  static String jobEdit(String id) => '/jobs/$id/edit';
  static const String jobNew = '/jobs/new';
  static String jobPhotos(String id) => '/jobs/$id/photos';

  static String quoteDetail(String id) => '/quotes/$id';
  static String quoteEdit(String id) => '/quotes/$id/edit';
  static const String quoteNew = '/quotes/new';

  static String invoiceDetail(String id) => '/invoices/$id';
  static String invoiceEdit(String id) => '/invoices/$id/edit';
  static const String invoiceNew = '/invoices/new';

  static const String expenseNew = '/expenses/new';
  static String expenseEdit(String id) => '/expenses/$id/edit';
}
