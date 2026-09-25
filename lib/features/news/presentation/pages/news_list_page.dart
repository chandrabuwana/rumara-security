import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../bloc/news_bloc.dart';
import '../bloc/news_event.dart';
import '../bloc/news_state.dart';
import '../../domain/entities/news.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/user_role_helper.dart';
import 'news_detail_page.dart';
import 'add_news_page.dart';

class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key});

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  UserRole? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    context.read<NewsBloc>().add(const NewsLoadNews());
    _scrollController.addListener(_onScroll);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleHelper.getUserRole();
    if (!mounted) return;
    setState(() {
      _userRole = role;
      _isLoadingRole = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<NewsBloc>().add(const NewsLoadMoreNews());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral10,
      body: SafeArea(
        child: BlocConsumer<NewsBloc, NewsState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: errorColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back, color: primaryColor, size: 24.sp),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: Text(
                          'Berita',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      if (!_isLoadingRole && _userRole == UserRole.pengawas)
                        IconButton(
                          icon: Icon(Icons.add, color: primaryColor, size: 28.sp),
                          onPressed: () {
                            final newsBloc = context.read<NewsBloc>();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BlocProvider.value(
                                  value: newsBloc,
                                  child: const AddNewsPage(),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Search and Filter Bar
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(color: primaryColor, width: 1.5),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari',
                              hintStyle: TextStyle(
                                color: neutral50,
                                fontSize: 14.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: primaryColor,
                                size: 20.sp,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                            ),
                            onChanged: (value) {
                              context.read<NewsBloc>().add(NewsSearchNews(value));
                            },
                          ),
                        ),
                      ),

                      12.horizontalSpace,

                      // Filter Button
                      GestureDetector(
                        onTap: _showFilterDialog,
                        child: Container(
                          width: 48.w,
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.filter_alt,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // News List
                Expanded(
                  child: state.isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      : state.filteredNews.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () async {
                                context.read<NewsBloc>().add(const NewsRefreshNews());
                                await Future.delayed(const Duration(milliseconds: 500));
                              },
                              color: primaryColor,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                itemCount: state.filteredNews.length +
                                    (state.hasReachedMax ? 0 : 1),
                                itemBuilder: (context, index) {
                                  if (index >= state.filteredNews.length) {
                                    return _buildBottomLoader();
                                  }
                                  final news = state.filteredNews[index];
                                  return _buildNewsCard(news);
                                },
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64.sp, color: neutral50),
          16.verticalSpace,
          Text(
            'Tidak ada berita',
            style: TextStyle(fontSize: 16.sp, color: neutral70),
          ),
          8.verticalSpace,
          Text(
            'Belum ada berita yang tersedia',
            style: TextStyle(fontSize: 14.sp, color: neutral50),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLoader() {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
    );
  }

  Widget _buildNewsCard(News news) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final newsBloc = context.read<NewsBloc>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: newsBloc,
                  child: NewsDetailPage(news: news),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: news.imageUrl != null
                      ? Image.network(
                          news.imageUrl!,
                          width: 80.w,
                          height: 80.w,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildThumbnailPlaceholder(),
                        )
                      : _buildThumbnailPlaceholder(),
                ),

                12.horizontalSpace,

                // News Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Text(
                        news.category,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: neutral50,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      4.verticalSpace,

                      // Title
                      Text(
                        news.title,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: neutral90,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      6.verticalSpace,

                      // Description
                      Text(
                        news.content,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: neutral50,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      8.verticalSpace,

                      // Date and Read More
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(news.publishedAt),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: neutral50,
                            ),
                          ),
                          Text(
                            'Baca →',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: neutral70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      width: 80.w,
      height: 80.w,
      color: primaryColor,
      child: Icon(Icons.wb_cloudy, color: Colors.white, size: 36.sp),
    );
  }

  void _showFilterDialog() {
    final newsBloc = context.read<NewsBloc>();
    final currentCategory = newsBloc.state.selectedCategory;
    final currentNewestFirst = newsBloc.state.newestFirst;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        NewsCategory? selectedCategory = currentCategory;
        bool newestFirst = currentNewestFirst;

        Widget buildChip({
          required String label,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selected ? Colors.white : neutral10,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: selected ? primaryColor : neutral30),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? primaryColor : neutral70,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 16.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: neutral90,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close, color: neutral90, size: 20.sp),
                      ),
                    ],
                  ),

                  12.verticalSpace,

                  Text(
                    'Kategori',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: neutral90,
                    ),
                  ),
                  12.verticalSpace,
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      buildChip(
                        label: 'Semua',
                        selected: selectedCategory == null,
                        onTap: () => setState(() => selectedCategory = null),
                      ),
                      ...NewsCategory.values.map((category) {
                        return buildChip(
                          label: category.displayName,
                          selected: selectedCategory == category,
                          onTap: () => setState(() => selectedCategory = category),
                        );
                      }),
                    ],
                  ),

                  20.verticalSpace,

                  Text(
                    'Urutkan',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: neutral90,
                    ),
                  ),
                  12.verticalSpace,
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      buildChip(
                        label: 'Terbaru',
                        selected: newestFirst,
                        onTap: () => setState(() => newestFirst = true),
                      ),
                      buildChip(
                        label: 'Terlama',
                        selected: !newestFirst,
                        onTap: () => setState(() => newestFirst = false),
                      ),
                    ],
                  ),

                  24.verticalSpace,

                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () {
                        newsBloc.add(
                          NewsApplyFilter(
                            category: selectedCategory,
                            newestFirst: newestFirst,
                          ),
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Terapkan',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  10.verticalSpace,
                ],
              ),
            );
          },
        );
      },
    );
  }
}
