import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pfe/controllers/wallet_balance_controller.dart';
import 'package:pfe/service/payment_service.dart';
import 'package:pfe/service/user_service.dart';

class WalletScreen extends StatefulWidget {
  /// Client : recharge Stripe en € ; Freelancer : solde + historique gains.
  final bool forClient;

  const WalletScreen({super.key, this.forClient = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final UserService _userService = UserService();

  final Color skyBlue     = const Color(0xFF74C0FC);
  final Color mintCrystal = const Color(0xFF81E38F);
  final Color darkText    = const Color(0xFF1A1C1E);

  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = _userService.getWallet();
  }

  Future<void> _reload() async {
    await Get.find<WalletBalanceController>().refreshFromApi();
    final next = _userService.getWallet();
    if (!mounted) return;
    setState(() {
      _walletFuture = next;
    });
    await next;
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy', 'fr_FR').format(dt);
  }

  Future<void> _showTopUpDialog(BuildContext context) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => const _WalletTopUpDialog(),
    );
    if (amount == null || !mounted) return;
    if (!context.mounted) return;
    final ok = await PaymentService.topUpWalletEuros(amount, context);
    if (ok && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      floatingActionButton: widget.forClient
          ? FloatingActionButton.extended(
              onPressed: () => _showTopUpDialog(context),
              backgroundColor: skyBlue,
              icon: const Icon(Icons.add_card_rounded),
              label: Text("Recharger", style: GoogleFonts.poppins()),
            )
          : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _walletFuture,
        builder: (context, snap) {
          final isLoading = snap.connectionState == ConnectionState.waiting;
          final balance   = snap.data?['balance'] ?? 0;
          final transactions =
              snap.data?['transactions'] as List? ?? [];

          return RefreshIndicator(
            color: skyBlue,
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── App Bar ──────────────────────────────
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: skyBlue,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [skyBlue, mintCrystal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              20, 56, 20, 20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              Text("Solde disponible",
                                  style: GoogleFonts.inter(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                  : Text(
                                      "$balance €",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                              const SizedBox(height: 10),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(99),
                                ),
                                child: Text(
                                  "${transactions.length} mission${transactions.length != 1 ? 's' : ''} complétée${transactions.length != 1 ? 's' : ''}",
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                        widget.forClient ? "Wallet client" : "Mon Wallet",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.white)),
                    titlePadding: const EdgeInsets.only(
                        left: 56, bottom: 14),
                  ),
                ),

                // ── Stats ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 20, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.check_circle_outline_rounded,
                            label: "Missions",
                            value: "${transactions.length}",
                            color: skyBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            icon: Icons.payments_outlined,
                            label: "Total gagné",
                            value: "$balance €",
                            color: mintCrystal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Transactions ─────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      16, 20, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                          widget.forClient
                              ? "Historique"
                              : "Historique des paiements",
                          style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: darkText)),
                      const SizedBox(height: 12),

                      if (isLoading)
                        const Center(
                            child: CircularProgressIndicator())
                      else if (transactions.isEmpty)
                        _buildEmpty()
                      else
                        ...transactions.map((t) => _buildTxCard(t)),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Stat card ─────────────────────────────────────────
  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ── Transaction card ──────────────────────────────────
  Widget _buildTxCard(dynamic t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mintCrystal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: Colors.green.shade600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] ?? 'Projet',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: darkText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  _formatDate(t['createdAt']),
                  style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "+${t['budget']} €",
            style: GoogleFonts.poppins(
              color: Colors.green.shade600,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────
  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("Aucune transaction",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text(
            widget.forClient
                ? "Les rechargements s’affichent après paiement Stripe réussi."
                : "Complète des missions pour voir tes paiements ici.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WalletTopUpDialog extends StatefulWidget {
  const _WalletTopUpDialog();

  @override
  State<_WalletTopUpDialog> createState() => _WalletTopUpDialogState();
}

class _WalletTopUpDialogState extends State<_WalletTopUpDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Recharger le wallet",
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: "Montant en €",
          prefixIcon: const Icon(Icons.euro_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
            if (v >= 1) Navigator.pop(context, v);
          },
          child: const Text("Continuer"),
        ),
      ],
    );
  }
}