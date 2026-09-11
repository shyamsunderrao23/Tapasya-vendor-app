import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';

class VendorReviewsScreen extends StatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchReviewsFull();
    });
  }

  void _filterReviews(int? rating) {
    setState(() => _selectedRating = rating);
    context.read<VendorProvider>().fetchReviewsFull(rating: rating);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, provider, child) {
        final reviewData = provider.reviewsFullData;
        final rating = reviewData?['average_rating']?.toString() ?? "0.0";
        final totalReviews = reviewData?['total_reviews'] ?? 0;
        final starDist = reviewData?['star_distribution'] ?? {};
        final reviews = reviewData?['reviews'] as List? ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: provider.isLoading && reviewData == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => provider.fetchReviewsFull(rating: _selectedRating),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1. CINEMATIC ANALYTICS HEADER
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                          child: IconButton(
                                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        const Text(
                                          "Ratings & Reviews",
                                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // RATING HUB
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Column(
                                          children: [
                                            Text(rating, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                                            _buildStarRow(double.tryParse(rating) ?? 0),
                                            const SizedBox(height: 8),
                                            Text("Based on $totalReviews reviews", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 2. RATING DISTRIBUTION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: Column(
                            children: [
                              for (int i = 5; i >= 1; i--) ...[
                                _buildRatingRow(
                                  "$i Star", 
                                  totalReviews > 0 ? (int.tryParse(starDist[i.toString()]?.toString() ?? "0") ?? 0) / totalReviews : 0, 
                                  _getStarColor(i),
                                  i,
                                  _selectedRating == i
                                ),
                                if (i > 1) const SizedBox(height: 12),
                              ],
                              if (_selectedRating != null) ...[
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => _filterReviews(null),
                                  child: const Text("Clear Filter", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                                ),
                              ]
                            ],
                          ),
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                      ),

                      const SizedBox(height: 40),

                      // 3. REVIEWS LIST
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRating != null ? "$_selectedRating Star Feedback" : "Recent Feedback",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 24),
                            if (reviews.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Text("No reviews found", style: TextStyle(color: Colors.grey.shade400)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: reviews.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final rev = reviews[index];
                                  return _buildReviewCard(
                                    rev['name'] ?? "User", 
                                    rev['review'] ?? "", 
                                    rev['rating']?.toString() ?? "0", 
                                    index,
                                    rev['created_at'] ?? ""
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Color _getStarColor(int star) {
    if (star >= 4) return Colors.green;
    if (star == 3) return Colors.amber;
    return Colors.red;
  }

  Widget _buildStarRow(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star_rounded, color: Colors.amber, size: 20);
        } else if (index < rating && (rating - index) >= 0.5) {
          return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 20);
        } else {
          return Icon(Icons.star_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20);
        }
      }),
    );
  }

  Widget _buildRatingRow(String label, double progress, Color color, int ratingValue, bool isSelected) {
    return InkWell(
      onTap: () => _filterReviews(ratingValue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(width: 45, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800, color: const Color(0xFF1B263B)))),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 35, child: Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400))),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(String name, String review, String rating, int index, String date) {
    String formattedDate = date;
    try {
      final DateTime parsed = DateTime.parse(date);
      formattedDate = "${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}";
    } catch (_) {
      if (date.contains('T')) {
        final d = date.split('T')[0].split('-');
        if (d.length == 3) formattedDate = "${d[2]}-${d[1]}-${d[0]}";
      } else if (date.contains(' ')) {
        final d = date.split(' ')[0].split('-');
        if (d.length == 3) formattedDate = "${d[2]}-${d[1]}-${d[0]}";
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(0.1), radius: 18, child: Text(name.isNotEmpty ? name[0] : 'U', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 12))),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1B263B))),
                      Text(formattedDate, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(rating, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(review, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().fadeIn(delay: (600 + (index * 100)).ms).slideX(begin: 0.1, end: 0);
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
