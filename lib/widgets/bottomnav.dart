import 'package:flutter/material.dart';

class CommonBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CommonBottomNav({
    super.key, 
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4038D8);

    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8FF),
          border: Border(
            top: BorderSide(
              color: Color(0xFFF0EAF5),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              index: 0,
              primary: primary,
            ),
            _item(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: 'History',
              index: 1,
              primary: primary,
            ),
            _item(
              icon: Icons.file_upload_outlined,
              activeIcon: Icons.file_upload,
              label: 'Export',
              index: 2,
              primary: primary,
            ),
            _item(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              index: 3,
              primary: primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color primary,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onItemSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected
                  ? primary
                  : const Color(0xFF999999),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? primary
                    : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}