import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class OfferAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> stats;

  const OfferAnalyticsScreen({super.key, required this.stats});

  @override
  _OfferAnalyticsScreenState createState() => _OfferAnalyticsScreenState();
}

class _OfferAnalyticsScreenState extends State<OfferAnalyticsScreen> {
  String _selectedPeriod = 'month'; // month, quarter, year

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Analytics'),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
            },
            items: const [
              DropdownMenuItem(value: 'week', child: Text('This Week')),
              DropdownMenuItem(value: 'month', child: Text('This Month')),
              DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
              DropdownMenuItem(value: 'year', child: Text('This Year')),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildTrendChartSection(),
            const SizedBox(height: 24),
            _buildStatusBreakdown(),
            const SizedBox(height: 24),
            _buildTimelineAnalysis(),
            const SizedBox(height: 24),
            _buildPerformanceMetrics(),
          ],
        ),
      ),
    );
  }

  // ------------------ SUMMARY CARDS ------------------
  Widget _buildSummaryCards() {
    final total = widget.stats['total'] ?? 0;
    final sent = widget.stats['sent'] ?? 0;
    final signed = widget.stats['signed'] ?? 0;
    final pending = widget.stats['pending'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
            'Total Offers', total.toString(), Icons.description, Colors.purple),
        _buildSummaryCard('Pending Approval', pending.toString(),
            Icons.pending_actions, Colors.orange),
        _buildSummaryCard(
            'Sent to Candidates', sent.toString(), Icons.send, Colors.blue),
        _buildSummaryCard('Signed Offers', signed.toString(),
            Icons.assignment_turned_in, Colors.green),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ------------------ TREND CHART ------------------
  Widget _buildTrendChartSection() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Offer Trends',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(height: 300, child: _buildTrendChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    final data = [
      _ChartData('Jan', 12, Colors.blue),
      _ChartData('Feb', 18, Colors.blue),
      _ChartData('Mar', 15, Colors.blue),
      _ChartData('Apr', 22, Colors.blue),
      _ChartData('May', 19, Colors.blue),
      _ChartData('Jun', 25, Colors.blue),
    ];

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(color: Colors.white),
        axisLine: const AxisLine(color: Colors.white70),
      ),
      primaryYAxis: NumericAxis(
        labelStyle: const TextStyle(color: Colors.white),
        axisLine: const AxisLine(color: Colors.white70),
        majorGridLines: const MajorGridLines(color: Colors.white24),
      ),
      series: <CartesianSeries<_ChartData, String>>[
        ColumnSeries<_ChartData, String>(
          dataSource: data,
          xValueMapper: (_ChartData d, _) => d.month,
          yValueMapper: (_ChartData d, _) => d.count,
          color: Colors.blue,
          name: 'Offers',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: Colors.white),
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }

  // ------------------ STATUS BREAKDOWN ------------------
  Widget _buildStatusBreakdown() {
    final breakdown = widget.stats['status_breakdown'] ??
        {
          'draft': 0,
          'reviewed': 0,
          'approved': 0,
          'sent': 0,
          'signed': 0,
          'rejected': 0,
          'expired': 0,
        };

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Breakdown',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            ...breakdown.entries
                .map((entry) => _buildStatusItem(entry.key, entry.value))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String status, int count) {
    Color getStatusColor(String s) {
      switch (s.toLowerCase()) {
        case 'draft':
          return Colors.orange;
        case 'reviewed':
          return Colors.blue;
        case 'approved':
          return Colors.green;
        case 'sent':
          return Colors.purple;
        case 'signed':
          return Colors.teal;
        case 'rejected':
          return Colors.red;
        case 'expired':
          return Colors.grey;
        default:
          return Colors.black;
      }
    }

    final total = widget.stats['total'] ?? 1;
    final percentage = count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: getStatusColor(status),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Text(status.capitalize(),
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              Text('$count (${(percentage * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(getStatusColor(status)),
          ),
        ],
      ),
    );
  }

  // ------------------ TIMELINE ANALYSIS ------------------
  Widget _buildTimelineAnalysis() {
    final avgTimeToReview = widget.stats['avg_time_to_review'] ?? 0.0;
    final avgTimeToApprove = widget.stats['avg_time_to_approve'] ?? 0.0;
    final avgTimeToSign = widget.stats['avg_time_to_sign'] ?? 0.0;

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timeline Analysis',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            _buildTimelineMetric(
                'Average Time to Review',
                '${avgTimeToReview.toStringAsFixed(1)} days',
                'Draft → Review',
                Colors.orange),
            _buildTimelineMetric(
                'Average Time to Approve',
                '${avgTimeToApprove.toStringAsFixed(1)} days',
                'Review → Approved',
                Colors.blue),
            _buildTimelineMetric(
                'Average Time to Sign',
                '${avgTimeToSign.toStringAsFixed(1)} days',
                'Sent → Signed',
                Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineMetric(
      String title, String value, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.timelapse, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // ------------------ PERFORMANCE METRICS ------------------
  Widget _buildPerformanceMetrics() {
    final sentRate = widget.stats['sent_rate'] ?? 0.0;
    final signedRate = widget.stats['signed_rate'] ?? 0.0;
    final acceptanceRate = widget.stats['acceptance_rate'] ?? 0.0;

    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance Metrics',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildPerformanceCard(
                        'Offer Send Rate',
                        '${(sentRate * 100).toStringAsFixed(1)}%',
                        Icons.send,
                        Colors.blue,
                        sentRate)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildPerformanceCard(
                        'Offer Sign Rate',
                        '${(signedRate * 100).toStringAsFixed(1)}%',
                        Icons.assignment_turned_in,
                        Colors.green,
                        signedRate)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPerformanceCard(
                'Overall Acceptance Rate',
                '${(acceptanceRate * 100).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.purple,
                acceptanceRate,
                isFullWidth: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
      String title, String value, IconData icon, Color color, double percentage,
      {bool isFullWidth = false}) {
    return Card(
      color: Colors.grey[700],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(icon, color: color),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white))
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[600],
                valueColor: AlwaysStoppedAnimation<Color>(color)),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String month;
  final int count;
  final Color color;

  _ChartData(this.month, this.count, this.color);
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
