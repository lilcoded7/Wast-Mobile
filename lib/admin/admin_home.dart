import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/profile_avatar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../utils/parse_utils.dart';
import '../providers/user_provider.dart';
import '../home/location_picker.dart';
import 'admin_collection_map.dart';

// ── Theme constants ───────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF2E7D32);
const _kDark = Color(0xFF1B5E20);
const _kBg = Color(0xFFF1F8F1);
const _kCard = Colors.white;
const _kAccent = Color(0xFF00C853);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextGray = Color(0xFF757575);
const _kRed = Color(0xFFE53935);
const _kOrange = Color(0xFFFF6D00);
const _kBlue = Color(0xFF1565C0);

// ── Root Admin Page ───────────────────────────────────────────────────────────
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _tab = 0;
  bool _redirecting = false;

  static const _baseTabs = [
    BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard'),
    BottomNavigationBarItem(
        icon: Icon(Icons.delete_sweep_outlined),
        activeIcon: Icon(Icons.delete_sweep),
        label: 'Collections'),
    BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people),
        label: 'Collectors'),
    BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_outlined),
        activeIcon: Icon(Icons.account_balance_wallet),
        label: 'Finance'),
    BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz_outlined),
        activeIcon: Icon(Icons.more_horiz),
        label: 'More'),
  ];

  static const _superAdminTab = BottomNavigationBarItem(
    icon: Icon(Icons.location_city_outlined),
    activeIcon: Icon(Icons.location_city),
    label: 'Branches',
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.isAuthenticated || !provider.isAdmin) {
      if (!_redirecting) {
        _redirecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        });
      }
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    final isSuperAdmin = provider.isSuperAdmin;
    final tabs = isSuperAdmin ? [..._baseTabs, _superAdminTab] : _baseTabs;
    final children = [
      const _DashboardTab(),
      const _CollectionsTab(),
      const _CollectorsTab(),
      const _FinanceTab(),
      const _MoreTab(),
      if (isSuperAdmin) const _BranchManagementTab(),
    ];

    // Clamp _tab index if switching between super/regular admin
    final safeTab = _tab.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: _kBg,
      body: IndexedStack(
        index: safeTab,
        children: children,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 12)],
        ),
        child: BottomNavigationBar(
          currentIndex: safeTab,
          onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _kPrimary,
          unselectedItemColor: _kTextGray,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: tabs,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _period = 'all';
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  final _periods = ['today', 'yesterday', 'week', 'month', 'all'];
  final _periodLabels = ['Today', 'Yesterday', 'Week', 'Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get(
        '${ApiConstants.adminDashboard}?period=$_period',
      );
      setState(() { _data = res; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: _loading && _data == null
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : _error != null && _data == null
                ? _ErrorView(error: _error!, onRetry: _load)
                : CustomScrollView(
                    slivers: [
                      _buildHeader(),
                      _buildPeriodFilter(),
                      if (_data != null) ...[
                        _buildOverviewCards(),
                        _buildCollectionStats(),
                        _buildRevenueChart(),
                        _buildRecentCollections(),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() => SliverToBoxAdapter(
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kPrimary, _kDark]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark)),
                Text(
                  () {
                    final branch = _data?['branch'] as Map<String, dynamic>?;
                    if (branch == null) return 'All Branches';
                    return branch['name'] as String? ?? 'WastePick Control Panel';
                  }(),
                  style: TextStyle(fontSize: 12, color: _kTextGray),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: _kPrimary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminProfilePage())),
          ),
        ],
      ),
    ),
  );

  Widget _buildPeriodFilter() => SliverToBoxAdapter(
    child: SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _periods.length,
        itemBuilder: (_, i) {
          final selected = _period == _periods[i];
          return GestureDetector(
            onTap: () { setState(() => _period = _periods[i]); _load(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? _kPrimary : const Color(0xFFDDDDDD), width: 1),
              ),
              child: Text(_periodLabels[i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _kTextGray)),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildOverviewCards() {
    final ov = _data?['overview'] as Map<String, dynamic>? ?? {};
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Overview'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(title: 'Total Revenue', value: 'GH₵ ${ov['total_revenue'] ?? '0'}',
                    icon: Icons.attach_money, gradient: const [Color(0xFF2E7D32), Color(0xFF43A047)]),
                _StatCard(title: 'Total Paid Out', value: 'GH₵ ${ov['total_paid_out'] ?? '0'}',
                    icon: Icons.payments_outlined, gradient: const [Color(0xFF1565C0), Color(0xFF1976D2)]),
                _StatCard(title: 'Commission Owed', value: 'GH₵ ${ov['total_commission_owed'] ?? '0'}',
                    icon: Icons.account_balance, gradient: const [Color(0xFFE53935), Color(0xFFEF5350)]),
                _StatCard(title: 'Pending Payout', value: 'GH₵ ${ov['pending_payout'] ?? '0'}',
                    icon: Icons.pending_actions, gradient: const [Color(0xFFFF6D00), Color(0xFFFF8F00)]),
                _StatCard(title: 'Customers', value: '${ov['total_customers'] ?? 0}',
                    icon: Icons.person_outline, gradient: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                _StatCard(title: 'Active Collectors', value: '${ov['active_collectors'] ?? 0} / ${ov['total_collectors'] ?? 0}',
                    icon: Icons.local_shipping_outlined, gradient: const [Color(0xFF00838F), Color(0xFF00ACC1)]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionStats() {
    final col = _data?['collections'] as Map<String, dynamic>? ?? {};
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Collections'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MiniStat('Total', '${col['total'] ?? 0}', _kPrimary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Completed', '${col['completed'] ?? 0}', _kAccent)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Pending', '${col['pending'] ?? 0}', _kOrange)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Cancelled', '${col['cancelled'] ?? 0}', _kRed)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final trend = (_data?['daily_trend'] as List? ?? []);
    if (trend.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length && i < 14; i++) {
      final rev = parseDouble(trend[i]['revenue']);
      spots.add(FlSpot(i.toDouble(), rev));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revenue Trend (14 days)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFEEEEEE), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text('₵${v.toInt()}', style: const TextStyle(fontSize: 9, color: _kTextGray)),
                        ),
                      ),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: _kPrimary,
                        barWidth: 2.5,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [_kPrimary.withOpacity(0.25), _kPrimary.withOpacity(0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCollections() {
    final recent = (_data?['recent_collections'] as List? ?? []);
    if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Recent Collections'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                itemBuilder: (_, i) {
                  final r = recent[i] as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    leading: _StatusBadge(status: r['status'] as String? ?? ''),
                    title: Text(r['customer'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(r['waste_type'] as String? ?? '', style: const TextStyle(fontSize: 11, color: _kTextGray)),
                    trailing: Text('GH₵ ${r['price']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _kPrimary, fontSize: 13)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collections Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CollectionsTab extends StatefulWidget {
  const _CollectionsTab();
  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int _total = 0, _page = 1;
  String _status = '';

  static const _statusTabs = [
    ('', 'All'), ('finding', 'Pending'), ('assigned', 'Assigned'),
    ('on_way', 'Active'), ('completed', 'Done'), ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _status = _statusTabs[_tabController.index].$1;
      _page = 1;
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final search = _searchController.text.trim();
      var url = '${ApiConstants.adminCollections}?page=$_page&page_size=20';
      if (_status.isNotEmpty) url += '&status=$_status';
      if (search.isNotEmpty) url += '&search=$search';
      final res = await ApiService.get(url);
      final list = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _items = _page == 1 ? list : [..._items, ...list];
        _total = (res['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text('Collections', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: _kPrimary,
        unselectedLabelColor: _kTextGray,
        indicatorColor: _kPrimary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: _statusTabs.map((t) => Tab(text: t.$2)).toList(),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) { _page = 1; _load(); },
            decoration: InputDecoration(
              hintText: 'Search customer, collector, address…',
              prefixIcon: const Icon(Icons.search, color: _kTextGray, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('$_total results', style: const TextStyle(fontSize: 12, color: _kTextGray, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _items.isEmpty
                  ? const _EmptyState(icon: Icons.delete_sweep_outlined, message: 'No collections found')
                  : RefreshIndicator(
                      onRefresh: () { _page = 1; return _load(); },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _items.length + (_items.length < _total ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _items.length) {
                            return TextButton(
                              onPressed: () { _page++; _load(); },
                              child: const Text('Load more'),
                            );
                          }
                          return _CollectionCard(item: _items[i], onAssign: _load);
                        },
                      ),
                    ),
        ),
      ],
    ),
  );
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAssign;
  const _CollectionCard({required this.item, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatusBadge(status: status),
              const Spacer(),
              Text('GH₵ ${item['price']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _kPrimary, fontSize: 15)),
              if (item['commission_amount'] != null) ...[
                const SizedBox(width: 8),
                Text('(Comm: GH₵${item['commission_amount']})',
                    style: const TextStyle(fontSize: 11, color: _kTextGray)),
              ],
            ]),
            const SizedBox(height: 8),
            _InfoRow(Icons.person_outline, 'Customer', item['customer_name'] as String? ?? ''),
            _InfoRow(Icons.local_shipping_outlined, 'Collector',
                item['collector_name'] as String? ?? 'Not assigned'),
            _InfoRow(Icons.location_on_outlined, 'Pickup', item['pickup_address'] as String? ?? ''),
            if ((item['destination_address'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.flag_outlined, 'Destination', item['destination_address'] as String? ?? ''),
            _InfoRow(Icons.delete_outline, 'Type', '${item['waste_type']} ${item['bin_type'] ?? ''}'),
            _InfoRow(Icons.straighten, 'Distance', '${item['distance_km']?.toStringAsFixed(1) ?? '0'} km'),
            _InfoRow(Icons.payment_outlined, 'Payment',
                '${item['payment_type'] ?? 'N/A'} • ${item['payment_status'] ?? ''}'),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Track on Map'),
                  style: OutlinedButton.styleFrom(foregroundColor: _kBlue),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminCollectionMapPage(collection: item),
                    ),
                  ),
                ),
              ),
            ),
            if (status == 'finding' || status == 'proposed')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Assign Collector'),
                    style: OutlinedButton.styleFrom(foregroundColor: _kPrimary),
                    onPressed: () => _showAssign(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssign(BuildContext context) async {
    final collectors = await _fetchCollectors();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AssignSheet(
        requestId: item['id'] as int,
        collectors: collectors,
        onDone: onAssign,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCollectors() async {
    try {
      final res = await ApiService.get('${ApiConstants.adminCollectors}?is_online=true');
      return (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }
}

class _AssignSheet extends StatefulWidget {
  final int requestId;
  final List<Map<String, dynamic>> collectors;
  final VoidCallback onDone;
  const _AssignSheet({required this.requestId, required this.collectors, required this.onDone});
  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  bool _loading = false;

  Future<void> _assign(int collectorUserId) async {
    setState(() => _loading = true);
    try {
      await ApiService.post(ApiConstants.assignCollection(widget.requestId), {'collector_id': collectorUserId});
      widget.onDone();
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Assign Collector', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 16),
        if (_loading) const CircularProgressIndicator(color: _kPrimary)
        else if (widget.collectors.isEmpty)
          const Text('No online collectors available', style: TextStyle(color: _kTextGray))
        else
          ...widget.collectors.map((c) => ListTile(
            leading: CircleAvatar(
              backgroundColor: _kPrimary.withOpacity(0.1),
              child: const Icon(Icons.person, color: _kPrimary),
            ),
            title: Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c['phone'] as String? ?? ''),
            trailing: Text('⭐ ${c['rating'] ?? 0}'),
            onTap: () => _assign(c['user_id'] as int),
          )),
        const SizedBox(height: 16),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Collectors Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CollectorsTab extends StatefulWidget {
  const _CollectorsTab();
  @override
  State<_CollectorsTab> createState() => _CollectorsTabState();
}

class _CollectorsTabState extends State<_CollectorsTab> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int _total = 0, _page = 1;
  final _search = TextEditingController();
  String _kycFilter = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var url = '${ApiConstants.adminCollectors}?page=$_page&page_size=20';
      if (_search.text.isNotEmpty) url += '&search=${_search.text}';
      if (_kycFilter.isNotEmpty) url += '&kyc_status=$_kycFilter';
      final res = await ApiService.get(url);
      final list = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _items = _page == 1 ? list : [..._items, ...list];
        _total = (res['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Collectors', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: _kPrimary),
          onSelected: (v) { _kycFilter = v == 'all' ? '' : v; _page = 1; _load(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'all', child: Text('All')),
            const PopupMenuItem(value: 'pending', child: Text('Pending KYC')),
            const PopupMenuItem(value: 'under_review', child: Text('Under Review')),
            const PopupMenuItem(value: 'approved', child: Text('Approved')),
            const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            const PopupMenuItem(value: 'suspended', child: Text('Suspended')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onSubmitted: (_) { _page = 1; _load(); },
            decoration: InputDecoration(
              hintText: 'Search by name or phone…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _items.isEmpty
                  ? const _EmptyState(icon: Icons.local_shipping_outlined, message: 'No collectors found')
                  : RefreshIndicator(
                      onRefresh: () { _page = 1; return _load(); },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _items.length + (_items.length < _total ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _items.length) {
                            return TextButton(onPressed: () { _page++; _load(); }, child: const Text('Load more'));
                          }
                          final collector = _items[i];
                          final isSuperAdmin = Provider.of<AppProvider>(context, listen: false).isSuperAdmin;
                          return _CollectorCard(
                            item: collector,
                            onAction: () { _page = 1; _load(); },
                            isSuperAdmin: isSuperAdmin,
                            onDelete: isSuperAdmin ? () async {
                              final id = collector['id'] as int?;
                              if (id == null) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Collector?'),
                                  content: Text('Delete "${collector['name']}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _kRed))),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              try {
                                await ApiService.delete(ApiConstants.superAdminDeleteCollector(id));
                                if (mounted) setState(() => _items.removeWhere((c) => c['id'] == id));
                              } catch (_) {
                                messenger.showSnackBar(const SnackBar(content: Text('Failed to delete collector'), backgroundColor: _kRed));
                              }
                            } : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
  );
}

class _CollectorCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAction;
  final bool isSuperAdmin;
  final VoidCallback? onDelete;
  const _CollectorCard({required this.item, required this.onAction, this.isSuperAdmin = false, this.onDelete});

  Color _kycColor(String? s) {
    switch (s) {
      case 'approved': return _kAccent;
      case 'rejected': return _kRed;
      case 'suspended': return _kOrange;
      case 'under_review': return _kBlue;
      default: return _kTextGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycStatus = item['kyc_status'] as String? ?? 'pending';
    final isApproved = item['is_approved'] == true;
    final score = (item['credit_score'] as num?)?.toInt() ?? 100;
    final scoreColor = score >= 80 ? _kAccent : score >= 50 ? _kOrange : _kRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _kPrimary.withOpacity(0.1),
              backgroundImage: item['profile_image'] != null
                  ? profileImageProvider(item['profile_image'] as String)
                  : null,
              child: item['profile_image'] == null
                  ? const Icon(Icons.person, color: _kPrimary, size: 26)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(item['phone'] as String? ?? '', style: const TextStyle(fontSize: 12, color: _kTextGray)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (isApproved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('APPROVED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kAccent)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kycColor(kycStatus).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(kycStatus.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kycColor(kycStatus))),
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 12, color: scoreColor),
                    Text(' $score pts', style: TextStyle(fontSize: 11, color: scoreColor, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${item['total_collections'] ?? 0} trips • GH₵ ${item['total_earnings'] ?? '0'}',
                      style: const TextStyle(fontSize: 11, color: _kTextGray)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((item['is_online'] as bool?) == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _CollectorDetailPage(collector: item, onAction: onAction),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                if (isSuperAdmin && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                    tooltip: 'Delete collector',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorDetailPage extends StatefulWidget {
  final Map<String, dynamic> collector;
  final VoidCallback onAction;
  const _CollectorDetailPage({required this.collector, required this.onAction});
  @override
  State<_CollectorDetailPage> createState() => _CollectorDetailPageState();
}

class _CollectorDetailPageState extends State<_CollectorDetailPage> {
  bool _loading = false;
  bool _loadingDetail = true;
  Map<String, dynamic>? _detail;
  Map<String, dynamic> get _c => (_detail?['collector'] as Map<String, dynamic>?) ?? widget.collector;

  @override
  void initState() { super.initState(); _loadDetail(); }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final data = await ApiService.get(
        ApiConstants.collectorKycDetail(widget.collector['id'] as int),
      );
      if (mounted) setState(() => _detail = data);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _doAction(String action) async {
    setState(() => _loading = true);
    try {
      final id = widget.collector['id'] as int;
      if (action == 'approve') await ApiService.post(ApiConstants.approveCollector(id), {});
      else if (action == 'decline') await ApiService.post(ApiConstants.declineCollector(id), {});
      else if (action == 'suspend') await ApiService.post(ApiConstants.suspendCollector(id), {});
      widget.onAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action success')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDetail) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.collector['name'] as String? ?? 'Collector',
              style: const TextStyle(color: _kTextDark, fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    final c = _c;
    final kyc = _detail?['kyc'] as Map<String, dynamic>?;
    final vehicles = (_detail?['vehicles'] as List? ?? []).cast<Map<String, dynamic>>();
    final scoreEvents = (_detail?['score_events'] as List? ?? []).cast<Map<String, dynamic>>();
    final kycStatus = c['kyc_status'] as String? ?? kyc?['kyc_status'] as String? ?? 'pending';
    final isApproved = c['is_approved'] == true;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(c['name'] as String? ?? '', style: const TextStyle(color: _kTextDark, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _kPrimary.withOpacity(0.1),
                    backgroundImage: c['profile_image'] != null
                        ? profileImageProvider(c['profile_image'] as String)
                        : null,
                    child: c['profile_image'] == null ? const Icon(Icons.person, size: 40, color: _kPrimary) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(c['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(c['phone'] as String? ?? '', style: const TextStyle(color: _kTextGray)),
                  if ((c['email'] as String? ?? '').isNotEmpty)
                    Text(c['email'] as String, style: const TextStyle(color: _kTextGray, fontSize: 12)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (isApproved)
                        _StatusBadge(status: 'approved')
                      else
                        _StatusBadge(status: kycStatus),
                      if (c['is_online'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('ONLINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kAccent)),
                        ),
                      if (c['password_set'] == false)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('PASSWORD NOT SET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kOrange)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _InfoChip('${c['total_collections'] ?? 0}', 'Trips'),
                    _InfoChip('GH₵${c['total_earnings'] ?? 0}', 'Earnings'),
                    _InfoChip('${c['credit_score'] ?? 100}', 'Score'),
                    _InfoChip('${c['rating'] ?? 0}⭐', 'Rating'),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionTitle2('Profile Details'),
              const SizedBox(height: 8),
              _DetailTile('Vehicle Type', c['vehicle_type'] as String? ?? '—'),
              _DetailTile('Vehicle Number', c['vehicle_number'] as String? ?? '—'),
              _DetailTile('Applied', _formatDate(c['applied_at'] as String?)),
              _DetailTile('Unpaid Commission', 'GH₵ ${c['unpaid_commission'] ?? '0'}'),
              if (parseDouble(c['unpaid_commission']) > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kOrange.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: _kOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Owes GH₵${c['unpaid_commission']} in cash commissions',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _kOrange)),
                    ),
                  ]),
                ),
              ],
              if (kyc != null) ...[
                const SizedBox(height: 16),
                _SectionTitle2('KYC Information'),
                const SizedBox(height: 8),
                _DetailTile('Ghana Card', kyc['ghana_card_number'] as String? ?? '—'),
                _DetailTile('License Number', kyc['license_number'] as String? ?? '—'),
                if ((kyc['email'] as String? ?? '').isNotEmpty)
                  _DetailTile('Email', kyc['email'] as String),
                if ((kyc['vehicle_number_plate'] as String? ?? '').isNotEmpty)
                  _DetailTile('Plate on KYC', kyc['vehicle_number_plate'] as String),
                if ((kyc['rejection_reason'] as String? ?? '').isNotEmpty)
                  _DetailTile('Rejection Reason', kyc['rejection_reason'] as String),
                const SizedBox(height: 8),
                ...(kyc['documents'] as List? ?? []).map((d) => _KycDocRow(doc: d as Map<String, dynamic>)),
              ],
              if (vehicles.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle2('Registered Vehicles'),
                const SizedBox(height: 8),
                ...vehicles.map((v) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v['name'] as String? ?? v['vehicle_type'] as String? ?? 'Vehicle',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${v['vehicle_type']} • ${v['vehicle_number'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: _kTextGray)),
                    if (v['driver_name'] != null)
                      Text('Driver: ${v['driver_name']}', style: const TextStyle(fontSize: 12, color: _kTextGray)),
                    if (v['vehicle_photo'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: v['vehicle_photo'] as String,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ]),
                )),
              ],
              if (scoreEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle2('Score History'),
                const SizedBox(height: 8),
                ...scoreEvents.take(5).map((ev) {
                  final pts = (ev['points_change'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    dense: true,
                    tileColor: _kCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(pts >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: pts >= 0 ? _kAccent : _kRed),
                    title: Text(ev['event_type'].toString().replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(ev['note'] as String? ?? ''),
                    trailing: Text('${pts >= 0 ? '+' : ''}$pts pts',
                        style: TextStyle(fontWeight: FontWeight.w700, color: pts >= 0 ? _kAccent : _kRed)),
                  );
                }),
              ],
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator(color: _kPrimary))
              else ...[
                if (!isApproved)
                  _ActionBtn('Approve Collector', _kAccent, () => _doAction('approve')),
                if (!isApproved && kycStatus != 'rejected')
                  _ActionBtn('Decline Application', _kRed, () => _doAction('decline')),
                if (isApproved && kycStatus != 'suspended')
                  _ActionBtn('Suspend Collector', _kOrange, () => _doAction('suspend')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  const _DetailTile(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
    ]),
  );
}

class _KycDocRow extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _KycDocRow({required this.doc});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = doc['url'] as String?;
    return ListTile(
      dense: true,
      tileColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: const Icon(Icons.insert_drive_file_outlined, color: _kPrimary),
      title: Text(doc['document_type_display'] as String? ?? doc['document_type'] as String? ?? '',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(doc['status'] as String? ?? '', style: const TextStyle(fontSize: 11)),
      trailing: url != null
          ? TextButton(
              onPressed: () => _openUrl(context, url),
              child: const Text('View', style: TextStyle(color: _kPrimary)),
            )
          : const Text('Not uploaded', style: TextStyle(color: _kTextGray, fontSize: 11)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Finance Tab
// ─────────────────────────────────────────────────────────────────────────────
class _FinanceTab extends StatefulWidget {
  const _FinanceTab();
  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> with SingleTickerProviderStateMixin {
  late TabController _tc;
  bool _loading = false;
  Map<String, dynamic>? _finance;
  List<Map<String, dynamic>> _withdrawals = [];
  int _wPage = 1;
  String _wStatus = '';
  List<Map<String, dynamic>> _commissionRules = [];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _loadFinance();
    _loadWithdrawals();
    _loadCommissions();
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  Future<void> _loadFinance() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConstants.adminFinance);
      setState(() => _finance = res);
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _loadWithdrawals() async {
    try {
      var url = '${ApiConstants.adminWithdrawals}?page=$_wPage&page_size=20';
      if (_wStatus.isNotEmpty) url += '&status=$_wStatus';
      final res = await ApiService.get(url);
      final list = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _withdrawals = _wPage == 1 ? list : [..._withdrawals, ...list];
      });
    } catch (_) {}
  }

  Future<void> _loadCommissions() async {
    try {
      final res = await ApiService.get(ApiConstants.adminCommissions) as List;
      setState(() => _commissionRules = res.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _processWithdrawal(int id, bool approve) async {
    try {
      final url = approve ? ApiConstants.approveWithdrawal(id) : ApiConstants.declineWithdrawal(id);
      await ApiService.post(url, {});
      _wPage = 1;
      await _loadWithdrawals();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Withdrawal approved' : 'Withdrawal declined')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Finance', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
      bottom: TabBar(
        controller: _tc,
        labelColor: _kPrimary, unselectedLabelColor: _kTextGray, indicatorColor: _kPrimary,
        tabs: const [Tab(text: 'Overview'), Tab(text: 'Withdrawals'), Tab(text: 'Commissions')],
      ),
    ),
    body: TabBarView(
      controller: _tc,
      children: [
        _buildOverview(),
        _buildWithdrawals(),
        _buildCommissions(),
      ],
    ),
  );

  Widget _buildOverview() {
    final s = _finance?['summary'] as Map<String, dynamic>? ?? {};
    final ws = s['withdrawal_summary'] as Map<String, dynamic>? ?? {};
    final txn = _finance?['transactions'] as Map<String, dynamic>? ?? {};
    final txnList = (txn['results'] as List? ?? []).cast<Map<String, dynamic>>();

    if (_loading && _finance == null) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    return RefreshIndicator(
      onRefresh: _loadFinance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FinanceCard('Total Revenue', 'GH₵ ${s['total_revenue'] ?? '0'}', Icons.trending_up, _kPrimary),
          _FinanceCard('Company Earnings', 'GH₵ ${s['company_earnings'] ?? '0'}', Icons.account_balance, _kBlue),
          _FinanceCard('Collector Earnings', 'GH₵ ${s['collector_earnings'] ?? '0'}', Icons.local_shipping_outlined, _kAccent),
          _FinanceCard('Cash Comm. Owed', 'GH₵ ${s['cash_commission_owed'] ?? '0'}', Icons.warning_amber, _kOrange),
          const Divider(height: 24),
          _SectionTitle2('Withdrawal Summary'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MiniStat('Pending', (ws['pending']?['count'] ?? 0).toString(), _kOrange)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Approved', (ws['approved']?['count'] ?? 0).toString(), _kAccent)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Declined', (ws['declined']?['count'] ?? 0).toString(), _kRed)),
          ]),
          const Divider(height: 24),
          _SectionTitle2('Recent Transactions'),
          const SizedBox(height: 8),
          ...txnList.map((t) => ListTile(
            dense: true,
            leading: Icon(_txIcon(t['type'] as String? ?? ''), color: _kPrimary, size: 18),
            title: Text(t['user'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(t['description'] as String? ?? '', style: const TextStyle(fontSize: 11)),
            trailing: Text('GH₵${t['amount']}', style: const TextStyle(fontWeight: FontWeight.w700, color: _kPrimary)),
          )),
        ],
      ),
    );
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'payment': return Icons.payments_outlined;
      case 'payout': return Icons.account_balance_wallet_outlined;
      case 'commission': return Icons.percent;
      default: return Icons.receipt_outlined;
    }
  }

  Widget _buildWithdrawals() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: ['', 'pending', 'approved', 'declined'].map((s) {
            final selected = _wStatus == s;
            final label = s.isEmpty ? 'All' : s[0].toUpperCase() + s.substring(1);
            return Expanded(
              child: GestureDetector(
                onTap: () { setState(() { _wStatus = s; _wPage = 1; }); _loadWithdrawals(); },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? _kPrimary : const Color(0xFFDDDDDD)),
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _kTextGray)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: _withdrawals.isEmpty
            ? const _EmptyState(icon: Icons.account_balance_wallet_outlined, message: 'No withdrawal requests')
            : RefreshIndicator(
                onRefresh: () { _wPage = 1; return _loadWithdrawals(); },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _withdrawals.length,
                  itemBuilder: (_, i) {
                    final w = _withdrawals[i];
                    final isPending = w['status'] == 'pending';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(w['collector']?['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(w['created_at'] as String? ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('GH₵${w['amount']}', style: const TextStyle(fontWeight: FontWeight.w800, color: _kPrimary, fontSize: 15)),
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.check_circle, color: _kAccent), onPressed: () => _processWithdrawal(w['id'] as int, true)),
                              IconButton(icon: const Icon(Icons.cancel, color: _kRed), onPressed: () => _processWithdrawal(w['id'] as int, false)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  Widget _buildCommissions() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(children: [
        const Expanded(child: _SectionTitle2('Commission Rules')),
        TextButton.icon(
          onPressed: _showAddCommission,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Rule'),
        ),
      ]),
      const SizedBox(height: 8),
      ..._commissionRules.map((r) => _CommissionRuleCard(rule: r, onChanged: _loadCommissions)),
    ],
  );

  void _showAddCommission() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CommissionRuleForm(onSaved: _loadCommissions),
  );
}

class _CommissionRuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final VoidCallback onChanged;
  const _CommissionRuleCard({required this.rule, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)]),
    child: Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rule['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'GH₵${rule['min_amount']} – ${rule['max_amount'] ?? '∞'} → '
              '${rule['commission_type'] == 'percentage' ? '${rule['value']}%' : 'GH₵${rule['value']}'}',
              style: const TextStyle(color: _kTextGray, fontSize: 12),
            ),
          ]),
        ),
        Switch(
          value: rule['is_active'] as bool? ?? true,
          onChanged: (_) {},
          activeColor: _kPrimary,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
          onPressed: () async {
            await ApiService.delete(ApiConstants.commissionRule(rule['id'] as int));
            onChanged();
          },
        ),
      ],
    ),
  );
}

class _CommissionRuleForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _CommissionRuleForm({required this.onSaved});
  @override
  State<_CommissionRuleForm> createState() => _CommissionRuleFormState();
}

class _CommissionRuleFormState extends State<_CommissionRuleForm> {
  final _name = TextEditingController();
  final _min = TextEditingController(text: '0');
  final _max = TextEditingController();
  final _val = TextEditingController();
  String _type = 'percentage';
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ApiService.post(ApiConstants.adminCommissions, {
        'name': _name.text,
        'min_amount': _min.text,
        'max_amount': _max.text.isEmpty ? null : _max.text,
        'commission_type': _type,
        'value': _val.text,
        'is_active': true,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('New Commission Rule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Rule Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _min, decoration: const InputDecoration(labelText: 'Min GH₵', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _max, decoration: const InputDecoration(labelText: 'Max GH₵ (blank=∞)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _val, decoration: InputDecoration(labelText: _type == 'percentage' ? 'Value (%)' : 'Value (GH₵)', border: const OutlineInputBorder()), keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _type,
          onChanged: (v) => setState(() => _type = v!),
          items: const [
            DropdownMenuItem(value: 'percentage', child: Text('%')),
            DropdownMenuItem(value: 'fixed', child: Text('GH₵ Fixed')),
          ],
        ),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Rule'),
        ),
      ),
      const SizedBox(height: 16),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// More Tab (Schedules, Reports, Customers, Commission Rules)
// ─────────────────────────────────────────────────────────────────────────────
class _MoreTab extends StatelessWidget {
  const _MoreTab();
  Future<void> _logout(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('More', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MoreTile(Icons.people_outline, 'Customers', 'View all customers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CustomersPage()))),
        _MoreTile(Icons.person_add_outlined, 'Create User', 'Customer, collector, or investor', () {
          final isSA = Provider.of<AppProvider>(context, listen: false).isSuperAdmin;
          Navigator.push(context, MaterialPageRoute(builder: (_) => _AdminCreateUserPage(isSuperAdmin: isSA)));
        }),
        _MoreTile(Icons.calendar_today_outlined, 'Schedules', 'Recurring pickups', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SchedulesPage()))),
        _MoreTile(Icons.report_outlined, 'Dumping Reports', 'View filed reports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ReportsPage()))),
        _MoreTile(Icons.settings_outlined, 'Admin Profile', 'Update your profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdminProfilePage()))),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout, color: _kRed, size: 22),
            ),
            title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Sign out of the admin portal',
                style: TextStyle(color: _kTextGray, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: _kTextGray),
            onTap: () => _logout(context),
          ),
        ),
      ],
    ),
  );
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MoreTile(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _kPrimary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: _kTextGray, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: _kTextGray),
      onTap: onTap,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Customers Page
// ─────────────────────────────────────────────────────────────────────────────
class _CustomersPage extends StatefulWidget {
  const _CustomersPage();
  @override
  State<_CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<_CustomersPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int _total = 0, _page = 1;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var url = '${ApiConstants.adminCustomers}?page=$_page&page_size=20';
      if (_search.text.isNotEmpty) url += '&search=${_search.text}';
      final res = await ApiService.get(url);
      final list = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _items = _page == 1 ? list : [..._items, ...list];
        _total = (res['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Customers', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onSubmitted: (_) { _page = 1; _load(); },
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _items.isEmpty
                  ? const _EmptyState(icon: Icons.people_outline, message: 'No customers found')
                  : RefreshIndicator(
                      onRefresh: () { _page = 1; return _load(); },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _items.length + (_items.length < _total ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _items.length) return TextButton(onPressed: () { _page++; _load(); }, child: const Text('Load more'));
                          final c = _items[i];
                          final isSuperAdmin = Provider.of<AppProvider>(context, listen: false).isSuperAdmin;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _kPrimary.withOpacity(0.1),
                                backgroundImage: c['profile_image'] != null
                                    ? profileImageProvider(c['profile_image'] as String)
                                    : null,
                                child: c['profile_image'] == null ? const Icon(Icons.person, color: _kPrimary) : null,
                              ),
                              title: Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(c['phone'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                              trailing: isSuperAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${c['completed_requests']} trips', style: const TextStyle(fontSize: 11, color: _kTextGray)),
                                            Text('GH₵${c['total_spent']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kPrimary)),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                                          tooltip: 'Delete customer',
                                          onPressed: () async {
                                            final id = c['id'] as int?;
                                            if (id == null) return;
                                            final messenger = ScaffoldMessenger.of(context);
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text('Delete Customer?'),
                                                content: Text('Delete "${c['name']}"? This cannot be undone.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _kRed))),
                                                ],
                                              ),
                                            );
                                            if (confirm != true) return;
                                            try {
                                              await ApiService.delete(ApiConstants.superAdminDeleteCustomer(id));
                                              if (mounted) setState(() => _items.removeWhere((x) => x['id'] == id));
                                            } catch (_) {
                                              messenger.showSnackBar(const SnackBar(content: Text('Failed to delete customer'), backgroundColor: _kRed));
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${c['completed_requests']} trips', style: const TextStyle(fontSize: 11, color: _kTextGray)),
                                        Text('GH₵${c['total_spent']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kPrimary)),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedules Page
// ─────────────────────────────────────────────────────────────────────────────
class _SchedulesPage extends StatefulWidget {
  const _SchedulesPage();
  @override
  State<_SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<_SchedulesPage> {
  bool _loading = false;
  bool _loadingMore = false;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  String _period = 'all';
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loading && !_loadingMore && _items.length < _total) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _loading = true);
    try {
      final url = '${ApiConstants.adminSchedules}?page=$_page&page_size=20&period=$_period';
      final res = await ApiService.get(url);
      if (!mounted) return;
      setState(() {
        _items = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _total = (res['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final url = '${ApiConstants.adminSchedules}?page=$next&page_size=20&period=$_period';
      final res = await ApiService.get(url);
      if (!mounted) return;
      setState(() {
        _page = next;
        _items = [..._items, ...(res['results'] as List? ?? []).cast<Map<String, dynamic>>()];
        _total = (res['total'] as num?)?.toInt() ?? _total;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setPeriod(String p) {
    _period = p;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Schedules', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
    ),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              _PeriodChip(label: 'All', selected: _period == 'all', onTap: () => _setPeriod('all')),
              _PeriodChip(label: 'Today', selected: _period == 'today', onTap: () => _setPeriod('today')),
              _PeriodChip(label: 'Yesterday', selected: _period == 'yesterday', onTap: () => _setPeriod('yesterday')),
              _PeriodChip(label: 'This Week', selected: _period == 'week', onTap: () => _setPeriod('week')),
            ],
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _items.isEmpty
                  ? const _EmptyState(icon: Icons.calendar_today_outlined, message: 'No schedules')
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(color: _kPrimary)),
                            );
                          }
                          final s = _items[i];
                          final customer = s['customer'] as Map<String, dynamic>?;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.schedule, color: _kPrimary),
                              ),
                              title: Text(customer?['name'] as String? ?? customer?['full_name'] as String? ?? 'Customer',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${s['frequency']} • ${s['day_of_week']} • ${s['pickup_time']}\n${s['pickup_address'] ?? ''}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: _StatusBadge(status: s['is_active'] == true ? 'active' : 'inactive'),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
  );
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _kPrimary.withOpacity(0.15),
      checkmarkColor: _kPrimary,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reports Page
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsPage extends StatefulWidget {
  const _ReportsPage();
  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConstants.adminReports);
      setState(() => _items = (res['results'] as List? ?? []).cast<Map<String, dynamic>>());
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _resolve(int id) async {
    await ApiService.post(ApiConstants.resolveReport(id), {});
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Dumping Reports', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _kPrimary))
        : _items.isEmpty
            ? const _EmptyState(icon: Icons.report_outlined, message: 'No reports')
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final r = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.report_outlined, color: _kRed),
                        ),
                        title: Text(r['description'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(r['location'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                        trailing: r['status'] == 'pending'
                            ? TextButton(
                                onPressed: () => _resolve(r['id'] as int),
                                child: const Text('Resolve', style: TextStyle(color: _kPrimary, fontSize: 12)),
                              )
                            : const Text('Resolved', style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Create User Page
// ─────────────────────────────────────────────────────────────────────────────
class _AdminCreateUserPage extends StatefulWidget {
  final bool isSuperAdmin;
  const _AdminCreateUserPage({this.isSuperAdmin = false});
  @override
  State<_AdminCreateUserPage> createState() => _AdminCreateUserPageState();
}

class _AdminCreateUserPageState extends State<_AdminCreateUserPage> with SingleTickerProviderStateMixin {
  late TabController _tc;
  bool _loading = false;
  final _picker = ImagePicker();

  static const _vehicleTypes = [
    'Pickup Truck',
    'Tricycle',
    'Motorcycle',
    'Van',
    'Mini Truck',
  ];

  final _custFirst = TextEditingController();
  final _custLast = TextEditingController();
  final _custPhone = TextEditingController();
  final _custEmail = TextEditingController();
  final _custPass = TextEditingController();

  final _colName = TextEditingController();
  final _colPhone = TextEditingController();
  final _colGhanaCard = TextEditingController();
  final _colLicense = TextEditingController();
  final _colVehicleName = TextEditingController();
  final _colVehicleNumber = TextEditingController();
  final _colPass = TextEditingController();
  String _colVehicleType = _vehicleTypes.first;
  bool _colAutoApprove = false;
  File? _colGhanaFront;
  File? _colGhanaBack;
  File? _colLicenseFront;
  File? _colLicenseBack;
  File? _colVehiclePhoto;

  final _invFirst = TextEditingController();
  final _invLast = TextEditingController();
  final _invPhone = TextEditingController();
  final _invLocation = TextEditingController();
  final _invAmount = TextEditingController();
  final _invRoi = TextEditingController();
  double? _invLat;
  double? _invLng;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: widget.isSuperAdmin ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    _custFirst.dispose(); _custLast.dispose(); _custPhone.dispose(); _custEmail.dispose(); _custPass.dispose();
    _colName.dispose(); _colPhone.dispose(); _colGhanaCard.dispose(); _colLicense.dispose();
    _colVehicleName.dispose(); _colVehicleNumber.dispose(); _colPass.dispose();
    _invFirst.dispose(); _invLast.dispose(); _invPhone.dispose();
    _invLocation.dispose(); _invAmount.dispose(); _invRoi.dispose();
    super.dispose();
  }

  Future<File?> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    return x != null ? File(x.path) : null;
  }

  Future<void> _choosePhoto(void Function(File?) setFile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final f = await _pickImage(source);
    if (f != null) setState(() => setFile(f));
  }

  Widget _photoTile(File? file, VoidCallback onTap, {required String label}) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.3)),
      ),
      child: file != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: _kPrimary.withOpacity(0.7)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 11, color: _kTextGray)),
              ],
            ),
    ),
  );

  Future<void> _pickInvestorLocation() async {
    final result = await showLocationPicker(context);
    if (result == null) return;
    setState(() {
      _invLocation.text = result['address'] as String? ?? '';
      _invLat = (result['lat'] as num?)?.toDouble();
      _invLng = (result['lng'] as num?)?.toDouble();
    });
  }

  Future<void> _createCustomer() async {
    setState(() => _loading = true);
    try {
      await ApiService.post(ApiConstants.adminCustomers, {
        'first_name': _custFirst.text.trim(),
        'last_name': _custLast.text.trim(),
        'phone': _custPhone.text.trim(),
        if (_custEmail.text.isNotEmpty) 'email': _custEmail.text.trim(),
        if (_custPass.text.isNotEmpty) 'password': _custPass.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer created')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _createCollector() async {
    if (_colName.text.trim().isEmpty ||
        _colPhone.text.trim().isEmpty ||
        _colGhanaCard.text.trim().isEmpty ||
        _colLicense.text.trim().isEmpty ||
        _colVehicleNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all required fields')),
      );
      return;
    }
    if (_colGhanaFront == null || _colGhanaBack == null ||
        _colLicenseFront == null || _colLicenseBack == null ||
        _colVehiclePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload Ghana card, license, and vehicle photos')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final fields = <String, String>{
        'name': _colName.text.trim(),
        'phone': _colPhone.text.trim(),
        'ghana_card_number': _colGhanaCard.text.trim(),
        'license_number': _colLicense.text.trim(),
        'vehicle_type': _colVehicleType,
        'vehicle_number': _colVehicleNumber.text.trim(),
        'auto_approve': _colAutoApprove.toString(),
      };
      if (_colVehicleName.text.trim().isNotEmpty) {
        fields['vehicle_name'] = _colVehicleName.text.trim();
      }
      if (_colPass.text.isNotEmpty) fields['password'] = _colPass.text.trim();

      final files = <String, File>{
        'ghana_card_front': _colGhanaFront!,
        'ghana_card_back': _colGhanaBack!,
        'license_front': _colLicenseFront!,
        'license_back': _colLicenseBack!,
        'vehicle_photo': _colVehiclePhoto!,
      };

      final res = await ApiService.postMultipart(ApiConstants.adminCollectors, fields, files);
      if (!mounted) return;
      final temp = res['collector']?['temporary_password'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(temp != null ? 'Collector created. Temp password: $temp' : 'Collector created'),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _createInvestor() async {
    if (_invFirst.text.trim().isEmpty ||
        _invLast.text.trim().isEmpty ||
        _invPhone.text.trim().isEmpty ||
        _invLocation.text.trim().isEmpty ||
        _invAmount.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all required fields')),
      );
      return;
    }
    if (looksLikeCoordinates(_invLocation.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location must be a place name, not GPS coordinates. '
            'Tap the GPS icon and pick an address from search.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'first_name': _invFirst.text.trim(),
        'last_name': _invLast.text.trim(),
        'phone': _invPhone.text.trim(),
        'location': _invLocation.text.trim(),
        'investment_amount': _invAmount.text.trim(),
        'roi_percentage': _invRoi.text.trim().isEmpty ? '0' : _invRoi.text.trim(),
      };
      if (_invLat != null) payload['location_latitude'] = _invLat.toString();
      if (_invLng != null) payload['location_longitude'] = _invLng.toString();

      await ApiService.post(ApiConstants.adminInvestors, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Investor account created. They can set their password on first login.')),
      );
      Navigator.pop(context); // go back to investor list
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Widget _field(String label, TextEditingController c, {TextInputType? type, Widget? suffixIcon}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kTextDark)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Create User', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
      bottom: TabBar(
        controller: _tc,
        labelColor: _kPrimary,
        unselectedLabelColor: _kTextGray,
        tabs: [
          const Tab(text: 'Customer'),
          const Tab(text: 'Collector'),
          if (widget.isSuperAdmin) const Tab(text: 'Investor'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tc,
      children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          _field('First Name', _custFirst),
          _field('Last Name', _custLast),
          _field('Phone', _custPhone, type: TextInputType.phone),
          _field('Email (optional)', _custEmail, type: TextInputType.emailAddress),
          _field('Password (optional)', _custPass),
          ElevatedButton(onPressed: _loading ? null : _createCustomer,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Customer')),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: [
          _sectionTitle('Collector details'),
          _field('Full Name', _colName),
          _field('Phone', _colPhone, type: TextInputType.phone),
          _field('Ghana Card Number', _colGhanaCard),
          const Text('Ghana card (front & back)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _photoTile(_colGhanaFront, () => _choosePhoto((f) => _colGhanaFront = f), label: 'Front')),
            const SizedBox(width: 10),
            Expanded(child: _photoTile(_colGhanaBack, () => _choosePhoto((f) => _colGhanaBack = f), label: 'Back')),
          ]),
          const SizedBox(height: 12),
          _field('License Number', _colLicense),
          const Text('Driver license (front & back)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _photoTile(_colLicenseFront, () => _choosePhoto((f) => _colLicenseFront = f), label: 'Front')),
            const SizedBox(width: 10),
            Expanded(child: _photoTile(_colLicenseBack, () => _choosePhoto((f) => _colLicenseBack = f), label: 'Back')),
          ]),
          _sectionTitle('Vehicle'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Vehicle Type',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _colVehicleType,
                  isExpanded: true,
                  items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _colVehicleType = v); },
                ),
              ),
            ),
          ),
          _field('Vehicle Name (optional)', _colVehicleName),
          _field('Registration Number', _colVehicleNumber),
          const Text('Vehicle photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _photoTile(_colVehiclePhoto, () => _choosePhoto((f) => _colVehiclePhoto = f), label: 'Vehicle'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'The new collector will be assigned as the driver for this vehicle.',
              style: TextStyle(fontSize: 12, color: _kTextGray),
            ),
          ),
          const SizedBox(height: 8),
          _field('Password (optional)', _colPass),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Approve immediately'),
            value: _colAutoApprove,
            activeThumbColor: _kPrimary,
            onChanged: (v) => setState(() => _colAutoApprove = v),
          ),
          ElevatedButton(onPressed: _loading ? null : _createCollector,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Collector')),
        ]),
        if (widget.isSuperAdmin)
          ListView(padding: const EdgeInsets.all(16), children: [
            _field('First Name', _invFirst),
            _field('Last Name', _invLast),
            _field('Phone', _invPhone, type: TextInputType.phone),
            _field(
              'Location',
              _invLocation,
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location, color: _kPrimary),
                tooltip: 'Pick location with GPS',
                onPressed: _pickInvestorLocation,
              ),
            ),
            _field('Investment Amount (GHS)', _invAmount, type: TextInputType.number),
            _field('ROI %', _invRoi, type: TextInputType.number),
            ElevatedButton(onPressed: _loading ? null : _createInvestor,
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Investor')),
          ]),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Profile Page
// ─────────────────────────────────────────────────────────────────────────────
class _AdminProfilePage extends StatefulWidget {
  const _AdminProfilePage();
  @override
  State<_AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<_AdminProfilePage> {
  bool _loading = false;
  bool _loggingOut = false;
  Map<String, dynamic>? _profile;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  File? _imageFile;

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.get(ApiConstants.adminProfile);
      setState(() {
        _profile = res;
        _firstName.text = res['first_name'] as String? ?? '';
        _lastName.text = res['last_name'] as String? ?? '';
        _email.text = res['email'] as String? ?? '';
        _phone.text = res['phone'] as String? ?? '';
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    final refresh = await ApiService.getRefreshToken();
    try {
      if (refresh != null) {
        await ApiService.post(ApiConstants.logout, {'refresh': refresh});
      }
    } catch (_) {}
    await ApiService.clearTokens();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ApiService.patchMultipart(ApiConstants.adminProfile, {
        'first_name': _firstName.text,
        'last_name': _lastName.text,
        'email': _email.text,
        'phone': _phone.text,
        if (_password.text.isNotEmpty) 'password': _password.text,
      }, imageFile: _imageFile, imageField: 'profile_image');
      await context.read<AppProvider>().refreshProfileImageFromServer();
      await _loadProfile();
      if (mounted) {
        setState(() {
          _imageFile = null;
          if (context.read<AppProvider>().profileImageUrl != null) {
            _profile = {
              ...?_profile,
              'profile_image': context.read<AppProvider>().profileImageUrl,
            };
          }
        });
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      title: const Text('Admin Profile', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _kPrimary.withOpacity(0.1),
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!) as ImageProvider
                      : (_profile?['profile_image'] != null
                          ? profileImageProvider(_profile!['profile_image'] as String)
                          : null),
                  child: (_imageFile == null && _profile?['profile_image'] == null)
                      ? const Icon(Icons.admin_panel_settings, size: 50, color: _kPrimary)
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Field(_firstName, 'First Name', Icons.person_outline),
          const SizedBox(height: 12),
          _Field(_lastName, 'Last Name', Icons.person_outline),
          const SizedBox(height: 12),
          _Field(_email, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _Field(_phone, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kRed),
                    )
                  : const Icon(Icons.logout, color: _kRed, size: 20),
              label: Text(
                _loggingOut ? 'Logging out…' : 'Logout',
                style: const TextStyle(
                  color: _kRed, fontWeight: FontWeight.w700, fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: _kRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final List<Color> gradient;
  const _StatCard({required this.title, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: _kTextGray)),
    ]),
  );
}

class _FinanceCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _FinanceCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)]),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _kTextGray, fontSize: 13)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ]),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'completed': return _kAccent;
      case 'cancelled': return _kRed;
      case 'on_way': case 'arrived': return _kBlue;
      case 'assigned': return _kPrimary;
      case 'active': return _kAccent;
      case 'inactive': return _kTextGray;
      default: return _kOrange;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _color)),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 13, color: _kTextGray),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: _kTextGray)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _InfoChip extends StatelessWidget {
  final String value, label;
  const _InfoChip(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _kPrimary)),
    Text(label, style: const TextStyle(fontSize: 10, color: _kTextGray)),
  ]);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark));
}

class _SectionTitle2 extends StatelessWidget {
  final String t;
  const _SectionTitle2(this.t);
  @override
  Widget build(BuildContext context) => Text(t,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark));
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            foregroundColor: color, side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: _kRed),
      const SizedBox(height: 16),
      Text('Failed to load data', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      Text(error, style: const TextStyle(color: _kTextGray, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _kPrimary), child: const Text('Retry')),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: const Color(0xFFDDDDDD)),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: _kTextGray, fontSize: 14)),
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType type;
  final bool obscure;
  const _Field(this.controller, this.label, this.icon,
      {this.type = TextInputType.text, this.obscure = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: type,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: _kTextGray),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Super-Admin: Branch Management Tab
// ─────────────────────────────────────────────────────────────────────────────

class _BranchManagementTab extends StatefulWidget {
  const _BranchManagementTab();

  @override
  State<_BranchManagementTab> createState() => _BranchManagementTabState();
}

class _BranchManagementTabState extends State<_BranchManagementTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _branches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      _branches = await provider.fetchBranches();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _kRed : _kPrimary,
    ));
  }

  // ── Create Branch ───────────────────────────────────────────────────────────
  Future<void> _showCreateBranchSheet() async {
    final nameCtrl    = TextEditingController();
    final regionCtrl  = TextEditingController();
    final countryCtrl = TextEditingController(text: 'Ghana');
    final addressCtrl = TextEditingController();
    double? lat, lng;
    String locationLabel = 'Tap to pick on map';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New Branch',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextDark)),
                const SizedBox(height: 20),
                _SheetField(ctrl: nameCtrl,    label: 'Branch Name',  icon: Icons.business),
                const SizedBox(height: 12),
                _SheetField(ctrl: regionCtrl,  label: 'Region',       icon: Icons.map_outlined),
                const SizedBox(height: 12),
                _SheetField(ctrl: countryCtrl, label: 'Country',      icon: Icons.flag_outlined),
                const SizedBox(height: 12),
                _SheetField(ctrl: addressCtrl, label: 'Address (optional)', icon: Icons.location_on_outlined),
                const SizedBox(height: 16),
                // Map location picker — uses the tab's outer context so the
                // picker sheet opens above the create-branch sheet.
                GestureDetector(
                  onTap: () async {
                    final outerCtx = context; // capture before gap
                    final result = await showLocationPicker(outerCtx);
                    if (result != null) {
                      setSheet(() {
                        lat = (result['lat'] as num).toDouble();
                        lng = (result['lng'] as num).toDouble();
                        locationLabel = result['address'] as String? ??
                            '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
                        if (addressCtrl.text.isEmpty && result['address'] != null) {
                          addressCtrl.text = result['address'] as String;
                        }
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lat != null ? _kPrimary : const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pin_drop_outlined,
                            color: lat != null ? _kPrimary : _kTextGray, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locationLabel,
                            style: TextStyle(
                              color: lat != null ? _kTextDark : _kTextGray,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (lat != null)
                          const Icon(Icons.check_circle, color: _kPrimary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _snack('Branch name is required', error: true);
                        return;
                      }
                      if (regionCtrl.text.trim().isEmpty) {
                        _snack('Region is required', error: true);
                        return;
                      }
                      if (lat == null) {
                        _snack('Pick a location on the map', error: true);
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        final provider = Provider.of<AppProvider>(context, listen: false);
                        await provider.createBranch(
                          name: nameCtrl.text.trim(),
                          region: regionCtrl.text.trim(),
                          country: countryCtrl.text.trim().isEmpty ? 'Ghana' : countryCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          lat: lat!,
                          lng: lng!,
                        );
                        _snack('Branch created');
                        _load();
                      } on ApiException catch (e) {
                        _snack(e.message, error: true);
                      } catch (e) {
                        _snack('Failed to create branch', error: true);
                      }
                    },
                    child: const Text('Create Branch',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    regionCtrl.dispose();
    countryCtrl.dispose();
    addressCtrl.dispose();
  }

  // ── Create Admin ────────────────────────────────────────────────────────────
  Future<void> _showCreateAdminSheet(int? preselectedBranchId) async {
    final firstCtrl = TextEditingController();
    final lastCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    int? selectedBranchId = preselectedBranchId;
    bool obscure = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Admin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextDark)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _SheetField(ctrl: firstCtrl, label: 'First Name', icon: Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _SheetField(ctrl: lastCtrl,  label: 'Last Name',  icon: Icons.person_outline)),
                  ],
                ),
                const SizedBox(height: 12),
                _SheetField(ctrl: phoneCtrl, label: 'Phone', icon: Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 12),
                _SheetField(ctrl: emailCtrl, label: 'Email (optional)', icon: Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: _kTextGray),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: _kTextGray),
                      onPressed: () => setSheet(() => obscure = !obscure),
                    ),
                    filled: true, fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                ),
                const SizedBox(height: 16),
                // Branch assignment dropdown
                const Text('Assign to Branch',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextDark)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: selectedBranchId,
                      hint: const Text('No branch (assign later)', style: TextStyle(color: _kTextGray)),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No branch (assign later)'),
                        ),
                        ..._branches.map((b) => DropdownMenuItem<int?>(
                          value: b['id'] as int,
                          child: Text('${b['name']} — ${b['region']}'),
                        )),
                      ],
                      onChanged: (v) => setSheet(() => selectedBranchId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (firstCtrl.text.trim().isEmpty) { _snack('First name required', error: true); return; }
                      if (phoneCtrl.text.trim().isEmpty) { _snack('Phone required', error: true); return; }
                      if (passCtrl.text.length < 6) { _snack('Password must be 6+ characters', error: true); return; }
                      Navigator.pop(ctx);
                      try {
                        final provider = Provider.of<AppProvider>(context, listen: false);
                        await provider.createAdminUser(
                          firstName: firstCtrl.text.trim(),
                          lastName:  lastCtrl.text.trim(),
                          phone:     phoneCtrl.text.trim(),
                          email:     emailCtrl.text.trim(),
                          password:  passCtrl.text,
                          branchId:  selectedBranchId,
                        );
                        _snack('Admin created');
                        _load();
                      } on ApiException catch (e) {
                        _snack(e.message, error: true);
                      } catch (e) {
                        _snack('Failed to create admin', error: true);
                      }
                    },
                    child: const Text('Create Admin',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    firstCtrl.dispose(); lastCtrl.dispose(); phoneCtrl.dispose();
    emailCtrl.dispose(); passCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_admin',
            onPressed: () => _showCreateAdminSheet(null),
            backgroundColor: _kBlue,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Admin', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_branch',
            onPressed: _showCreateBranchSheet,
            backgroundColor: _kPrimary,
            icon: const Icon(Icons.add_location_alt, color: Colors.white),
            label: const Text('Branch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: _kPrimary,
              title: const Text('Branch Management',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add_outlined, color: Colors.white),
                  tooltip: 'Create Admin',
                  onPressed: () => _showCreateAdminSheet(null),
                ),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _kPrimary)))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _kRed, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: _kRed)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_branches.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_city_outlined, size: 56, color: _kTextGray),
                      SizedBox(height: 12),
                      Text('No branches yet', style: TextStyle(color: _kTextGray, fontSize: 16)),
                      SizedBox(height: 6),
                      Text('Tap "Branch" below to create the first one',
                          style: TextStyle(color: _kTextGray, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _BranchCard(
                      branch: _branches[i],
                      onCreateAdmin: () => _showCreateAdminSheet(_branches[i]['id'] as int),
                      onDeleteAdmin: () async {
                        final branch = _branches[i];
                        final admin = branch['assigned_admin'] as Map<String, dynamic>?;
                        if (admin == null) return;
                        final adminId = admin['id'] as int?;
                        if (adminId == null) return;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Admin?'),
                            content: Text('Delete "${admin['name']}"? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _kRed))),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        try {
                          await ApiService.delete(ApiConstants.superAdminDeleteAdmin(adminId));
                          _snack('Admin deleted');
                          _load();
                        } catch (_) {
                          _snack('Failed to delete admin', error: true);
                        }
                      },
                      onDelete: () async {
                        final id = _branches[i]['id'] as int;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Branch?'),
                            content: Text(
                                'Delete "${_branches[i]['name']}"? Admins assigned to it will be unassigned.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: _kRed))),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        try {
                          // ignore: use_build_context_synchronously
                          final provider = Provider.of<AppProvider>(context, listen: false);
                          await provider.deleteBranch(id);
                          _snack('Branch deleted');
                          _load();
                        } catch (_) {
                          _snack('Failed to delete branch', error: true);
                        }
                      },
                    ),
                    childCount: _branches.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.onCreateAdmin,
    required this.onDelete,
    this.onDeleteAdmin,
  });
  final Map<String, dynamic> branch;
  final VoidCallback onCreateAdmin;
  final VoidCallback onDelete;
  final VoidCallback? onDeleteAdmin;

  @override
  Widget build(BuildContext context) {
    final assignedAdmin = branch['assigned_admin'] as Map<String, dynamic>?;
    final adminCount    = branch['admin_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_city, color: _kPrimary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kTextDark)),
                      const SizedBox(height: 2),
                      Text('${branch['region']}, ${branch['country']}',
                          style: const TextStyle(color: _kTextGray, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, size: 16, color: _kTextGray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        branch['address'] != null && (branch['address'] as String).isNotEmpty
                            ? branch['address'] as String
                            : 'Lat ${(branch['lat'] as num?)?.toStringAsFixed(4)}, '
                              'Lng ${(branch['lng'] as num?)?.toStringAsFixed(4)}',
                        style: const TextStyle(color: _kTextGray, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 16, color: _kTextGray),
                    const SizedBox(width: 6),
                    Text('Service radius: ${branch['service_radius_km']} km',
                        style: const TextStyle(color: _kTextGray, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (branch['is_active'] as bool? ?? true)
                            ? _kAccent.withValues(alpha: 0.15)
                            : _kRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (branch['is_active'] as bool? ?? true) ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (branch['is_active'] as bool? ?? true) ? _kAccent : _kRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Admin section
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 16, color: _kTextGray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: assignedAdmin != null
                          ? Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(assignedAdmin['name'] as String? ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextDark)),
                                      Text(assignedAdmin['phone'] as String? ?? '',
                                          style: const TextStyle(color: _kTextGray, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (onDeleteAdmin != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: _kRed, size: 18),
                                    tooltip: 'Delete admin',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: onDeleteAdmin,
                                  ),
                              ],
                            )
                          : const Text('No admin assigned',
                              style: TextStyle(color: _kTextGray, fontSize: 13)),
                    ),
                    TextButton.icon(
                      onPressed: onCreateAdmin,
                      icon: Icon(
                        adminCount > 0 ? Icons.person_add_outlined : Icons.person_add,
                        size: 16,
                        color: _kPrimary,
                      ),
                      label: Text(
                        adminCount > 0 ? 'Add Admin' : 'Assign Admin',
                        style: const TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
  });
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: _kTextGray),
      filled: true, fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
    ),
  );
}
