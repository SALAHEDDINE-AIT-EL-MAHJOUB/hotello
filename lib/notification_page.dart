import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _isLoading = false;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _initFCM();
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      Map<String, dynamic> data = message.data;

      String title = notification?.title ?? data['title'] ?? 'New Notification';
      String body = notification?.body ?? data['message'] ?? 'You have a new message.';
      String id = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      String typeStr = data['type'] ?? 'info';
      
      NotificationType type = NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == typeStr.toLowerCase(),
        orElse: () => NotificationType.info,
      );

      final newNotification = NotificationItem(
        id: id,
        title: title,
        message: body,
        timestamp: DateTime.now(),
        isRead: false,
        type: type,
      );

      if (mounted) {
        setState(() {
          _notifications.insert(0, newNotification);
          _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state via notification: ${message.data}');
      }
    });
    
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background via notification: ${message.data}');
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<NotificationItem> allNotifications = [];
      
      // Add default system notifications
      allNotifications.addAll([
        NotificationItem(
          id: '1',
          title: 'Welcome to Hotello!',
          message: 'Thank you for joining Hotello. Start exploring the best hotels around the world.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          isRead: false,
          type: NotificationType.info,
        ),
        NotificationItem(
          id: '2',
          title: 'Special Discount!',
          message: 'Get 20% off on your first booking with code WELCOME20.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          type: NotificationType.promotion,
        ),
      ]);
      
      // Fetch user's booking data from Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final bookingsSnapshot = await FirebaseDatabase.instance
            .ref('bookings')
            .orderByChild('userId')
            .equalTo(user.uid)
            .get();

        if (bookingsSnapshot.exists) {
          final bookingsData = bookingsSnapshot.value as Map<dynamic, dynamic>;
          bookingsData.forEach((key, value) {
            final checkIn = DateTime.fromMillisecondsSinceEpoch(value['checkIn']);
            final checkOut = DateTime.fromMillisecondsSinceEpoch(value['checkOut']);
            final hotelName = value['hotelName'] ?? 'Unknown Hotel';
            final status = value['status'] ?? 'pending';
            
            // Only add reminder notifications for confirmed bookings
            if (status == 'confirmed') {
              // Create reminder for upcoming check-in (if it's within the next 3 days)
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final checkInDateOnly = DateTime(checkIn.year, checkIn.month, checkIn.day);
              
              final daysUntilCheckIn = checkInDateOnly.difference(today).inDays;

              if (daysUntilCheckIn >= 0 && daysUntilCheckIn <= 3) {
                allNotifications.add(
                  NotificationItem(
                    id: 'booking-reminder-$key',
                    title: 'Upcoming Reservation Reminder',
                    message: 'Your stay at $hotelName is coming up in $daysUntilCheckIn ${daysUntilCheckIn == 1 ? 'day' : 'days'}.',
                    timestamp: DateTime.now().subtract(Duration(hours: daysUntilCheckIn +1)), // Ajuster pour l'ordre
                    isRead: false,
                    type: NotificationType.booking,
                  ),
                );
              }
              
              // Create notification for check-in day
              if (daysUntilCheckIn == 0) {
                allNotifications.add(
                  NotificationItem(
                    id: 'checkin-$key',
                    title: 'Check-in Today!',
                    message: 'Today is your check-in at $hotelName. We hope you have a wonderful stay!',
                    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                    isRead: false,
                    type: NotificationType.booking,
                  ),
                );
              }

              // Create notification for check-out day
              final checkOutDateOnly = DateTime(checkOut.year, checkOut.month, checkOut.day);
              if (checkOutDateOnly.isAtSameMomentAs(today)) {
                 allNotifications.add(
                  NotificationItem(
                    id: 'checkout-$key',
                    title: 'Check-out Today',
                    message: 'Remember to check out from $hotelName today. We hope you enjoyed your stay!',
                    timestamp: DateTime.now().subtract(const Duration(milliseconds: 500)), // S'assurer qu'il est légèrement plus récent
                    isRead: false,
                    type: NotificationType.booking,
                  ),
                );
              }
            }
          });
        }
      }
      
      // Sort notifications by timestamp (newest first)
      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) { // Added mounted check for safety
        setState(() {
          _notifications = allNotifications;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) { // Added mounted check for safety
        setState(() {
          _isLoading = false;
          _notifications = []; // Empty list in case of error
        });
      }
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((item) => item.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _notifications = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Notifications'),
                    content: const Text('Are you sure you want to clear all notifications?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearAll();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no notifications at this time',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final unreadCount = _notifications.where((item) => !item.isRead).length;
    
    return Column(
      children: [
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.deepPurple.shade50,
            child: Row(
              children: [
                Text(
                  '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _notifications = _notifications.map((item) => 
                        item.copyWith(isRead: true)).toList();
                    });
                  },
                  child: const Text('Mark all as read'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _buildNotificationItem(notification);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return InkWell(
      onTap: () {
        _markAsRead(notification.id);
        
        // Show notification details
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getNotificationIcon(notification.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  notification.message,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : Colors.blue.shade50,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: _getNotificationIcon(notification.type),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _getNotificationIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;
    
    switch (type) {
      case NotificationType.info:
        iconData = Icons.info;
        iconColor = Colors.blue;
        break;
      case NotificationType.promotion:
        iconData = Icons.local_offer;
        iconColor = Colors.orange;
        break;
      case NotificationType.account:
        iconData = Icons.person;
        iconColor = Colors.green;
        break;
      case NotificationType.booking:
        iconData = Icons.hotel;
        iconColor = Colors.deepPurple;
        break;
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(
        iconData,
        color: iconColor,
        size: 16,
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

enum NotificationType {
  info,
  promotion,
  account,
  booking,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}