import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../utils/parse_utils.dart';

const Color _kBg = Color(0xFFF0F7F0);
const Color _kPrimary = Color(0xFF2E7D32);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class ScheduledPickupsPage extends StatefulWidget {
  const ScheduledPickupsPage({super.key});

  @override
  State<ScheduledPickupsPage> createState() => _ScheduledPickupsPageState();
}

class _ScheduledPickupsPageState extends State<ScheduledPickupsPage> {
  Timer? _ticker;
  final Set<int> _triggeredIds = {};
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reload();
      if (mounted) {
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {});
            _checkDue();
          }
        });
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await context.read<AppProvider>().fetchSchedules();
    } catch (e) {
      if (mounted) {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration? _remaining(Map<String, dynamic> item) {
    final dtStr = item['pickup_datetime'] as String?;
    if (dtStr == null || dtStr.isEmpty) return null;
    try {
      final dt = DateTime.parse(dtStr).toLocal();
      return dt.difference(DateTime.now());
    } catch (_) {
      return null;
    }
  }

  void _checkDue() {
    final items = context.read<AppProvider>().scheduledPickups;
    for (final item in items) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (_triggeredIds.contains(id)) continue;
      final status = (item['status'] as String?) ?? 'pending';
      if (status != 'pending') continue;
      final rem = _remaining(item);
      if (rem == null) continue;
      if (rem.inSeconds <= 0) {
        _triggeredIds.add(id);
        _triggerFindCollector(id, item);
      }
    }
  }

  Future<void> _triggerFindCollector(
      int id, Map<String, dynamic> item) async {
    final provider = context.read<AppProvider>();
    await SoundService.playNotification();
    await NotificationService.show(
      'Scheduled Pickup Active',
      'Finding a collector for your ${item['wasteType']} pickup...',
      id: 300 + id,
    );
    try {
      await provider.triggerSchedule(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collector search started for your ${item['wasteType']} pickup.',
          ),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      _triggeredIds.remove(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelSchedule(int id) async {
    try {
      await context.read<AppProvider>().cancelSchedule(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule cancelled'),
            backgroundColor: _kPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _formatDateLabel(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      const days = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final pickups = provider.scheduledPickups;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Schedules',
          style: TextStyle(
              color: _kTextDark,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kPrimary),
            onPressed: _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimary))
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : pickups.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              size: 64, color: _kTextGray),
                          SizedBox(height: 16),
                          Text(
                            'No scheduled pickups yet',
                            style:
                                TextStyle(color: _kTextGray, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Schedule a pickup to see it here',
                            style:
                                TextStyle(color: _kTextGray, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: pickups.length,
                      itemBuilder: (context, index) => _ScheduleCard(
                        item: pickups[index],
                        remaining: _remaining(pickups[index]),
                        formattedDate: _formatDateLabel(
                            pickups[index]['date'] as String?),
                        onCancel: () => _cancelSchedule(
                            (pickups[index]['id'] as num).toInt()),
                        onTrack: () async {
                          final provider = context.read<AppProvider>();
                          await provider.loadActiveRequest();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/home', (route) => false);
                          }
                        },
                      ),
                    ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Duration? remaining;
  final String formattedDate;
  final VoidCallback onCancel;
  final VoidCallback onTrack;

  const _ScheduleCard({
    required this.item,
    required this.remaining,
    required this.formattedDate,
    required this.onCancel,
    required this.onTrack,
  });

  Color _countdownColor() {
    if (remaining == null) return _kTextGray;
    if (remaining!.isNegative) return Colors.red;
    if (remaining!.inMinutes < 15) return Colors.red;
    if (remaining!.inMinutes < 60) return const Color(0xFFF57C00);
    return _kPrimary;
  }

  String _countdownText() {
    if (remaining == null) return '—';
    if (remaining!.isNegative) return 'NOW!';
    final d = remaining!;
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _frequencyLabel(String freq) {
    switch (freq.toLowerCase()) {
      case 'biweekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'once':
        return 'One-time';
      default:
        return freq;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Scheduled';
      case 'finding':
        return 'Finding Collector…';
      case 'assigned':
        return 'Collector Assigned';
      case 'on_way':
        return 'Collector On Way';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _kPrimary;
      case 'cancelled':
        return Colors.red;
      case 'finding':
        return const Color(0xFFF57C00);
      case 'assigned':
      case 'on_way':
        return const Color(0xFF1565C0);
      default:
        return _kTextGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _countdownColor();
    final status = (item['status'] as String?) ?? 'pending';
    final isRecurring = (item['isRecurring'] as bool?) ?? false;
    final freq = (item['frequency'] as String?) ?? 'once';
    final price = item['price'];
    final binTypeName = (item['binTypeName'] as String?) ?? '';
    final wasteType = (item['wasteType'] as String?) ?? 'General';
    final time = (item['time'] as String?) ?? '';
    final isNow = remaining != null && remaining!.isNegative;
    final isUrgent = remaining != null &&
        !remaining!.isNegative &&
        remaining!.inMinutes < 15;
    final canCancel = status == 'pending';

    String shortDay = '';
    final dateStr = item['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr);
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        shortDay = days[dt.weekday - 1];
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNow
            ? const Color(0xFFFFF3E0)
            : isUrgent
                ? const Color(0xFFFFF8F8)
                : _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNow
              ? const Color(0xFFFFCC80)
              : isUrgent
                  ? const Color(0xFFFFCDD2)
                  : const Color(0xFFE8F5E9),
          width: isNow || isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (shortDay.isNotEmpty)
                      Text(
                        shortDay,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    Icon(Icons.calendar_month, color: color, size: 20),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wasteType,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kTextDark),
                    ),
                    if (binTypeName.isNotEmpty)
                      Text(
                        binTypeName,
                        style: const TextStyle(
                            color: _kTextGray, fontSize: 12),
                      ),
                    Text(
                      formattedDate.isNotEmpty
                          ? '$formattedDate  ·  $time'
                          : time,
                      style: const TextStyle(
                          color: _kTextGray, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(price, prefix: 'GH₵', fallback: 'GH₵ 0.00'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _kPrimary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'pending' || status == 'finding') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isNow ? Icons.alarm_on_outlined : Icons.timer_outlined,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isNow ? 'Finding collector now!' : 'Pickup in: ',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  if (!isNow)
                    Text(
                      _countdownText(),
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (status == 'assigned' ||
              status == 'on_way' ||
              status == 'arrived') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTrack,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Track & Pay on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(
                isRecurring ? Icons.refresh : Icons.event,
                size: 14,
                color: _kTextGray,
              ),
              const SizedBox(width: 6),
              Text(
                isRecurring
                    ? 'Recurring: ${_frequencyLabel(freq)}'
                    : 'One-time pickup',
                style: const TextStyle(color: _kTextGray, fontSize: 12),
              ),
              const Spacer(),
              if (canCancel)
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
