import 'package:get/get.dart';

/// Switches bottom navigation to Accueil and triggers home mission list refresh
/// after a mission is published (from FAB or Profil).
class MainTabController extends GetxController {
  void Function(int index)? setTabIndex;
  Future<void> Function()? refreshHomeProjects;
  Future<void> Function()? refreshHomeAvatar;

  Future<void> afterMissionPublished() async {
    setTabIndex?.call(0);
    final refresh = refreshHomeProjects;
    if (refresh != null) {
      await refresh();
    }
  }
}
