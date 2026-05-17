import 'package:flutter/material.dart';
import 'package:pfe/service/project_service.dart';

class ClientProjectScreen extends StatefulWidget {
  final String proposalId;
  final String projectId;

  const ClientProjectScreen({
    super.key,
    required this.proposalId,
    required this.projectId,
  });

  @override
  State<ClientProjectScreen> createState() => _ClientProjectScreenState();
}

class _ClientProjectScreenState extends State<ClientProjectScreen> {
  final service = ProjectService();
  bool loading = false;

  void showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ACCEPT
  Future<void> accept() async {
    setState(() => loading = true);

    final ok = await service.acceptProposal(widget.proposalId);

    setState(() => loading = false);

    if (ok) {
      showMsg("Projet accepté 💰");
    } else {
      showMsg("Erreur accept ❌", error: true);
    }
  }

  // RELEASE PAYMENT
  Future<void> validateWork() async {
    setState(() => loading = true);

    final ok = await service.releasePayment(widget.projectId);

    if (!mounted) return;
    setState(() => loading = false);

    if (ok) {
      showMsg("Paiement libéré 💸");
      Navigator.pop(context);
    } else {
      showMsg("Erreur paiement ❌", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Client Project")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: loading ? null : accept,
              child: const Text("Accepter proposition"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : validateWork,
              child: const Text("Valider & libérer paiement"),
            ),
          ],
        ),
      ),
    );
  }
}