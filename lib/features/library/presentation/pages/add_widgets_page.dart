import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddWidgetsPage extends StatefulWidget {
  const AddWidgetsPage({super.key});

  @override
  State<AddWidgetsPage> createState() => _AddWidgetsPageState();
}

class _AddWidgetsPageState extends State<AddWidgetsPage> {
  static const _pageBg = Color(0xFF0F0F10);
  static const _actionBlue = Color(0xFF5C8DFF);

  void _showAddToHomeDialog(String widgetName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF232325),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add to Home screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Touch & hold the widget to move it around the home screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD0D0D0),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 96,
                  child: AspectRatio(
                    aspectRatio: 1.45,
                    child: widgetName == 'Your likes'
                        ? const _MiniLikesPreview()
                        : const _MiniPlayerPreview(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widgetName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '3 × 2',
                  style: TextStyle(
                    color: Color(0xFFE2E2E2),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF3B3B3F),
                ),
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(26),
                          ),
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: _actionBlue,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        color: const Color(0xFF3B3B3F),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(26),
                          ),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF242426),
                                content:
                                    Text('$widgetName added to Home screen'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Center(
                            child: Text(
                              'Add',
                              style: TextStyle(
                                color: _actionBlue,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Text(
                      'Add widgets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    splashRadius: 24,
                    icon: const Icon(
                      Icons.cast_outlined,
                      color: Colors.white,
                      size: 33,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select a widget to add to home screen',
                  style: TextStyle(
                    color: Color(0xFFE2E2E2),
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _WidgetSection(
                      title: 'Your likes',
                      child: _OuterSectionSurface(
                        child: _YourLikesWidgetPreview(
                          onTap: () => _showAddToHomeDialog('Your likes'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _WidgetSection(
                      title: 'Player',
                      child: _OuterSectionSurface(
                        child: _PlayerWidgetPreview(
                          onTap: () => _showAddToHomeDialog('Player'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _WidgetSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF2A2A2B),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Row(
            children: [
              Transform.rotate(
                angle: -0.35,
                child: const Icon(
                  Icons.push_pin_outlined,
                  color: Color(0xFFEAEAEA),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _OuterSectionSurface extends StatelessWidget {
  final Widget child;

  const _OuterSectionSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2A2A2B),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: child,
    );
  }
}

class _YourLikesWidgetPreview extends StatelessWidget {
  final VoidCallback onTap;

  const _YourLikesWidgetPreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF060606),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: Color(0xFFBDBDBD),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Liked tracks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.cloud_rounded,
                  size: 26,
                  color: Colors.white.withOpacity(0.78),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 76,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242426),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.cloud_rounded,
                        color: Colors.white.withOpacity(0.12),
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerWidgetPreview extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayerWidgetPreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF060606),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFF252527),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4E4E52),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.cloud_rounded,
                  color: Colors.white.withOpacity(0.12),
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: SizedBox(
                height: 86,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track Title · Artist Name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Spacer(),
                    Row(
                      children: [
                        _OutlinedControlButton(
                          icon: Icons.skip_previous_rounded,
                          size: 26,
                        ),
                        SizedBox(width: 16),
                        _OutlinedControlButton(
                          icon: Icons.play_arrow_rounded,
                          size: 30,
                        ),
                        SizedBox(width: 16),
                        _OutlinedControlButton(
                          icon: Icons.skip_next_rounded,
                          size: 26,
                        ),
                        Spacer(),
                        Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedControlButton extends StatelessWidget {
  final IconData icon;
  final double size;

  const _OutlinedControlButton({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.82),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    );
  }
}

class _MiniLikesPreview extends StatelessWidget {
  const _MiniLikesPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Liked tracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 5.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.cloud_rounded,
                size: 8,
                color: Colors.white.withOpacity(0.75),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202022),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerPreview extends StatelessWidget {
  const _MiniPlayerPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF202022),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 5.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    _MiniCircle(icon: Icons.skip_previous_rounded),
                    SizedBox(width: 4),
                    _MiniCircle(icon: Icons.play_arrow_rounded),
                    SizedBox(width: 4),
                    _MiniCircle(icon: Icons.skip_next_rounded),
                    Spacer(),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCircle extends StatelessWidget {
  final IconData icon;

  const _MiniCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 0.7,
        ),
      ),
      child: Icon(
        icon,
        size: 7,
        color: Colors.white,
      ),
    );
  }
}
