import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart'; // Add this package
import '../hr/offer_detail_screen.dart';
import '../hr/offer_analytics_screen.dart';
import '../../services/offer_service.dart';
import '../../models/offer.dart';
import 'approval_queue_screen.dart';
import '../hiring_manager/pipeline_page.dart';

class HRDashboard extends StatefulWidget {
  final String token;
  const HRDashboard({super.key, required this.token});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  int _selectedIndex = 0;
  final OfferService _offerService = OfferService();
  Map<String, dynamic> _dashboardStats = {};
  List<Offer> _pendingOffers = [];
  List<Offer> _sentOffers = [];
  bool _isLoading = true;

  final List<String> _pages = [
    'Dashboard',
    'Offer Management',
    'Employees',
    'Recruitment',
    'Reports',
    'Settings'
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.description,
    Icons.people,
    Icons.how_to_reg,
    Icons.bar_chart,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load pending offers
      final pending = await _offerService.getOffersByStatus('reviewed');

      // Load sent offers
      final sent = await _offerService.getOffersByStatus('sent');

      // Get analytics
      final analytics = await _offerService.getOfferAnalytics();

      setState(() {
        _pendingOffers = pending;
        _sentOffers = sent;
        _dashboardStats = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    bool isDesktop = size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // ---------------- Sidebar ----------------
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.grey[900],
              selectedIconTheme: const IconThemeData(color: Colors.redAccent),
              selectedLabelTextStyle: const TextStyle(color: Colors.redAccent),
              unselectedIconTheme: const IconThemeData(color: Colors.white70),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
              leading: Column(
                children: [
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HR Manager',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationsBadge(),
                ],
              ),
              destinations: List.generate(
                _pages.length,
                (index) => NavigationRailDestination(
                  icon: Icon(_icons[index]),
                  selectedIcon: Icon(_icons[index]),
                  label: Text(_pages[index]),
                ),
              ),
            ),

          // ---------------- Main Content ----------------
          Expanded(
            child: Column(
              children: [
                // ---------- Navbar ----------
                Container(
                  height: 60,
                  color: Colors.grey[850],
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _pages[_selectedIndex],
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _loadDashboardData,
                            icon:
                                const Icon(Icons.refresh, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          _buildNotificationsBadge(isMobile: true),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child:
                                const Icon(Icons.person, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---------- Dashboard Body ----------
                Expanded(
                  child: Container(
                    color: Colors.grey[900],
                    width: double.infinity,
                    child: _buildPageContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Mobile Drawer for small screens
      drawer: !isDesktop
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child:
                              const Icon(Icons.person, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'HR Manager',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildNotificationsBadge(),
                      ],
                    ),
                  ),
                  ...List.generate(_pages.length, (index) {
                    return ListTile(
                      leading: Icon(_icons[index]),
                      title: Text(_pages[index]),
                      selected: _selectedIndex == index,
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildPageContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent,
        ),
      );
    }

    switch (_selectedIndex) {
      case 0: // Dashboard
        return _buildDashboard();
      case 1: // Offer Management
        return const HRApprovalQueueScreen();
      case 2: // Employees
        return _buildPlaceholderPage('Employees Management');
      case 3: // Recruitment
        return RecruitmentPipelinePage(token: widget.token);

      case 4: // Reports
        return OfferAnalyticsScreen(stats: _dashboardStats);
      case 5: // Settings
        return _buildPlaceholderPage('HR Settings');
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          _buildWelcomeCard(),
          const SizedBox(height: 20),

          // Quick Stats
          _buildQuickStats(),
          const SizedBox(height: 20),

          // Pending Actions
          _buildPendingActions(),
          const SizedBox(height: 20),

          // Recent Offers
          _buildRecentOffers(),
          const SizedBox(height: 20),

          // Analytics Overview
          _buildAnalyticsOverview(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back, HR Manager!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_pendingOffers.length} offers pending approval • ${_sentOffers.length} offers sent',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Review Offers Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final int pending = _pendingOffers.length;
    final int sent = _sentOffers.length;
    final int signed = _dashboardStats['signed'] ?? 0;
    final int total = _dashboardStats['total'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Pending Approval',
          pending.toString(),
          Icons.pending_actions,
          Colors.orange,
          () {
            setState(() {
              _selectedIndex = 1;
            });
          },
        ),
        _buildStatCard(
          'Sent Offers',
          sent.toString(),
          Icons.send,
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HRApprovalQueueScreen(),
              ),
            );
          },
        ),
        _buildStatCard(
          'Signed Offers',
          signed.toString(),
          Icons.assignment_turned_in,
          Colors.green,
          () {
            // Navigate to signed offers
          },
        ),
        _buildStatCard(
          'Total Offers',
          total.toString(),
          Icons.description,
          Colors.purple,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OfferAnalyticsScreen(stats: _dashboardStats),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingActions() {
    if (_pendingOffers.isEmpty) {
      return Container();
    }

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Approval',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Chip(
                  label: Text('${_pendingOffers.length} offers'),
                  backgroundColor: Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingOffers
                .take(3)
                .map(
                  (offer) => _buildPendingOfferItem(offer),
                )
                .toList(),
            if (_pendingOffers.length > 3) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOfferItem(Offer offer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey[700],
      child: ListTile(
        leading: const Icon(Icons.description, color: Colors.orange),
        title: Text(
          offer.candidateName ?? 'Candidate',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          offer.jobTitle ?? 'Position',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (offer.baseSalary != null)
              Text(
                '\$${offer.baseSalary!.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HROfferDetailScreen(offer: offer),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentOffers() {
    final recentOffers = [..._pendingOffers, ..._sentOffers];
    if (recentOffers.isEmpty) {
      return Container();
    }

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Offers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...recentOffers
                .take(5)
                .map(
                  (offer) => _buildRecentOfferItem(offer),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOfferItem(Offer offer) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: offer.statusColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          offer.statusIcon,
          color: offer.statusColor,
          size: 20,
        ),
      ),
      title: Text(
        offer.candidateName ?? 'Candidate',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        '${offer.jobTitle} • ${offer.statusDisplay}',
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: Text(
        offer.createdAt != null
            ? '${offer.createdAt!.toLocal().toString().split(' ')[0]}'
            : '',
        style: const TextStyle(color: Colors.white70),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HROfferDetailScreen(offer: offer),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsOverview() {
    final double sentRate = _dashboardStats['sent_rate'] ?? 0.0;
    final double signedRate = _dashboardStats['signed_rate'] ?? 0.0;
    final double avgTimeToSign = _dashboardStats['avg_time_to_sign'] ?? 0.0;

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OfferAnalyticsScreen(stats: _dashboardStats),
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Sent Rate',
                    '${(sentRate * 100).toStringAsFixed(1)}%',
                    Icons.send,
                    Colors.blue,
                    sentRate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Signed Rate',
                    '${(signedRate * 100).toStringAsFixed(1)}%',
                    Icons.assignment_turned_in,
                    Colors.green,
                    signedRate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimeMetricCard(avgTimeToSign),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double percentage,
  ) {
    return Card(
      color: Colors.grey[700],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              animation: true,
              lineHeight: 8,
              animationDuration: 1000,
              percent: percentage,
              progressColor: color,
              backgroundColor: Colors.grey[600]!,
              barRadius: const Radius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetricCard(double avgDays) {
    return Card(
      color: Colors.grey[700],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timelapse, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Average Time to Sign',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${avgDays.toStringAsFixed(1)} days',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'From offer sent to candidate signature',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _icons[_selectedIndex],
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This section is under development',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsBadge({bool isMobile = false}) {
    final pendingCount = _pendingOffers.length;

    if (pendingCount == 0) {
      return isMobile
          ? Container()
          : const Icon(Icons.notifications_none, color: Colors.white70);
    }

    return Badge(
      label: Text(pendingCount.toString()),
      backgroundColor: Colors.red,
      textColor: Colors.white,
      child: Icon(
        isMobile ? Icons.notifications : Icons.notifications_active,
        color: isMobile ? Colors.white : Colors.white70,
      ),
    );
  }
}
