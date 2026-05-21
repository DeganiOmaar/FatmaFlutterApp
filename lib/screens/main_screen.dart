import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pfe/controllers/app_socket_controller.dart';
import 'package:pfe/controllers/main_tab_controller.dart';
import 'package:pfe/screens/home.dart';
import 'package:pfe/screens/client_confirmed_deliveries_screen.dart';
import 'package:pfe/screens/profilescreen.dart';
import 'package:pfe/screens/projects_list_screen.dart';
import 'package:pfe/screens/SuiviProjectScreen.dart';
import 'package:pfe/screens/project_tracking_screen.dart';
import 'package:pfe/service/auth_service.dart';

class MainScreen extends StatefulWidget {
  final String email;
  final String role;
  final String? name;

  const MainScreen({
    super.key,
    required this.email,
    required this.role,
    this.name,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? selectedProject;

  @override
  void initState() {
    super.initState();
    final tabs = Get.put(MainTabController(), permanent: false);
    tabs.setTabIndex = (i) {
      if (!mounted) return;
      setState(() => _currentIndex = i);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapAppSocket());
  }

  @override
  void dispose() {
    if (Get.isRegistered<MainTabController>()) {
      final c = Get.find<MainTabController>();
      c.setTabIndex = null;
      c.refreshHomeProjects = null;
      c.refreshHomeAvatar = null;
      Get.delete<MainTabController>(force: true);
    }
    super.dispose();
  }

  Future<void> _bootstrapAppSocket() async {
    final uid = await AuthService.getUserId();
    if (!mounted) return;
    if (uid == null || uid.isEmpty) return;
    await AppSocketController.to.ensureConnected(
      userId: uid,
      emailFallback: widget.email.trim().toLowerCase(),
    );
  }

  void openProject(Map<String, dynamic> project) {
    setState(() {
      selectedProject = project;
    });
    // ✅ Navigation complète vers le tracking (cache la navbar)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.role == 'client'
            ? SuiviProjectScreen(project: project)
            : ProjectTrackingScreen(project: project, role: widget.role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.role.toLowerCase() == 'client';

    final pages = isClient
        ? <Widget>[
            HomeScreen(
              email: widget.email,
              role: widget.role,
              name: widget.name,
            ),
            const ClientConfirmedDeliveriesScreen(),
            ProjectsListScreen(role: widget.role),
            ProfileScreen(email: widget.email),
          ]
        : <Widget>[
            HomeScreen(
              email: widget.email,
              role: widget.role,
              name: widget.name,
            ),
            ProjectsListScreen(role: widget.role),
            ProfileScreen(email: widget.email),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF9249FD),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0 && Get.isRegistered<MainTabController>()) {
            Get.find<MainTabController>().refreshHomeAvatar?.call();
          }
        },
        items: isClient
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.verified_outlined),
                  label: 'Livrables',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.work),
                  label: 'Projets',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.work),
                  label: 'Projets',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
      ),
    );
  }
}