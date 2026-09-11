import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _bank;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBankDetails());
  }

  Future<void> _loadBankDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ??
          context.read<RegistrationState>().authToken;

      // 🔑 Dynamic vendor_id: this vendor's own id (never anyone else's)
      final vendorId = context.read<VendorProvider>().profile?.vendor.id ??
          context.read<RegistrationState>().vendorId;

      if (vendorId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = "Vendor session not found. Please re-login.";
        });
        return;
      }

      final res = await ApiService().getVendorBankDetails(token, vendorId);

      if (!mounted) return;
      if (res != null && res['success'] == true && res['data'] != null) {
        setState(() {
          _bank = Map<String, dynamic>.from(res['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _bank = null;
          _isLoading = false;
          _error = res?['message'] ?? "No bank account linked yet.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't load bank details. Pull to refresh.";
      });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return "—";
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _maskedAccount(String? acc) {
    if (acc == null || acc.isEmpty) return "•••• •••• ••••";
    // Group the (already partly masked) value into blocks of 4 for readability
    final clean = acc.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bool isVerified = (_bank?['is_verified']?.toString() == '1') ||
        (_bank?['is_verified'] == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _loadBankDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(isVerified),
              const SizedBox(height: 24),
              if (_isLoading)
                _buildLoading()
              else if (_bank == null)
                _buildEmptyState()
              else
                _buildDetails(isVerified),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HEADER + CARD ----------------
  Widget _buildHeader(bool isVerified) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Payments & Banking",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildBankCard(isVerified),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(bool isVerified) {
    final String holder = (_bank?['account_holder_name'] ?? 'Your Name').toString();
    final String ifsc = (_bank?['ifsc_code'] ?? 'IFSC').toString();
    final String bankName = (_bank?['bank_name'] ?? 'Your Bank').toString();
    final String account = _maskedAccount(_bank?['account_number']?.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      _isLoading ? "Loading…" : bankName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ],
              ),
              if (_bank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isVerified ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (isVerified ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                          color: isVerified ? Colors.greenAccent : Colors.orangeAccent, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? "Verified" : "Pending",
                        style: TextStyle(
                            color: isVerified ? Colors.greenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            account,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.5),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardMini("HOLDER NAME", _isLoading ? "—" : holder, CrossAxisAlignment.start),
              _cardMini("IFSC CODE", _isLoading ? "—" : ifsc, CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _cardMini(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ---------------- DETAILS ----------------
  Widget _buildDetails(bool isVerified) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text("ACCOUNT DETAILS",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Color(0xFF8A8F9C))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                _detailRow(Icons.account_balance_rounded, "Bank Name", _bank?['bank_name']),
                _divider(),
                _detailRow(Icons.person_rounded, "Account Holder", _bank?['account_holder_name']),
                _divider(),
                _detailRow(
                  Icons.numbers_rounded,
                  "Account Number",
                  _maskedAccount(_bank?['account_number']?.toString()),
                  trailing: _copyButton(_bank?['account_number']?.toString()),
                ),
                _divider(),
                _detailRow(
                  Icons.qr_code_rounded,
                  "IFSC Code",
                  _bank?['ifsc_code'],
                  trailing: _copyButton(_bank?['ifsc_code']?.toString()),
                ),
                _divider(),
                _detailRow(Icons.event_rounded, "Added On", _formatDate(_bank?['created_at']?.toString())),
                _divider(),
                _statusRow(isVerified),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Your banking information is encrypted and visible only to you.",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value, {Widget? trailing}) {
    final String text = (value == null || value.toString().isEmpty) ? "—" : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B263B),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
  }

  Widget _statusRow(bool isVerified) {
    final Color color = isVerified ? const Color(0xFF16A34A) : const Color(0xFFEA8C00);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.pending_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "VERIFICATION STATUS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(isVerified ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  isVerified ? "Verified" : "Pending",
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyButton(String? raw) {
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: raw));
        HapticFeedback.lightImpact();
        AppToast.show(context, "Copied to clipboard");
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryColor.withOpacity(0.7)),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.08), indent: 16, endIndent: 16);

  // ---------------- STATES ----------------
  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 44, color: AppTheme.primaryColor.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          const Text("No Bank Account Linked",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
          const SizedBox(height: 8),
          Text(
            _error ?? "You haven't added your bank details yet.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadBankDetails();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            label: const Text("Retry", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 30, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
