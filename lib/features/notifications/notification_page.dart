import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

///  *********************************************
///     NOTIFICATION PAGE
///  *********************************************
class NotificationPage extends StatefulWidget {
  const NotificationPage({
    super.key,
    required this.receivedAction,
  });

  final ReceivedAction receivedAction;

  @override
  NotificationPageState createState() => NotificationPageState();
}

class NotificationPageState extends State<NotificationPage> {
  bool get hasTitle => widget.receivedAction.title?.isNotEmpty ?? false;
  bool get hasBody => widget.receivedAction.body?.isNotEmpty ?? false;
  bool get hasLargeIcon => widget.receivedAction.largeIconImage != null;
  bool get hasBigPicture => widget.receivedAction.bigPictureImage != null;

  double bigPictureSize = 0.0;
  double largeIconSize = 0.0;
  bool isTotallyCollapsed = false;
  bool bigPictureIsPredominantlyWhite = true;

  ScrollController scrollController = ScrollController();

  Future<bool> isImagePredominantlyWhite(ImageProvider imageProvider) async {
    final paletteGenerator =
        await PaletteGenerator.fromImageProvider(imageProvider);
    final dominantColor =
        paletteGenerator.dominantColor?.color ?? Colors.transparent;
    return dominantColor.computeLuminance() > 0.5;
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_scrollListener);

    if (hasBigPicture) {
      isImagePredominantlyWhite(widget.receivedAction.bigPictureImage!)
          .then((isPredominantlyWhite) => setState(() {
                bigPictureIsPredominantlyWhite = isPredominantlyWhite;
              }));
    }
  }

  void _scrollListener() {
    bool pastScrollLimit = scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 240;

    if (!hasBigPicture) {
      isTotallyCollapsed = true;
      return;
    }

    if (isTotallyCollapsed) {
      if (!pastScrollLimit) {
        setState(() {
          isTotallyCollapsed = false;
        });
      }
    } else {
      if (pastScrollLimit) {
        setState(() {
          isTotallyCollapsed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bigPictureSize = MediaQuery.of(context).size.height * .4;
    largeIconSize =
        MediaQuery.of(context).size.height * (hasBigPicture ? .16 : .2);

    if (!hasBigPicture) {
      isTotallyCollapsed = true;
    }

    return Scaffold(
      body: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: isTotallyCollapsed || bigPictureIsPredominantlyWhite
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            systemOverlayStyle:
                isTotallyCollapsed || bigPictureIsPredominantlyWhite
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
            expandedHeight: hasBigPicture
                ? bigPictureSize + (hasLargeIcon ? 40 : 0)
                : (hasLargeIcon)
                    ? largeIconSize + 10
                    : MediaQuery.of(context).padding.top + 28,
            backgroundColor: Colors.transparent,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              centerTitle: true,
              expandedTitleScale: 1,
              collapseMode: CollapseMode.pin,
              title: (!hasLargeIcon)
                  ? null
                  : Stack(children: [
                      Positioned(
                        bottom: 0,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: hasBigPicture
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: largeIconSize,
                              width: largeIconSize,
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(largeIconSize)),
                                child: FadeInImage(
                                  placeholder: const NetworkImage(
                                      'https://cdn.syncfusion.com/content/images/common/placeholder.gif'),
                                  image: widget.receivedAction.largeIconImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
              background: hasBigPicture
                  ? Padding(
                      padding: EdgeInsets.only(bottom: hasLargeIcon ? 60 : 20),
                      child: FadeInImage(
                        placeholder: const NetworkImage(
                            'https://cdn.syncfusion.com/content/images/common/placeholder.gif'),
                        height: bigPictureSize,
                        width: MediaQuery.of(context).size.width,
                        image: widget.receivedAction.bigPictureImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          if (hasTitle)
                            TextSpan(
                              text: widget.receivedAction.title!,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          if (hasBody)
                            WidgetSpan(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: hasTitle ? 16.0 : 0.0,
                                ),
                                child: SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    child: Text(
                                        widget.receivedAction.bodyWithoutHtml ??
                                            '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium)),
                              ),
                            ),
                        ]),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black12,
                  padding: const EdgeInsets.all(20),
                  width: MediaQuery.of(context).size.width,
                  child: Text(widget.receivedAction.toString()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}