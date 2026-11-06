import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatFileMessage extends StatelessWidget {
  const IsmChatFileMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final memoryImage = message.attachments?.first.mediaUrl?.isValidUrl == true
        ? MemoryImage(Uint8List(0))
        : IsmChatUtility.chatPageController.getMemoryImage(message.sentAt,
            (message.attachments?.first.thumbnailUrl ?? '').strigToUnit8List);
    final attachment = message.attachments?.first;
    final documentIcon = IsmChatDocumentIcon.assetFor(attachment);
    final docKind = IsmChatDocumentIcon.kindFor(attachment);
    // Word and Excel have no page render. The JPEG in thumbnailUrl is only
    // for the API. Keep the type badge in the area above the file name.
    final showTypeThumbnail = docKind == IsmChatDocumentKind.word ||
        docKind == IsmChatDocumentKind.excel;
    // Plain text: show the first lines from the file URL or local path.
    final showTxtPreview = docKind == IsmChatDocumentKind.text;
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    return BlurFilter.widget(
      isBlured: data?.shouldBlured ?? false,
      sigmaX: data?.sigmaX ?? 3,
      sigmaY: data?.sigmaY ?? 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(IsmChatDimens.ten),
            ),
            child: kIsWeb
                ? Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        alignment: Alignment.topCenter,
                        width: double.maxFinite,
                        height: IsmChatDimens.twoHundredTwenty,
                        child: showTxtPreview
                            ? _TxtFilePreview(
                                attachment: attachment,
                              )
                            : showTypeThumbnail
                                ? _DocumentTypeThumbnail(asset: documentIcon)
                                : IsmChatPdfView(
                                    filePath: attachment?.mediaUrl,
                                  ),
                      ),
                      Container(
                        height: IsmChatDimens.fifty,
                        width: double.maxFinite,
                        color: message.backgroundColor,
                        child: Container(
                          color: (message.sentByMe
                                  ? IsmChatColors.whiteColor
                                  : IsmChatColors.greyColor)
                              .applyIsmOpacity(0.2),
                          padding: IsmChatDimens.edgeInsets4,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                documentIcon,
                                height: IsmChatDimens.thirtyTwo,
                                width: IsmChatDimens.thirtyTwo,
                              ),
                              IsmChatDimens.boxWidth4,
                              Flexible(
                                child: Text(
                                  attachment?.name ?? '',
                                  style: message.style,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      if (attachment?.mediaUrl?.isNotEmpty == true)
                        SizedBox(
                            width: IsmChatDimens.percentWidth(.5),
                            height: IsmChatDimens.oneHundredThirty,
                            child: showTxtPreview
                                ? _TxtFilePreview(
                                    attachment: attachment,
                                  )
                                : showTypeThumbnail
                                    ? _DocumentTypeThumbnail(
                                        asset: documentIcon,
                                      )
                                    : IsmChatPdfThumbnail.shouldRenderPage(
                                            attachment)
                                        // Web used to store the PDF URL in thumbnailUrl.
                                        // Image.network cannot decode that; render page 1.
                                        ? IsmChatPdfThumbnail(
                                            pdfUrl: attachment?.mediaUrl ?? '',
                                          )
                                        : attachment?.mediaUrl?.isValidUrl ==
                                                true
                                            ? Image.network(
                                                attachment?.thumbnailUrl ?? '',
                                                fit: BoxFit.fill,
                                              )
                                            : Image(
                                                image: memoryImage,
                                                fit: BoxFit.fill,
                                                gaplessPlayback: true,
                                              )),
                      Container(
                        height: context.width * 0.15,
                        width: double.maxFinite,
                        color: message.backgroundColor,
                        child: Container(
                          color: (message.sentByMe
                                  ? IsmChatColors.whiteColor
                                  : IsmChatColors.greyColor)
                              .applyIsmOpacity(0.2),
                          padding: IsmChatDimens.edgeInsets4,
                          child: Material(
                            color: Colors.transparent,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  documentIcon,
                                  height: IsmChatDimens.thirtyTwo,
                                  width: IsmChatDimens.thirtyTwo,
                                ),
                                IsmChatDimens.boxWidth4,
                                Flexible(
                                  child: Text(
                                    attachment?.name ?? '',
                                    style: message.style,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (message.isUploading == true)
            IsmChatUtility.circularProgressBar(
                IsmChatColors.blackColor, IsmChatColors.whiteColor),
        ],
      ),
    );
  }
}

/// Fills the document preview when the file is Word or Excel.
///
/// pdfx can only render PDFs. The badge sits above the file-name bar, which
/// overlays the bottom of this box. Reuse [IsmChatDocumentIcon.assetFor].
class _DocumentTypeThumbnail extends StatelessWidget {
  const _DocumentTypeThumbnail({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
        child: ColoredBox(
          color: const Color(0xFFF4F6F8),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: IsmChatDimens.eight),
              child: SvgPicture.asset(
                asset,
                height: IsmChatDimens.fortyEight,
                width: IsmChatDimens.fortyEight,
              ),
            ),
          ),
        ),
      );
}

/// First chunk of a plain-text file for the bubble preview (not the API JPG).
class _TxtFilePreview extends StatefulWidget {
  const _TxtFilePreview({
    required this.attachment,
  });

  final AttachmentModel? attachment;

  @override
  State<_TxtFilePreview> createState() => _TxtFilePreviewState();
}

class _TxtFilePreviewState extends State<_TxtFilePreview> {
  static const int _maxChars = 800;

  String? _preview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TxtFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment?.mediaUrl != widget.attachment?.mediaUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final attachment = widget.attachment;
    final media = (attachment?.mediaUrl ?? '').trim();
    if (media.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _preview = '';
        });
      }
      return;
    }

    try {
      Uint8List bytes;
      if (media.isValidUrl) {
        bytes = await IsmChatUtility.getUint8ListFromUrl(media);
      } else if (!kIsWeb) {
        bytes = await File(media).readAsBytes();
      } else {
        bytes = media.strigToUnit8List;
      }

      final raw = utf8.decode(bytes, allowMalformed: true);
      var text =
          raw.replaceAll('\u0000', '').replaceAll(RegExp(r'\r\n?'), '\n');
      if (text.length > _maxChars) {
        text = '${text.substring(0, _maxChars).trim()}…';
      }

      if (mounted) {
        setState(() {
          _preview = text;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preview = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF4F6F8),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_preview == null || _preview!.isEmpty) {
      return SizedBox.expand(
        child: ColoredBox(
          color: const Color(0xFFF4F6F8),
          child: Center(
            child: SvgPicture.asset(
              IsmChatAssets.txtSvg,
              height: IsmChatDimens.fortyEight,
              width: IsmChatDimens.fortyEight,
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFFF4F6F8),
      child: Padding(
        padding: IsmChatDimens.edgeInsets8,
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: SelectableText(
              _preview!,
              style: TextStyle(
                fontSize: IsmChatDimens.twelve,
                height: 1.35,
                color: const Color(0xFF2C2C2C),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
