import '../models/sales_dashboard_model.dart';
import 'api_client.dart';

class SalesDashboardService {
  final ApiClient _api = ApiClient();

  static const _endpoint = 'sales-dashboard';

  Map<String, String> _qp(SalesView view, SalesPeriode periode,
      {int? page, int? perPage, ProductSort? sort, int? compareYear, String? metric, int? year}) {
    return {
      'periode': periode.apiValue,
      'view': view.name,
      if (year != null) 'year': '$year',
      if (page != null) 'page': '$page',
      if (perPage != null) 'per_page': '$perPage',
      if (sort != null) 'sort': sort.name,
      if (compareYear != null) 'compare_year': '$compareYear',
      if (metric != null) 'metric': metric,
    };
  }

  Future<SalesSummary> getSummary(SalesPeriode periode, {int? year}) async {
    final data = await _api.get(_endpoint,
        queryParams: _qp(SalesView.summary, periode, year: year));
    return SalesSummary.fromJson((data as Map<String, dynamic>?) ?? {});
  }

  Future<List<SalesTrendPoint>> getTrend(SalesPeriode periode,
      {int? compareYear, String metric = 'omzet', int? year}) async {
    final data = await _api.get(_endpoint,
        queryParams: _qp(SalesView.trend, periode,
            compareYear: compareYear, metric: metric, year: year));
    final map = (data as Map<String, dynamic>?) ?? {};
    return (map['points'] as List<dynamic>?)
            ?.map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<({List<SalesProductItem> items, SalesProductMeta meta, List<SalesCategorySummaryItem> categorySummary})> getProducts(
    SalesPeriode periode, {
    int page = 1,
    int perPage = 50,
    ProductSort sort = ProductSort.qty,
    int? compareYear,
    int? year,
  }) async {
    final data = await _api.get(_endpoint,
        queryParams: _qp(SalesView.products, periode,
            page: page, perPage: perPage, sort: sort, compareYear: compareYear, year: year));
    final map = (data as Map<String, dynamic>?) ?? {};
    final items = ((map['items'] as List<dynamic>?) ?? const [])
        .map((e) => SalesProductItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = SalesProductMeta.fromJson(
        (map['meta'] as Map<String, dynamic>?) ?? const {});
    final categorySummary = ((map['category_summary'] as List<dynamic>?) ?? const [])
        .map((e) => SalesCategorySummaryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, meta: meta, categorySummary: categorySummary);
  }

  Future<SalesChannelsResult> getChannels(
    SalesPeriode periode, {
    int? compareYear,
    int? year,
  }) async {
    final data = await _api.get(_endpoint,
        queryParams: _qp(SalesView.channels, periode, compareYear: compareYear, year: year));
    return SalesChannelsResult.fromJson((data as Map<String, dynamic>?) ?? {});
  }

  Future<SalesCategoriesResult> getCategories(
    SalesPeriode periode, {
    int? compareYear,
    int? year,
  }) async {
    final data = await _api.get(_endpoint,
        queryParams: _qp(SalesView.categories, periode, compareYear: compareYear, year: year));
    return SalesCategoriesResult.fromJson((data as Map<String, dynamic>?) ?? {});
  }
}
