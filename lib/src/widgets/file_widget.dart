import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:pdfx/pdfx.dart';

class IsmChatPdfView extends StatefulWidget {
  const IsmChatPdfView({super.key, this.filePath});

  final String? filePath;

  @override
  State<IsmChatPdfView> createState() => _IsmChatPdfViewState();
}

class _IsmChatPdfViewState extends State<IsmChatPdfView> {
  late PdfController _pdfController;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final isNetowrk = widget.filePath?.contains('http');
      if (isNetowrk ?? false) {
        _pdfController = PdfController(
          document: PdfDocument.openData(
            IsmChatUtility.getUint8ListFromUrl(
              widget.filePath ?? '',
            ),
          ),
          initialPage: 1,
        );
      } else {
        _pdfController = PdfController(
          document: PdfDocument.openData(
            widget.filePath?.strigToUnit8List ?? Uint8List(0),
          ),
          initialPage: 1,
        );
      }
    } else {
      _pdfController = PdfController(
        document: PdfDocument.openAsset(widget.filePath ?? ''),
        initialPage: 1,
      );
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: PdfView(
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            pageLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
          controller: _pdfController,
        ),
      );
}

/// First-page JPEG for a PDF whose thumbnail URL is the file itself.
///
/// The chat bubble draws thumbnails with [Image.network]. A PDF URL fails
/// there. App-sent documents already store a real image in `thumbnailUrl` and
/// should keep using that. Call [shouldRenderPage] first, then this widget.
/// Bytes are cached by URL so scrolling does not download the file again.
class IsmChatPdfThumbnail extends StatefulWidget {
  const IsmChatPdfThumbnail({super.key, required this.pdfUrl});

  final String pdfUrl;

  /// True when the attachment is a PDF and its thumbnail is not a separate image.
  static bool shouldRenderPage(AttachmentModel? attachment) {
    final media = (attachment?.mediaUrl ?? '').trim();
    if (!media.isValidUrl) return false;
    if (!_isPdf(attachment)) return false;
    final thumb = (attachment?.thumbnailUrl ?? '').trim();
    if (thumb.isEmpty || thumb == media) return true;
    final path = (Uri.tryParse(thumb)?.path ?? thumb).toLowerCase();
    return path.endsWith('.pdf');
  }

  static bool _isPdf(AttachmentModel? attachment) {
    final mime = (attachment?.mimeType ?? '').toLowerCase();
    final extension = (attachment?.extension ?? '').toLowerCase();
    final name = (attachment?.name ?? '').toLowerCase();
    final media = (attachment?.mediaUrl ?? '').toLowerCase();
    return mime.contains('pdf') ||
        extension == 'pdf' ||
        name.endsWith('.pdf') ||
        media.split('?').first.endsWith('.pdf');
  }

  /// Page-1 JPEG bytes, keyed by the PDF URL.
  static final Map<String, Uint8List> _pageCache = {};

  @override
  State<IsmChatPdfThumbnail> createState() => _IsmChatPdfThumbnailState();
}

class _IsmChatPdfThumbnailState extends State<IsmChatPdfThumbnail> {
  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = IsmChatPdfThumbnail._pageCache[widget.pdfUrl];
    if (_bytes == null) {
      _load();
    }
  }

  @override
  void didUpdateWidget(IsmChatPdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfUrl != widget.pdfUrl) {
      _bytes = IsmChatPdfThumbnail._pageCache[widget.pdfUrl];
      _failed = false;
      if (_bytes == null) _load();
    }
  }

  Future<void> _load() async {
    final url = widget.pdfUrl;
    try {
      final data = await IsmChatUtility.getUint8ListFromUrl(url);
      final document = await PdfDocument.openData(data);
      final page = await document.getPage(1);
      final width = page.width <= 0 ? 480.0 : page.width;
      final scale = (480 / width).clamp(0.4, 2.0);
      final image = await page.render(
        width: width * scale,
        height: page.height * scale,
        backgroundColor: '#ffffff',
        quality: 80,
      );
      await page.close();
      await document.close();
      final bytes = image?.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      if (IsmChatPdfThumbnail._pageCache.length > 30) {
        IsmChatPdfThumbnail._pageCache
            .remove(IsmChatPdfThumbnail._pageCache.keys.first);
      }
      IsmChatPdfThumbnail._pageCache[url] = bytes;
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (_failed) return const SizedBox.shrink();
    return const ColoredBox(
      color: Color(0xFFECECEC),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// File badge for a chat document.
///
/// Word, Excel, and plain text used to fall through to the PDF icon. Resolve
/// the badge from the extension, then the file name, then the MIME type. The
/// chat bubble, the multi-document row, and the docs tab should all call
/// [IsmChatDocumentIcon.assetFor] instead of hard-coding [IsmChatAssets.pdfSvg].
enum IsmChatDocumentKind { pdf, word, excel, text }

class IsmChatDocumentIcon {
  const IsmChatDocumentIcon._();

  /// Asset path for [attachment]. Unknown documents stay on the PDF badge.
  static String assetFor(AttachmentModel? attachment) {
    switch (kindFor(attachment)) {
      case IsmChatDocumentKind.word:
        return IsmChatAssets.docSvg;
      case IsmChatDocumentKind.excel:
        return IsmChatAssets.xlsSvg;
      case IsmChatDocumentKind.text:
        return IsmChatAssets.txtSvg;
      case IsmChatDocumentKind.pdf:
        return IsmChatAssets.pdfSvg;
    }
  }

  /// PDF keeps a rendered page. Word and Excel use [assetFor] in the preview.
  /// Plain text shows a snippet. The JPEG in `thumbnailUrl` is for the API.
  static IsmChatDocumentKind kindFor(AttachmentModel? attachment) {
    final fromExtension = _kindFromExtension(attachment?.extension);
    if (fromExtension != null) return fromExtension;
    final fromName = _kindFromExtension(_extensionFromName(attachment?.name));
    if (fromName != null) return fromName;
    return _kindFromMime(attachment?.mimeType) ?? IsmChatDocumentKind.pdf;
  }

  static String? _extensionFromName(String? name) {
    final lower = (name ?? '').trim().toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || dot >= lower.length - 1) return null;
    return lower.substring(dot + 1);
  }

  static IsmChatDocumentKind? _kindFromExtension(String? extension) {
    switch ((extension ?? '').toLowerCase().replaceAll('.', '').trim()) {
      case 'doc':
      case 'docx':
        return IsmChatDocumentKind.word;
      case 'xls':
      case 'xlsx':
        return IsmChatDocumentKind.excel;
      case 'txt':
        return IsmChatDocumentKind.text;
      case 'pdf':
        return IsmChatDocumentKind.pdf;
      default:
        return null;
    }
  }

  static IsmChatDocumentKind? _kindFromMime(String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.isEmpty) return null;
    if (mime.contains('wordprocessingml') || mime.contains('msword')) {
      return IsmChatDocumentKind.word;
    }
    if (mime.contains('spreadsheet') || mime.contains('ms-excel')) {
      return IsmChatDocumentKind.excel;
    }
    if (mime.startsWith('text/')) return IsmChatDocumentKind.text;
    if (mime.contains('pdf')) return IsmChatDocumentKind.pdf;
    return null;
  }
}
