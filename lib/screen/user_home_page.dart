import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
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

  // Add user name variable
  String _userName = '';

  @override
  void initState() {
    super.initState();
    // Debug image paths
    _checkImagePaths();
    _loadUserSelections(); // Add this line
    _loadUserName(); // Add this line
  }

  void _checkImagePaths() {
    for (var meal in mealStates) {
      debugPrint('Checking image path: ${meal.image}');
      try {
        // Attempt to check if the file exists (this works differently in web vs mobile)
        if (Platform.isAndroid || Platform.isIOS) {
          File(meal.image).existsSync();
        }
      } catch (e) {
        debugPrint('Error checking image path ${meal.image}: $e');
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Welcome $_userName', // Updated to show username
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.white),
                  onPressed: _handleLogout,
                ),
                SizedBox(width: 8), // Add some padding after the logout button
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Please select your meals for today:',
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

  Widget _buildMealCard(MealState mealState) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          // Meal Image
          ClipRRect(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
            child: Image.asset(
              mealState.image,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image load error for ${mealState.image}: $error');
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey,
                  child: Center(
                    child: Text(
                      'No Image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),

          // Meal Title
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                mealState.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Toggle Switch Section
          Container(
            margin: EdgeInsets.only(right: 16),
            child: Switch(
              value: mealState.isSelected,
              onChanged: (bool value) {
                setState(() {
                  mealState.isSelected = value;
                  _updateFirestore(mealState);
                });
              },
              activeColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // Update the _updateFirestore method
  Future<void> _updateFirestore(MealState mealState) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final today = now.toIso8601String().split('T')[0];

        // Check time restrictions (6 PM to 9 PM)
        if (now.hour < 18 || now.hour >= 21) {
          //now.hour < 18 || now.hour >= 21
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Selections are only allowed between 6 PM and 9 PM'),
            ),
          );
          setState(() {
            mealState.isSelected = !mealState.isSelected;
          });
          return;
        }

        final mealRef =
            FirebaseFirestore.instance.collection('meal_counts').doc(today);

        // Get current document and user data
        final docSnapshot = await mealRef.get();
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userName = userData.data()?['username'] ?? 'Unknown User';
        final currentData = docSnapshot.data() ?? {};
        final mealData = currentData[mealState.title.toLowerCase()] ??
            {
              'total_count': 0,
              'users': {},
              'userNames': [],
            };

        // Update the meal data
        final users = (mealData['users'] as Map<String, dynamic>?) ?? {};
        final userNames = List<String>.from(mealData['userNames'] ?? []);

        users[user.uid] = mealState.isSelected;

        if (mealState.isSelected && !userNames.contains(userName)) {
          userNames.add(userName);
        } else if (!mealState.isSelected) {
          userNames.remove(userName);
        }

        // Update Firestore
        await mealRef.set({
          mealState.title.toLowerCase(): {
            'users': users,
            'userNames': userNames,
            'total_count': userNames.length,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating meal selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meal selection: $e')),
      );
      setState(() {
        mealState.isSelected = !mealState.isSelected;
      });
    }
  }

  // Add this method to _UserHomePageState class
  Future<void> _loadUserSelections() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final doc = await FirebaseFirestore.instance
            .collection('meal_counts')
            .doc(today)
            .get();

        if (doc.exists) {
          setState(() {
            for (var meal in mealStates) {
              final mealData = doc.data()?[meal.title.toLowerCase()];
              if (mealData != null) {
                meal.isSelected = mealData['users']?[user.uid] ?? false;
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading user selections: $e');
    }
  }

  // Update the _loadUserName method in _UserHomePageState
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
}

class MealState {
  final String title;
  final String image;
  bool isSelected;

  MealState({
    required this.title,
    required this.image,
    this.isSelected = false,
  });
}
