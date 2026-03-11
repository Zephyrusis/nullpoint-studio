// lib/features/paywall/paywall_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/subscription_service.dart';

// Replace with your actual URLs before shipping.
const String _kPrivacyUrl = 'https://yourdomain.com/privacy';
const String _kTermsUrl   = 'https://yourdomain.com/terms';

class PaywallScreen extends StatefulWidget {
  /// Called after a successful purchase so the parent can replace this screen.
  final VoidCallback onSubscribed;

  const PaywallScreen({super.key, required this.onSubscribed});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  List<Package> _packages = [];
  bool _loadingPackages = true;
  int _selectedIndex = 2; // default to annual
  bool _purchasing = false;
  bool _restoring = false;
  bool _redeemingPromo = false;
  bool _showPromoField = false;
  final _promoController = TextEditingController();
  String? _errorMessage;
  String? _promoSuccess;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  // Display metadata for each product ID, in the order we want to show them.
  static const _meta = [
    _PlanMeta(
      productId: kProductMonthly,
      label: 'Monthly',
      period: '/ month',
      price: '\$3.00',
      annualEquiv: '\$36 / year',
      badge: null,
      highlight: false,
    ),
    _PlanMeta(
      productId: kProductBiannual,
      label: '6 Months',
      period: '/ 6 months',
      price: '\$16.00',
      annualEquiv: '\$32 / year  •  Save \$4',
      badge: 'POPULAR',
      highlight: false,
    ),
    _PlanMeta(
      productId: kProductAnnual,
      label: 'Annual',
      period: '/ year',
      price: '\$28.00',
      annualEquiv: 'Best value  •  Save \$8',
      badge: 'BEST VALUE',
      highlight: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadPackages();
  }

  @override
  void dispose() {
    _animController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    final service = context.read<SubscriptionService>();
    final packages = await service.fetchPackages();
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _loadingPackages = false;
    });
    _animController.forward();
  }

  Package? _packageFor(String productId) {
    for (final p in _packages) {
      if (p.storeProduct.identifier == productId) return p;
    }
    return null;
  }

  Future<void> _subscribe() async {
    final meta = _meta[_selectedIndex];
    final package = _packageFor(meta.productId);
    if (package == null) {
      setState(() => _errorMessage = 'Product unavailable. Try again later.');
      return;
    }

    setState(() { _purchasing = true; _errorMessage = null; });
    try {
      final service = context.read<SubscriptionService>();
      final success = await service.purchase(package);
      if (success && mounted) widget.onSubscribed();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Purchase failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _redeemPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    setState(() { _redeemingPromo = true; _errorMessage = null; _promoSuccess = null; });
    try {
      final service = context.read<SubscriptionService>();
      final valid = await service.redeemPromoCode(code);
      if (!mounted) return;
      if (valid) {
        setState(() => _promoSuccess = 'Code accepted! Welcome to Ascension.');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) widget.onSubscribed();
      } else {
        setState(() => _errorMessage = 'Invalid promo code.');
      }
    } finally {
      if (mounted) setState(() => _redeemingPromo = false);
    }
  }

  Future<void> _restore() async {    setState(() { _restoring = true; _errorMessage = null; });
    try {
      final service = context.read<SubscriptionService>();
      final restored = await service.restorePurchases();
      if (!mounted) return;
      if (restored) {
        widget.onSubscribed();
      } else {
        setState(() => _errorMessage = 'No previous purchase found.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Restore failed.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070818),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF29FFC6).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9D4EDD).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Logo / title ─────────────────────────────────
                    const SizedBox(height: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF29FFC6), Color(0xFF9D4EDD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF29FFC6).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt,
                          color: Colors.black, size: 30),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ASCENSION GYM',
                      style: TextStyle(
                        fontFamily: 'NotoSerifJP',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Unlock your full potential',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Feature list ─────────────────────────────────
                    _FeatureList(),

                    const SizedBox(height: 28),

                    // ── Plan selector ─────────────────────────────────
                    if (_loadingPackages)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(
                          color: Color(0xFF29FFC6),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < _meta.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlanCard(
                                meta: _meta[i],
                                selected: _selectedIndex == i,
                                available:
                                    _packageFor(_meta[i].productId) != null,
                                onTap: () =>
                                    setState(() => _selectedIndex = i),
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 8),

                    // ── Error ─────────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Free trial callout ────────────────────────────
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_outlined,
                            size: 14, color: Color(0xFF29FFC6)),
                        const SizedBox(width: 6),
                        const Text(
                          '7-day free trial — cancel anytime',
                          style: TextStyle(
                            color: Color(0xFF29FFC6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── CTA ───────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            (_purchasing || _loadingPackages) ? null : _subscribe,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF29FFC6),
                          foregroundColor: Colors.black,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        child: _purchasing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Try Free for 7 Days',
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Restore ───────────────────────────────────────
                    TextButton(
                      onPressed: (_restoring || _purchasing) ? null : _restore,
                      child: _restoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF29FFC6),
                              ),
                            )
                          : const Text(
                              'Restore purchase',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // ── Promo code ────────────────────────────────────
                    TextButton(
                      onPressed: () => setState(
                          () => _showPromoField = !_showPromoField),
                      child: Text(
                        _showPromoField ? 'Hide promo code' : 'Have a promo code?',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13),
                      ),
                    ),

                    if (_showPromoField) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: const TextStyle(
                                    color: Colors.white30, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.12)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.12)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF29FFC6)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _redeemingPromo ? null : _redeemPromo,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF29FFC6).withOpacity(0.15),
                              foregroundColor: const Color(0xFF29FFC6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0xFF29FFC6), width: 1)),
                            ),
                            child: _redeemingPromo
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF29FFC6),
                                    ),
                                  )
                                : const Text('Apply'),
                          ),
                        ],
                      ),
                      if (_promoSuccess != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _promoSuccess!,
                          style: const TextStyle(
                              color: Color(0xFF29FFC6), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),

                    // ── Legal ─────────────────────────────────────────
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                        children: [
                          const TextSpan(
                            text:
                                'Subscription renews automatically. Cancel anytime in '
                                'Google Play. By continuing you agree to our ',
                          ),
                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.white38),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  launchUrl(Uri.parse(_kTermsUrl)),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.white38),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  launchUrl(Uri.parse(_kPrivacyUrl)),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature list ──────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  static const _features = [
    (Icons.bolt_outlined,          'Weekly quest generation & progression'),
    (Icons.local_fire_department,  'Penalty chains & boss raids'),
    (Icons.shield_outlined,        'Absolution trials'),
    (Icons.emoji_events_outlined,  'Achievements & stat tracking'),
    (Icons.notifications_outlined, 'Smart reminders & countdowns'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: _features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, color: const Color(0xFF29FFC6), size: 18),
                const SizedBox(width: 12),
                Text(
                  f.$2,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13.5),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _PlanMeta meta;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  const _PlanCard({
    required this.meta,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? (meta.highlight
            ? const Color(0xFF29FFC6)
            : const Color(0xFF29FFC6).withOpacity(0.7))
        : Colors.white.withOpacity(0.12);

    return GestureDetector(
      onTap: available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? const Color(0xFF29FFC6).withOpacity(0.07)
              : Colors.white.withOpacity(0.03),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF29FFC6).withOpacity(0.12),
                    blurRadius: 16,
                    spreadRadius: -4,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF29FFC6)
                      : Colors.white30,
                  width: 1.5,
                ),
                color: selected
                    ? const Color(0xFF29FFC6)
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 13, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (meta.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: meta.highlight
                                ? const Color(0xFF29FFC6)
                                : const Color(0xFF9D4EDD).withOpacity(0.85),
                          ),
                          child: Text(
                            meta.badge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.annualEquiv,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF29FFC6).withOpacity(0.85)
                          : Colors.white38,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  meta.price,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  meta.period,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan metadata ─────────────────────────────────────────────────────────────

class _PlanMeta {
  final String productId;
  final String label;
  final String period;
  final String price;
  final String annualEquiv;
  final String? badge;
  final bool highlight;

  const _PlanMeta({
    required this.productId,
    required this.label,
    required this.period,
    required this.price,
    required this.annualEquiv,
    required this.badge,
    required this.highlight,
  });
}
