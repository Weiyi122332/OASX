import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import 'package:oasx/modules/common/widgets/workbench_select.dart';
import 'package:oasx/modules/common/widgets/appbar.dart';
import 'package:oasx/modules/settings/oas_card.dart';
import 'package:oasx/modules/settings/settings_leave_handler.dart';
import 'package:oasx/modules/settings/system_card.dart';
import 'package:oasx/modules/settings/user_card.dart';
import 'package:oasx/modules/settings/illustration_card.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.standalone = true});

  final bool standalone;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const double _layoutSpacing = 12.0;
  static const double _wideLayoutBreakpoint = 960.0;
  static const double _navWidth = 220.0;
  static const double _topAlignmentTolerance = 12.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();
  late final List<_SettingsSection> _sections = [
    _SettingsSection(
      icon: Icons.manage_accounts_outlined,
      navTitleBuilder: () => I18n.userSetting.tr,
      cardBuilder: () => const UserSettingsCard(),
    ),
    _SettingsSection(
      icon: Icons.dns_outlined,
      navTitleBuilder: () => 'OAS ${I18n.setting.tr}',
      cardBuilder: () => const OasSettingsCard(),
    ),
    _SettingsSection(
      icon: Icons.tune_rounded,
      navTitleBuilder: () => I18n.systemSetting.tr,
      cardBuilder: () => const SystemSettingsCard(),
    ),
    _SettingsSection(
      icon: Icons.image_outlined,
      navTitleBuilder: () => I18n.illustrationSettings.tr,
      cardBuilder: () => const IllustrationSettingsCard(),
    ),
  ];

  int? _selectedSectionIndex;
  bool _isAutoScrolling = false;
  bool _lockSelectionToClickedNav = false;
  bool _hasHandledLeave = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncSelectedSectionByViewport();
    });
  }

  @override
  void dispose() {
    _handleLeaveSettings();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final body = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final settingList = _buildSettingList(keyboardInset);

          if (!isWide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: WorkbenchSelect<int>(
                      options: Iterable<int>.generate(_sections.length),
                      value: _selectedSectionIndex ?? 0,
                      optionLabel: (index) =>
                          _sections[index].navTitleBuilder(),
                      leadingIcon: _sections[_selectedSectionIndex ?? 0].icon,
                      semanticLabel: I18n.setting.tr,
                      onChanged: _scrollToSection,
                    ),
                  ),
                  Expanded(child: settingList),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrimaryNav(),
              const SizedBox(width: _layoutSpacing),
              Expanded(child: settingList),
            ],
          ).paddingOnly(left: 8, right: 8, top: 8);
        },
      ),
    );
    if (!widget.standalone) {
      return body;
    }
    return Scaffold(
      appBar: buildPlatformAppBar(context, routePath: '/settings'),
      body: body,
    );
  }

  void _handleLeaveSettings() {
    if (_hasHandledLeave) {
      return;
    }
    _hasHandledLeave = true;
    unawaited(handleSettingsLeaveEffect());
  }

  void _handleScroll() {
    if (_isAutoScrolling || _lockSelectionToClickedNav || !mounted) {
      return;
    }
    _syncSelectedSectionByViewport();
  }

  void _syncSelectedSectionByViewport() {
    final sectionIndex = _findCurrentSectionIndex();
    if (sectionIndex == _selectedSectionIndex) {
      return;
    }
    setState(() => _selectedSectionIndex = sectionIndex);
  }

  int? _findCurrentSectionIndex() {
    final viewportContext = _scrollViewKey.currentContext;
    if (viewportContext == null) {
      return _selectedSectionIndex;
    }

    final viewportRenderObject = viewportContext.findRenderObject();
    if (viewportRenderObject is! RenderBox || !viewportRenderObject.hasSize) {
      return _selectedSectionIndex;
    }

    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    int? passedTopSectionIndex;
    int? upcomingSectionIndex;
    var nearestUpcomingTop = double.infinity;

    for (var index = 0; index < _sections.length; index++) {
      final sectionContext = _sections[index].key.currentContext;
      if (sectionContext == null) {
        continue;
      }
      final sectionRenderObject = sectionContext.findRenderObject();
      if (sectionRenderObject is! RenderBox || !sectionRenderObject.hasSize) {
        continue;
      }

      final sectionTop =
          sectionRenderObject.localToGlobal(Offset.zero).dy - viewportTop;
      if (sectionTop <= _topAlignmentTolerance) {
        passedTopSectionIndex = index;
        continue;
      }
      if (sectionTop < nearestUpcomingTop) {
        nearestUpcomingTop = sectionTop;
        upcomingSectionIndex = index;
      }
    }

    return passedTopSectionIndex ??
        upcomingSectionIndex ??
        _selectedSectionIndex;
  }

  Future<void> _scrollToSection(int index) async {
    if (index < 0 || index >= _sections.length) {
      return;
    }

    final targetContext = _sections[index].key.currentContext;
    if (targetContext == null) {
      return;
    }

    setState(() {
      _selectedSectionIndex = index;
      _lockSelectionToClickedNav = true;
    });

    _isAutoScrolling = true;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: 0,
    );
    _isAutoScrolling = false;
  }

  Widget _buildSettingList(double keyboardInset) {
    return Scrollbar(
      controller: _scrollController,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (_isAutoScrolling || !mounted) {
            return false;
          }
          if (notification.direction != ScrollDirection.idle &&
              _lockSelectionToClickedNav) {
            setState(() => _lockSelectionToClickedNav = false);
          }
          return false;
        },
        child: SingleChildScrollView(
          key: _scrollViewKey,
          controller: _scrollController,
          keyboardDismissBehavior: PlatformUtils.isWeb
              ? ScrollViewKeyboardDismissBehavior.manual
              : ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: keyboardInset > 0 ? keyboardInset + 24 : 0,
          ),
          child: Column(
            children: _sections
                .map(
                  (section) => Container(
                    key: section.key,
                    margin: const EdgeInsets.only(bottom: _layoutSpacing),
                    child: section.cardBuilder(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, _SettingsSection section) {
    return Row(
      children: [
        Icon(
          section.icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            section.navTitleBuilder(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryNav() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: _navWidth,
      child: Card(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          children: [
            for (final (index, section) in _sections.indexed)
              ListTile(
                title: _sectionLabel(context, section),
                selected: index == _selectedSectionIndex,
                selectedTileColor: colors.primaryContainer,
                selectedColor: colors.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () => _scrollToSection(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection {
  _SettingsSection({
    required this.icon,
    required this.navTitleBuilder,
    required this.cardBuilder,
  });

  final GlobalKey key = GlobalKey();
  final IconData icon;
  final String Function() navTitleBuilder;
  final Widget Function() cardBuilder;
}
