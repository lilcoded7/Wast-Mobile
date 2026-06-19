import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';

const Color _kPrimary = Color(0xFF2E7D32);
const Color _kBg = Color(0xFFF0F7F0);
const Color _kCard = Colors.white;
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGray = Color(0xFF757575);

class CollectorHelpSupportPage extends StatefulWidget {
  const CollectorHelpSupportPage({super.key});

  @override
  State<CollectorHelpSupportPage> createState() =>
      _CollectorHelpSupportPageState();
}

class _CollectorHelpSupportPageState extends State<CollectorHelpSupportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _kPrimary,
          unselectedLabelColor: _kTextGray,
          indicatorColor: _kPrimary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'FAQ'), Tab(text: 'Chat Support')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_FaqTab(onLaunch: _launch), _ChatTab()],
      ),
    );
  }
}

// ── FAQ tab ────────────────────────────────────────────────────────────────────
class _FaqTab extends StatelessWidget {
  final Future<void> Function(String) onLaunch;
  const _FaqTab({required this.onLaunch});

  static const _faqs = [
    (
      q: 'How do I get more pickup requests?',
      a: 'Stay online and keep a high rating. The system auto-matches the nearest available collector. Make sure your GPS is enabled.',
    ),
    (
      q: 'What is the 3.5% commission?',
      a: 'Bɔla Aba charges a small commission on cash collections. You can settle debt automatically during withdrawal.',
    ),
    (
      q: 'How do I withdraw my earnings?',
      a: 'Go to Earnings → Withdrawal. Make sure you have no outstanding commission owed before requesting a withdrawal. Funds arrive within 24 hours via MoMo.',
    ),
    (
      q: 'My account is pending approval. What do I do?',
      a: 'After registering, your account is reviewed by the Bɔla Aba team. Approval usually takes 1–2 business days.',
    ),
    (
      q: 'How is my rating calculated?',
      a: 'Your rating is the average of all customer ratings (1–5 stars) you have received. Arrive on time and handle waste professionally to maintain a high score.',
    ),
    (
      q: 'What happens if I miss a scheduled pickup?',
      a: 'You will receive a countdown notification before the scheduled time. If you miss the pickup, the customer is notified and your rating may be affected.',
    ),
    (
      q: 'How do I update my vehicle information?',
      a: 'Go to Profile → Vehicle Details. You can update your vehicle type and plate number at any time.',
    ),
    (
      q: 'Can I decline a pickup request?',
      a: 'Yes. If you receive a request you cannot fulfil, tap Decline. The request will be re-matched to another available collector.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact quick links
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kLightGreen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Contact',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ContactBtn(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => onLaunch('https://wa.me/233501234567'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ContactBtn(
                      icon: Icons.phone,
                      label: 'Call',
                      color: const Color(0xFF1565C0),
                      onTap: () => onLaunch('tel:+233501234567'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ContactBtn(
                      icon: Icons.email,
                      label: 'Email',
                      color: _kPrimary,
                      onTap:
                          () => onLaunch(
                            'mailto:collector-support@wastepick.com',
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 10),
        ..._faqs.map((f) => _FaqTile(question: f.q, answer: f.a)),
      ],
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question, answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: _kPrimary,
        collapsedIconColor: _kTextGray,
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _kTextDark,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: _kTextGray,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat tab — connected to Bɔla Aba support API ─────────────────────────────
class _ChatTab extends StatefulWidget {
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  int? _ticketId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
      text: 'Hello! Welcome to Bɔla Aba Collector Support. How can we help you today?',
      isMe: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_ChatMsg(text: text, isMe: true));
      _msgCtrl.clear();
    });
    _scroll();
    try {
      final data = _ticketId == null
          ? await ApiService.post(ApiConstants.collectorSupport, {'message': text})
          : await ApiService.post(
              ApiConstants.collectorSupportTicket(_ticketId!),
              {'message': text},
            );
      _ticketId ??= data['ticket_id'] as int?;
      final raw = data['messages'] as List? ?? [];
      setState(() {
        _messages.clear();
        for (final m in raw) {
          final map = m as Map<String, dynamic>;
          _messages.add(_ChatMsg(
            text: map['body'] as String? ?? '',
            isMe: map['is_mine'] as bool? ?? false,
          ));
        }
      });
      _scroll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _BubbleRow(msg: _messages[i]),
          ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 16,
            right: 12,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: const TextStyle(color: _kTextGray),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: _kPrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isMe;
  _ChatMsg({required this.text, required this.isMe});
}

class _BubbleRow extends StatelessWidget {
  final _ChatMsg msg;
  const _BubbleRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isMe ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isMe ? Colors.white : _kTextDark,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
