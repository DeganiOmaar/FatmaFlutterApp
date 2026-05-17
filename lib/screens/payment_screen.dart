import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfe/service/auth_service.dart';
import 'package:pfe/service/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String  projectId;
  final dynamic amount;
  final String  projectTitle;
  final dynamic client;
  final dynamic freelancer;

  const PaymentScreen({
    super.key,
    required this.projectId,
    required this.amount,
    required this.projectTitle,
    required this.client,
    required this.freelancer,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  // ── Lancy Brand ─────────────────────────────────────
  static const Color _blue    = Color(0xFF00D2FF);
  static const Color _purple  = Color(0xFF9249FD);
  static const Color _dark    = Color(0xFF1A1A2E);
  static const Color _bgLight = Color(0xFFF4F6FF);
  static const LinearGradient _grad = LinearGradient(
    colors: [_blue, _purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _isPaying = false;
  late AnimationController _animCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String get _clientName =>
      (widget.client is Map) ? (widget.client['name'] ?? 'Client') : 'Client';
  String get _freelancerName =>
      (widget.freelancer is Map)
          ? (widget.freelancer['name'] ?? 'Freelancer')
          : 'Freelancer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // Background gradient top
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: const BoxDecoration(
                gradient: _grad,
                borderRadius: BorderRadius.only(
                  bottomLeft:  Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 60, left: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      children: [
                        _buildAmountCard(),
                        const SizedBox(height: 24),
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildEscrowCard(),
                        const SizedBox(height: 32),
                        _buildPayButton(),
                        const SizedBox(height: 16),
                        _buildSecureLine(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          Text(
            'Finaliser le paiement',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── Amount Card ──────────────────────────────────────
  Widget _buildAmountCard() {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Montant total',
              style: GoogleFonts.inter(
                  color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ShaderMask(
              shaderCallback: (b) => _grad.createShader(b),
              child: Text(
                '${widget.amount} DT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _blue.withValues(alpha: 0.1),
                    _purple.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _purple.withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.projectTitle,
                style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary Card ─────────────────────────────────────
  Widget _buildSummaryCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Récapitulatif',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 16),
          _infoRow(
            icon: Icons.person_3_outlined,
            label: 'Client',
            value: _clientName,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey.shade100, thickness: 1),
          ),
          _infoRow(
            icon: Icons.bolt_outlined,
            label: 'Freelancer',
            value: _freelancerName,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey.shade100, thickness: 1),
          ),
          _infoRow(
            icon: Icons.tag_rounded,
            label: 'Projet',
            value: widget.projectTitle,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      {required IconData icon,
      required String label,
      required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_blue.withValues(alpha: 0.1), _purple.withValues(alpha: 0.1)],
            ),
            shape: BoxShape.circle,
          ),
          child: ShaderMask(
            shaderCallback: (b) => _grad.createShader(b),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade500)),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
          ],
        ),
      ],
    );
  }

  // ── Escrow Card ──────────────────────────────────────
  Widget _buildEscrowCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.green.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Protection Escrow activée',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  "Le freelancer ne sera payé qu'après validation de votre part.",
                  style: GoogleFonts.inter(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pay Button ───────────────────────────────────────
  Widget _buildPayButton() {
    return GestureDetector(
      onTap: _isPaying ? null : _handlePayment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: _isPaying ? null : _grad,
          color: _isPaying ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isPaying
              ? []
              : [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        child: Center(
          child: _isPaying
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.credit_card_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Payer maintenant',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecureLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 5),
        Text(
          'Paiement 100 % sécurisé via Stripe',
          style: GoogleFonts.inter(
              color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  // ── Reusable glass card ──────────────────────────────
  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Payment Handler ──────────────────────────────────
  Future<void> _handlePayment() async {
    setState(() => _isPaying = true);
    final token = await AuthService.getToken();
    if (token != null && mounted) {
      await PaymentService.initAndPresentPaymentSheet(
          widget.projectId, token, context);
    }
    if (mounted) setState(() => _isPaying = false);
  }
}