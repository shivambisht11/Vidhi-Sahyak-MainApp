import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'Guest User'),
            accountEmail: Text(user?.email ?? 'Not logged in'),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : const AssetImage('assets/default_user.png')
                        as ImageProvider,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text("Chat History"),
            onTap: () {
              // navigate to chat history
            },
          ),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text("Login"),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (result != null) {
                  setState(() => user = FirebaseAuth.instance.currentUser);
                }
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                setState(() => user = null);
              },
            ),
        ],
      ),
    );
  }
}
