import 'package:flutter/material.dart';

void main() {
  runApp(const InstagramProfileApp());
}

class InstagramProfileApp extends StatelessWidget {
  const InstagramProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: const Icon(Icons.keyboard_arrow_left, size: 45, color: Colors.black),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'soil',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Profile Avatar & Numbers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Profile Picture
                const CircleAvatar(
                  radius: 43,
                  backgroundColor: Color(0xFFEFEFEF),
                  backgroundImage: NetworkImage('https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcToWKOjqto4nmfUtgOQTkyscZULfj57_R23WArM9kHwkEjBuaEYhcZD9jc&s=10'),
                ),
                // Stats Section
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('12', 'Posts'),
                      _buildStatColumn('1.2k', 'Followers'),
                      _buildStatColumn('450', 'Following'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Name
            const Text(
              'Sohail',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 4),

            // Bio Body
            const Text(
              'buddha was born in nepal',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActionButton('Follow', isPrimary: true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: _buildActionButton('Message'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: _buildActionButton('Email'),
                ),
                const SizedBox(width: 4),
                Expanded(flex: 1, child: _buildActionButton('...'))
              ],
            ),
          ],
        ),
      ),
    );
  }



  static Widget _buildActionButton(String label, {bool isPrimary = false}) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF0095F6) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  static Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

}