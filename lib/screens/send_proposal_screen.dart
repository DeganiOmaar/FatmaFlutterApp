import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/proposal_service.dart';

class SendProposalScreen extends StatefulWidget {
  final String token;
  final String projectId;
  final String? projectTitle;
  /// Budget fixé par le client (non modifiable dans le formulaire).
  final int clientBudget;

  const SendProposalScreen({
    super.key,
    required this.token,
    required this.projectId,
    required this.clientBudget,
    this.projectTitle,
  });

  @override
  State<SendProposalScreen> createState() => _SendProposalScreenState();
}

class _SendProposalScreenState extends State<SendProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _timeController = TextEditingController();
  final _messageController = TextEditingController();

  final ProposalService service = ProposalService();
  bool loading = false;
  bool aiLoading = false;

  // Couleurs Lancy
  final Color primaryBlue = const Color(0xFF00AEEF);
  final Color primaryPurple = const Color(0xFF8E2DE2);

  @override
  void initState() {
    super.initState();
    _priceController.text =
        widget.clientBudget > 0 ? '${widget.clientBudget}' : '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _timeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- STYLE DES CHAMPS ---
  InputDecoration _buildInputStyle(
    String label,
    IconData icon, {
    String? suffix,
    bool muted = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: primaryBlue, size: 20),
      suffixText: suffix,
      filled: true,
      fillColor: muted ? Colors.grey.shade100 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: primaryPurple, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _generateWithAi() async {
    setState(() => aiLoading = true);
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => aiLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée — reconnectez-vous'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await service.generateAiProposalDraft(
      token: token,
      projectId: widget.projectId,
    );

    if (!mounted) return;
    setState(() => aiLoading = false);

    if (result['ok'] == true) {
      final letter = result['coverLetter']?.toString() ?? '';
      final daysRaw = result['deliveryDays'];
      int? days;
      if (daysRaw is int) {
        days = daysRaw;
      } else if (daysRaw != null) {
        days = int.tryParse(daysRaw.toString());
      }
      setState(() {
        _messageController.text = letter;
        if (days != null && days > 0) {
          _timeController.text = '$days';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Proposition générée — relisez et adaptez avant envoi ✨'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Erreur IA'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> send() async {
    if (!_formKey.currentState!.validate()) return;
    final price = widget.clientBudget > 0
        ? widget.clientBudget
        : int.tryParse(_priceController.text) ?? 0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget du projet invalide.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final token = await AuthService.getToken();

    final ok = await service.createProposal(
      token: token!,
      projectId: widget.projectId,
      coverLetter: _messageController.text,
      price: price,
      deliveryTime: int.parse(_timeController.text),
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Proposition envoyée ✅"),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de l'envoi ❌"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Nouvelle Proposition",
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Détails de votre offre",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Soyez précis pour augmenter vos chances d'être retenu.",
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),

              const SizedBox(height: 30),

              // --- CHAMP MESSAGE ---
              Text(
                "Lettre de motivation",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (loading || aiLoading) ? null : _generateWithAi,
                  icon: aiLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryBlue,
                          ),
                        )
                      : Icon(Icons.auto_awesome, color: primaryPurple),
                  label: Text(
                    aiLoading
                        ? 'Génération…'
                        : 'Générer avec l\'IA (Groq)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    side: BorderSide(color: primaryBlue.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: _buildInputStyle(
                  "Expliquez pourquoi vous êtes le meilleur...",
                  Icons.edit_note,
                ),
                validator: (v) => v!.length < 20
                    ? "Détaillez un peu plus votre message"
                    : null,
              ),

              const SizedBox(height: 20),

              // --- LIGNE PRIX ET DÉLAI ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prix (budget client)",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          readOnly: true,
                          enableInteractiveSelection: true,
                          showCursor: false,
                          decoration: _buildInputStyle(
                            "",
                            Icons.payments_outlined,
                            suffix: "DT",
                            muted: true,
                          ).copyWith(
                            hintText:
                                widget.clientBudget > 0 ? null : "—",
                            helperText: 'Fixé par le client',
                            helperStyle:
                                GoogleFonts.inter(fontSize: 11),
                          ),
                          validator: (_) =>
                              widget.clientBudget <= 0 ? "Budget manquant" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Délai",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _timeController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputStyle(
                            "00",
                            Icons.timer_outlined,
                            suffix: "Jours",
                          ),
                          validator: (v) => v!.isEmpty ? "Requis" : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // --- BOUTON ENVOYER ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading ? null : send,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryBlue, primaryPurple],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Envoyer l'offre",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
