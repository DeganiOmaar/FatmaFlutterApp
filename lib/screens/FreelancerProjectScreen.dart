/*import 'package:flutter/material.dart';
import 'package:pfe/service/project_service.dart';

class FreelancerProjectScreen extends StatefulWidget {
  final String projectId;

  const FreelancerProjectScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<FreelancerProjectScreen> createState() =>
      _FreelancerProjectScreenState();
}

class _FreelancerProjectScreenState extends State<FreelancerProjectScreen> {
  final service = ProjectService();
  final messageController = TextEditingController();
  bool loading = false;

  void showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // DELIVER WORK
  Future<void> deliver() async {
    setState(() => loading = true);

    final ok = await service.deliverProject(
      widget.projectId,
      messageController.text,
    );

    setState(() => loading = false);

    if (ok) {
      showMsg("Travail livré ✅");
      Navigator.pop(context);
    } else {
      showMsg("Erreur livraison ❌", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Freelancer Project")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: "Message de livraison",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : deliver,
              child: const Text("Livrer le travail"),
            ),
          ],
        ),
      ),
    );
  }
}*/