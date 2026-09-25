import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/news_bloc.dart';
import '../bloc/news_event.dart';
import '../bloc/news_state.dart';
import '../../domain/entities/news.dart';
import '../../../../core/design/colors.dart';

class NewsDetailPage extends StatefulWidget {
  final News news;

  const NewsDetailPage({
    super.key,
    required this.news,
  });

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<NewsBloc>().add(NewsLoadNewsById(widget.news.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        final news = state.selectedNews ?? widget.news;
        final imageUrl = news.imageUrl;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        // Source box height estimate for bottom padding in scroll
        const sourceBoxHeight = 60.0;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Scrollable content
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Hero Image
                          SizedBox(
                            width: double.infinity,
                            height: 300.h,
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildImagePlaceholder(),
                                  )
                                : _buildImagePlaceholder(),
                          ),

                          // White content card overlapping the image
                          Transform.translate(
                            offset: Offset(0, -28.h),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                              ),
                              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Title
                                  Text(
                                    news.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: neutral90,
                                      height: 1.4,
                                    ),
                                  ),

                                  16.verticalSpace,

                                  // Category - Date Chip
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(color: neutral30, width: 1),
                                    ),
                                    child: Text(
                                      '${news.category} - ${DateFormat('dd/MM/yyyy').format(news.publishedAt)}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: neutral50,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),

                                  24.verticalSpace,

                                  // Content
                                  Text(
                                    news.content,
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: neutral90,
                                      height: 1.7,
                                    ),
                                  ),

                                  // Bottom padding so content doesn't hide behind source box
                                  SizedBox(height: sourceBoxHeight + 24.h + bottomPadding),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Source fixed at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, bottomPadding + 12.h),
                  child: GestureDetector(
                    onTap: () => _launchUrl(news.source),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: neutral10,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'Sumber : ${news.source}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: primaryColor,
                          decoration: TextDecoration.underline,
                          decorationColor: primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Back Button
              Positioned(
                top: statusBarHeight + 12.h,
                left: 16.w,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.black,
                      size: 26.sp,
                    ),
                  ),
                ),
              ),

              // Loading Overlay
              if (state.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  ),
                ),

              // Error Banner
              if (!state.isLoading && state.errorMessage != null)
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  top: statusBarHeight + 60.h,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      state.errorMessage ?? '',
                      style: TextStyle(color: errorColor, fontSize: 12.sp),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String source) async {
    final raw = source.trim();
    if (raw.isEmpty) {
      print('❌ Source is empty');
      return;
    }

    final withScheme =
        raw.startsWith('http://') || raw.startsWith('https://')
            ? raw
            : 'https://$raw';

    print('🌐 Launching URL: $withScheme');

    final url = Uri.tryParse(withScheme);
    if (url == null) {
      print('❌ Failed to parse URL: $withScheme');
      return;
    }

    print('🌐 Parsed URL: $url');

    try {
      print('🌐 Attempting to launch URL...');
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      print('🌐 Launch result: $launched');
      if (!launched) {
        print('❌ Launch failed, trying with in-app browser mode...');
        await launchUrl(
          url,
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (e) {
      print('❌ Exception launching URL: $e');
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: primaryColor,
      child: Center(
        child: Icon(
          Icons.wb_cloudy,
          color: Colors.white.withValues(alpha: 0.5),
          size: 64.sp,
        ),
      ),
    );
  }
}
