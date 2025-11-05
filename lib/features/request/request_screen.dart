import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RequestScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const RequestScreen({super.key, required this.onBackToHome});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late Future<Map<String, dynamic>?> _requestStatusFuture;
  Map<String, dynamic>? _currentRequestData;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _requestStatusFuture = _fetchRequestStatus();
  }

  // ดึงสถานะล่าสุด
  Future<Map<String, dynamic>?> _fetchRequestStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('userId');
    if (studentId == null) {
      // ไม่เจอ ID 
      throw Exception('User ID not found. Please login again.');
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      print(
        'ERROR: .env file not found or API_BASE_URL is missing',
      );
      throw Exception('Config error: API URL not found.');
    }
    final url = Uri.parse(
      '$baseUrl/my-request-status/$studentId',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data == null) {
          return null;
        } else {
          _currentRequestData = data;
          return data;
        }
      } else {
        throw Exception('Failed to load status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch status: ${e.toString()}');
    }
  }

  // ยกเลิก Request (เรียก API DELETE)
  Future<void> _cancelRequest() async {
    if (_currentRequestData == null ||
        _currentRequestData!['request_id'] == null ||
        _isCancelling) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    final requestId = _currentRequestData!['request_id'];

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      print(
        'ERROR: .env file not found or API_BASE_URL is missing',
      );
      throw Exception('Config error: API URL not found.');
    }
    final url = Uri.parse(
      '$baseUrl/borrow-request/$requestId',
    );

    try {
      final response = await http.delete(url);

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _requestStatusFuture =
              _fetchRequestStatus();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['message'] ?? 'Failed to cancel request.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackBar('Connection error: ${e.toString()}');
    } finally {
      if (context.mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  // _showCancelConfirmationDialog ให้เรียก _cancelRequest
  void _showCancelConfirmationDialog() {
    // เช็คก่อนว่ามี Request ให้ยกเลิกไหม และสถานะเป็น Pending หรือเปล่า
    if (_currentRequestData == null ||
        _currentRequestData!['status'] != 'Pending') {
      _showErrorSnackBar('This request cannot be cancelled.');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content: const Text('Are you sure you want to cancel this request?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Yes, Cancel',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _cancelRequest();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null || end == null) return "N/A";
    try {
      final DateFormat dbFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
      final DateFormat displayFormat = DateFormat(
        "MMM dd, yyyy",
      );

      final startDate = dbFormat.parse(start, true).toLocal();
      final endDate = dbFormat.parse(end, true).toLocal();

      return "${displayFormat.format(startDate)} - ${displayFormat.format(endDate)}";
    } catch (e) {
      return "Invalid Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Check Request',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _requestStatusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return _buildNoRequestView();
            }

            final requestData = snapshot.data!;
            final status = requestData['status'] ?? 'Unknown';
            final reason = requestData['disapprove_reason'];

            Widget actionButton;
            if (status == 'Pending') {
              actionButton = _buildCancelButton();
            } else {
              actionButton = _buildBackToHomeButton();
            }

            return _buildRequestView(
              itemName: requestData['product_name'] ?? 'No Name',
              itemSubtitle:
                  (requestData['product_detail'] as String?)
                      ?.split('\n')
                      .first ??
                  'No Detail',
              itemImage: requestData['image_url'] ?? 'assets/ps4.png',
              requestDate: _formatDateRange(
                requestData['borrow_start_date'],
                requestData['borrow_end_date'],
              ),
              status: status,
              reason: reason,
              button: actionButton,
            );
          },
        ),
      ),
    );
  }


  Widget _buildRequestView({
    required String itemName,
    required String itemSubtitle,
    required String itemImage,
    required String requestDate,
    required String status,
    required Widget button,
    String? reason,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(
          itemName: itemName,
          itemSubtitle: itemSubtitle,
          itemImage: itemImage,
          requestDate: requestDate,
          status: status,
          reason: reason,
        ),
        const SizedBox(height: 24),
        button,
      ],
    );
  }

  Widget _buildNoRequestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Active Requests',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Your pending requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // _buildStatusCard Status/Reason/Image จาก API
  Widget _buildStatusCard({
    required String itemName,
    required String itemSubtitle,
    required String itemImage,
    required String requestDate,
    required String status,
    String? reason,
  }) {
    Color statusColor;
    Color statusTextColor = Colors.white;
    String displayStatus;

    switch (status) {
      case 'Approved':
        statusColor =  Colors.green;
        displayStatus = 'Approved';
        break;
      case 'Disapproved':
        statusColor = Colors.grey;
        displayStatus = 'Disapproved';
        break;
      case 'Pending':
        statusColor = Colors.yellow;
        displayStatus = 'Pending Approval';
        statusTextColor = Colors.black;
        break;
      case 'Returned':
        statusColor = Colors.blueGrey;
        displayStatus = 'Returned';
        break;
      default:
        statusColor = Colors.grey;
        displayStatus = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildItemImage(itemImage),
          const SizedBox(height: 16),
          Text(
            itemName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            itemSubtitle,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              displayStatus,
              style: TextStyle(
                color: statusTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Requested: $requestDate',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Reason: $reason',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String imagePath) {
    Widget imageWidget;
    if (imagePath.startsWith('http')) {
      imageWidget = Image.network(
        imagePath,
        height: 150,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stack) =>
            Icon(Icons.broken_image, size: 80, color: Colors.grey[400]),
      );
    } else {
      imageWidget = Image.asset(
        imagePath,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            Icon(Icons.image_not_supported, size: 80, color: Colors.grey[400]),
      );
    }
    return SizedBox(height: 150, child: Center(child: imageWidget));
  }

  Widget _buildCancelButton() {
    return ElevatedButton(
      onPressed: _isCancelling
          ? null
          : _showCancelConfirmationDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF44336),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        elevation: 0,
      ),
      child:
          _isCancelling
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Text(
              'Cancel Request',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
    );
  }

  Widget _buildBackToHomeButton() {
    return ElevatedButton(
      onPressed: widget.onBackToHome,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        elevation: 0,
      ),
      child: const Text(
        'Back To Home',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
