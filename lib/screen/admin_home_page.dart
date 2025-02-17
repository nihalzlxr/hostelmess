import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:workmanager/workmanager.dart';
import 'dart:async';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // List to track the state of each meal card
  List<MealState> mealStates = [
    MealState(
      title: 'Breakfast',
      image: 'assets/images/breakfast.png',
    ),
    MealState(
      title: 'Lunch',
      image: 'assets/images/lunch.png', // Double-check this path
    ),
    MealState(
      title: 'Dinner',
      image: 'assets/images/dinner.png', // Double-check this path
    ),
  ];

  Map<String, int> mealCounts = {
    'Breakfast': 0,
    'Lunch': 0,
    'Dinner': 0,
  };

  // Add StreamSubscription
  StreamSubscription<DocumentSnapshot>? _mealCountsSubscription;

  // Add user name variable
  String _userName = '';

  // Add these variables to _AdminHomePageState class
  Map<String, List<String>> mealUsers = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
  };

  // Add this variable to _AdminHomePageState class
  final TextEditingController _userNameController = TextEditingController();

  // Add selected date variable
  String selectedDate = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _checkImagePaths();
    _verifyAndSetupAdmin();
    _loadUserName(); // Add this line
    // Clean up old data on startup
  }

  void _checkImagePaths() {
    for (var meal in mealStates) {
      debugPrint('Checking image path: ${meal.image}');
      try {} catch (e) {
        debugPrint('Error checking image path ${meal.image}: $e');
      }
    }
  }

  // Update the _checkAdminStatus method
  Future<bool> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if the user ID matches the admin ID
        return user.uid == '2V2EWoZbZ4UWdpwFWjTdN77Ybis2';
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Update the _verifyAndSetupAdmin method
  Future<void> _verifyAndSetupAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final isAdmin = await _checkAdminStatus();
      print('Checking admin status for user ID: ${user.uid}'); // Debug print

      if (isAdmin) {
        print('Admin access granted'); // Debug print
        _setupMealCountsListener();
      } else {
        print('Admin access denied - Not matching admin ID'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Admin privileges required.'),
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('Error in admin verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying admin status: $e')),
      );
    }
  }

  // Update the _setupMealCountsListener method to ensure initial counts are loaded
  void _setupMealCountsListener() {
    // First, get the initial data
    _loadMealData(selectedDate);

    // Then set up the listener for real-time updates
    _mealCountsSubscription?.cancel(); // Cancel existing subscription
    _mealCountsSubscription = FirebaseFirestore.instance
        .collection('meal_counts')
        .doc(selectedDate)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _updateMealData(snapshot);
      }
    });
  }

  // Update the _updateMealData method to handle permissions
  Future<void> _updateMealData(DocumentSnapshot snapshot) async {
    try {
      final isAdmin = await _checkAdminStatus();
      if (!isAdmin) {
        print('Non-admin user attempting to access admin features');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      for (var meal in ['Breakfast', 'Lunch', 'Dinner']) {
        final mealData = data[meal.toLowerCase()] as Map<String, dynamic>?;
        if (mealData != null) {
          setState(() {
            mealCounts[meal] = mealData['total_count'] ?? 0;
            mealUsers[meal] = List<String>.from(mealData['userNames'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error updating meal data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meal data: $e')),
      );
    }
  }

  // Add method to load meal data for specific date
  Future<void> _loadMealData(String date) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('meal_counts')
          .doc(date)
          .get();

      if (docSnapshot.exists) {
        _updateMealData(docSnapshot);
      } else {
        setState(() {
          mealCounts = {
            'Breakfast': 0,
            'Lunch': 0,
            'Dinner': 0,
          };
          mealUsers = {
            'Breakfast': [],
            'Lunch': [],
            'Dinner': [],
          };
        });
      }
    } catch (e) {
      print('Error loading meal data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading meal data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update the _setupDailyReset method in _AdminHomePageState class

  Future<void> _setupDailyReset() async {
    try {
      final now = DateTime.now();

      // Set reset time to 5 PM (17:00)
      final resetTime = DateTime(now.year, now.month, now.day, 17, 0);

      // If it's past 5 PM, schedule for next day
      final targetResetTime =
          now.hour >= 17 ? resetTime.add(Duration(days: 1)) : resetTime;

      final duration = targetResetTime.difference(now);

      // Schedule the reset
      Future.delayed(duration, () async {
        await _resetMealCounts();
        // Setup next day's reset
        _setupDailyReset();
      });

      // Register background task
      await Workmanager().registerPeriodicTask(
        'daily-reset',
        'resetMealCounts',
        frequency: const Duration(days: 1),
        initialDelay: duration,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      print('Error setting up daily reset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting up daily reset: $e')),
      );
    }
  }

  Future<void> _resetMealCounts() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await FirebaseFirestore.instance
          .collection('meal_counts')
          .doc(today)
          .set({
        'breakfast': {'total_count': 0, 'users': {}, 'userNames': []},
        'lunch': {'total_count': 0, 'users': {}, 'userNames': []},
        'dinner': {'total_count': 0, 'users': {}, 'userNames': []},
      });

      // Update local state directly instead of calling _loadMealCounts
      setState(() {
        mealCounts = {
          'Breakfast': 0,
          'Lunch': 0,
          'Dinner': 0,
        };
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal counts reset successfully')),
      );
    } catch (e) {
      print('Error resetting meal counts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting meal counts: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  // Update the _loadUserName method in _AdminHomePageState
  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists && userData.data()?['username'] != null) {
          setState(() {
            _userName = userData.data()?['username'];
          });
          print('Username loaded: $_userName'); // Debug print
        } else {
          print('No username found in database'); // Debug print
        }
      }
    } catch (e) {
      print('Error loading user name: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user name: $e')),
      );
    }
  }

  // Add this method to get last 3 days
  List<String> _getLast3Days() {
    final now = DateTime.now();
    return List.generate(3, (index) {
      final date = now.subtract(Duration(days: index));
      return date.toIso8601String().split('T')[0];
    });
  }

  // Update the build method's AppBar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // This removes the back button
        title: Row(
          children: [
            Text(
              'Welcome $_userName',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(width: 16),
            // Add date selector dropdown
            DropdownButton<String>(
              value: selectedDate,
              dropdownColor: Color(0xFF2C2C2C),
              style: TextStyle(color: Colors.white),
              underline: Container(
                height: 2,
                color: Colors.white70,
              ),
              items: _getLast3Days().map((String date) {
                final now = DateTime.now().toIso8601String().split('T')[0];
                final displayText = date == now ? 'Today' : date;
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(displayText),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedDate = newValue;
                    _loadMealData(newValue); // Add this method
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _setupMealCountsListener,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Todays List of Meals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(height: 25),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: mealStates.length,
                itemBuilder: (context, index) {
                  return _buildMealCard(mealStates[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the _buildMealCard method in _AdminHomePageState class

  Widget _buildMealCard(MealState mealState) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          // Image section (unchanged)
          ClipRRect(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
            child: Image.asset(
              mealState.image,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey,
                  child: Center(
                    child:
                        Text('No Image', style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),

          // Title section (unchanged)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                mealState.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Counter section with + and - buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF3A3A3A),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: Colors.white),
                  onPressed: () => _updateMealCount(mealState.title, -1),
                ),
                Text(
                  '${mealCounts[mealState.title] ?? 0}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.white),
                  onPressed: () => _updateMealCount(mealState.title, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method to _AdminHomePageState class
  Future<void> _updateMealCount(String mealTitle, int change) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final mealRef =
          FirebaseFirestore.instance.collection('meal_counts').doc(today);

      // Update the count in Firestore
      await mealRef.set({
        mealTitle.toLowerCase(): {
          'total_count': FieldValue.increment(change),
        }
      }, SetOptions(merge: true));

      // Update local state
      setState(() {
        mealCounts[mealTitle] = (mealCounts[mealTitle] ?? 0) + change;
      });
    } catch (e) {
      print('Error updating meal count: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meal count: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Cancel the subscription when disposing
    _mealCountsSubscription?.cancel();
    Workmanager().cancelByUniqueName('daily-reset');
    super.dispose();
  }
}

class MealState {
  final String title;
  final String image;

  MealState({
    required this.title,
    required this.image,
  });
}
