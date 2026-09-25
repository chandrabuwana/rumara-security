import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/colors.dart';
import '../bloc/patrol_bloc.dart';
import '../widgets/patrol_route_card.dart';
import 'patrol_detail_page.dart';

class HomePatrolPage extends StatefulWidget {
  const HomePatrolPage({super.key});

  @override
  State<HomePatrolPage> createState() => _HomePatrolPageState();
}

class _HomePatrolPageState extends State<HomePatrolPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<PatrolBloc>().add(LoadMorePatrolRoutes());
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
    return BlocProvider(
      create: (_) => getIt<PatrolBloc>()..add(LoadPatrolRoutes()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'Daftar Rute Patroli',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
        ),
        body: BlocBuilder<PatrolBloc, PatrolState>(
          builder: (context, state) {
            if (state is PatrolLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              );
            }

            if (state is PatrolError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<PatrolBloc>().add(RefreshPatrolData());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              );
            }

            if (state is PatrolLoaded) {
              if (state.routes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada rute patroli',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<PatrolBloc>().add(RefreshPatrolData());
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Patrol Routes List
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < state.routes.length) {
                              final route = state.routes[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: PatrolRouteCard(
                                  route: route,
                                  onTap: () async {
                                    // Validasi: tidak bisa absen patroli jika belum check in
                                    final shiftDetailId =
                                        await SecurityManager.readSecurely(
                                      AppConstants.shiftDetailIdKey,
                                    );
                                    if (shiftDetailId == null ||
                                        shiftDetailId.isEmpty) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Silakan check in terlebih dahulu sebelum melakukan absen patroli',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    final patrolBloc =
                                        context.read<PatrolBloc>();
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PatrolDetailPage(
                                          route: route,
                                          bloc: patrolBloc,
                                          isCheckedIn: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                            return null;
                          },
                          childCount: state.routes.length,
                        ),
                      ),
                    ),

                    // Loading More Indicator
                    if (state.hasMore && state.isLoadingMore)
                      SliverPadding(
                        padding: EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),

                    // Bottom Padding
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 80),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
