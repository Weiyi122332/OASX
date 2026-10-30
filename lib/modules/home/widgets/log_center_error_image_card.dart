part of 'log_center_panel.dart';

/// Error screenshot loaded through the same API as downloads and reports.
class LogCenterErrorImageCard extends StatefulWidget {
  /// Creates one error image card.
  const LogCenterErrorImageCard({
    super.key,
    required this.controller,
    required this.detail,
    required this.image,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Error detail owning the image.
  final ScriptErrorLogDetail detail;

  /// Image metadata rendered by this card.
  final ScriptErrorImageInfo image;

  @override
  State<LogCenterErrorImageCard> createState() =>
      _LogCenterErrorImageCardState();
}

class _LogCenterErrorImageCardState extends State<LogCenterErrorImageCard> {
  late Future<ScriptErrorImageBytes> _image;

  @override
  void initState() {
    super.initState();
    _image = _loadImage();
  }

  @override
  void didUpdateWidget(covariant LogCenterErrorImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.id != widget.detail.id ||
        oldWidget.image.name != widget.image.name ||
        oldWidget.image.size != widget.image.size ||
        oldWidget.image.modifiedTime != widget.image.modifiedTime) {
      _image = _loadImage();
    }
  }

  Future<ScriptErrorImageBytes> _loadImage() =>
      ApiClient().getScriptErrorImage(widget.detail.id, widget.image.name);

  void _retry() {
    setState(() {
      _image = _loadImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.image.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _buildDownloadButton(),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: FutureBuilder<ScriptErrorImageBytes>(
              future: _image,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildFailure(snapshot.error!);
                final payload = snapshot.data;
                if (payload == null) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Tooltip(
                  message: '点击放大截图',
                  child: InkWell(
                    onTap: () => _showFullImage(payload),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Image.memory(
                        payload.bytes,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        semanticLabel: '错误截图：${widget.image.name}',
                        frameBuilder: (context, child, frame, synchronous) {
                          if (synchronous || frame != null) return child;
                          return const SizedBox(
                            height: 160,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFailure(error),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailure(Object error) => SizedBox(
    height: 180,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(height: 8),
          const Text('截图加载失败'),
          Text(
            error.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  void _showFullImage(ScriptErrorImageBytes payload) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.image.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      payload.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Text('截图加载失败：$error'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the per-image download button with loading feedback.
  Widget _buildDownloadButton() {
    return Obx(() {
      final loading = widget.controller.isErrorImageDownloading(widget.image);
      return IconButton(
        tooltip: I18n.homeLogDownloadImage.tr,
        onPressed: loading
            ? null
            : () => widget.controller.downloadErrorImage(widget.image),
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
      );
    });
  }
}
