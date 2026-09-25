import 'package:flutter/material.dart';
import 'package:guardify_app/core/design/colors.dart';

class MenuItem {
  final String id;
  final String title;
  final IconData icon;
  final bool hasNotification;
  final VoidCallback onTap;

  const MenuItem({
    required this.id,
    required this.title,
    required this.icon,
    this.hasNotification = false,
    required this.onTap,
  });
}

class MenuGrid extends StatelessWidget {
  final List<MenuItem> menuItems;

  const MenuGrid({
    super.key,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: neutral90,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return _buildMenuItem(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: babyBlueColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with optional notification badge
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: babyBlueColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: primaryColor,
                        size: 34,
                      ),
                    ),
                    if (item.hasNotification)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Menu title
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: neutral90,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
