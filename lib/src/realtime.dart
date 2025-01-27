part of 'index.dart';

/// Teta Realtime - Use Realtime subscriptions
@lazySingleton
class TetaRealtime {
  ///Constructor
  TetaRealtime(
    this._serverRequestMetadata,
  );

  socket_io.Socket? _socket;

  ///This stores the token and project id headers.
  final ServerRequestMetadataStore _serverRequestMetadata;

  /// List of all the streams
  List<RealtimeSubscription> streams = [];

  Future<void> _openSocket() {
    final completer = Completer<void>();

    if (_socket?.connected == true) {
      completer.complete();
      return completer.future;
    }

    final opts = socket_io.OptionBuilder()
        .setPath('/nosql')
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build();

    _socket = socket_io.io(Constants.tetaUrl, opts);

    _socket?.onConnect((final dynamic _) {
      TetaCMS.printWarning('Socket Connected');
      completer.complete();
    });

    _socket?.on('change', (final dynamic data) {
      final event = SocketChangeEvent.fromJson(data as Map<String, dynamic>);

      for (final stream in streams) {
        if (stream.uid == event.uid) stream.callback(event);
      }
    });

    _socket!.connect();

    return completer.future;
  }

  void _closeStream(final String uid) {
    final stream = streams.firstWhere((final stream) => stream.uid == uid);
    streams.remove(stream);

    if (streams.isEmpty) {
      _socket!.close();
      _socket = null;
    }
  }

  /// Creates a websocket connection to the NoSql database
  /// that listens for events of type [action] and
  /// fires [callback] when the event is emitted.
  ///
  /// Returns a `NoSqlStream`
  ///
  Future<RealtimeSubscription> on({
    final StreamAction action = StreamAction.all,
    final String? collectionId,
    final String? documentId,
    final Function(SocketChangeEvent)? callback,
  }) async {
    final serverMetadata = _serverRequestMetadata.getMetadata();

    if (_socket == null) await _openSocket();

    TetaCMS.printWarning('Socket Id: ${_socket!.id}');

    final collId = collectionId ?? '*';
    final docId = action.targetDocument ? documentId : '*';
    if (docId == null) throw Exception('documentId is required');

    final uri = Uri.parse(
      '${Constants.tetaUrl}stream/listen/${_socket!.id}/${action.type}/${serverMetadata.prjId}/$collId/$docId',
    );

    final res = await http.post(
      uri,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${serverMetadata.token}',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Request resulted in ${res.statusCode} - ${res.body}');
    }

    final uid =
        (json.decode(res.body) as Map<String, dynamic>)['uid'] as String;

    final stream =
        RealtimeSubscription(uid, callback!, () => _closeStream(uid));
    streams.add(stream);
    return stream;
  }

  /// Creates a websocket connection to the NoSql database
  /// that listens for events of type [action]
  ///
  /// Returns a `Stream<SocketChangeEvent>`
  ///
  StreamController<SocketChangeEvent> stream({
    final StreamAction action = StreamAction.all,
    final String? collectionId,
    final String? documentId,
  }) {
    final streamController = StreamController<SocketChangeEvent>();
    on(
      collectionId: collectionId,
      callback: (final e) async* {
        streamController.add(e);
      },
    );
    return streamController;
  }

  /// Stream all collections without docs
  StreamController<List<CollectionObject>> streamCollections({
    final StreamAction action = StreamAction.all,
  }) {
    late final StreamController<List<CollectionObject>> streamController;
    streamController = StreamController<List<CollectionObject>>.broadcast(
      onCancel: () {
        if (!streamController.hasListener) {
          streamController.close();
        }
      },
    );
    TetaCMS.instance.analytics.insertEvent(
      TetaAnalyticsType.streamCollection,
      'Teta CMS: realtime request',
      <String, dynamic>{},
      isUserIdPreferableIfExists: true,
    );
    TetaCMS.instance.client.getCollections().then(streamController.add);
    on(
      callback: (final e) async {
        TetaCMS.log('on stream collections event. $e');
        final resp = await TetaCMS.instance.client.getCollections();
        TetaCMS.log('on resp get collections: $resp');
        streamController.add(resp);
      },
    );
    return streamController;
  }

  /// Stream a single collection with its docs only
  StreamController<List<dynamic>> streamCollection(
    final String collectionId, {
    final StreamAction action = StreamAction.all,
    final List<Filter> filters = const [],
    final int page = 0,
    final int limit = 20,
    final bool showDrafts = false,
  }) {
    late final StreamController<List<dynamic>> streamController;
    streamController = StreamController<List<dynamic>>.broadcast(
      onCancel: () {
        if (!streamController.hasListener) {
          streamController.close();
        }
      },
    );
    TetaCMS.instance.analytics.insertEvent(
      TetaAnalyticsType.streamCollection,
      'Teta CMS: realtime request',
      <String, dynamic>{},
      isUserIdPreferableIfExists: true,
    );
    TetaCMS.instance.client
        .getCollection(
          collectionId,
          filters: filters,
          limit: limit,
          page: page,
          showDrafts: showDrafts,
        )
        .then(streamController.add);
    on(
      collectionId: collectionId,
      callback: (final e) async {
        try {
          unawaited(
            TetaCMS.instance.analytics.insertEvent(
              TetaAnalyticsType.streamCollection,
              'Teta CMS: realtime request',
              <String, dynamic>{},
              isUserIdPreferableIfExists: true,
            ),
          );
        } catch (_) {}
        TetaCMS.printWarning('$filters, $limit, $page');
        final resp = await TetaCMS.instance.client.getCollection(
          collectionId,
          filters: filters,
          limit: limit,
          page: page,
          showDrafts: showDrafts,
        );
        streamController.add(resp);
      },
    );
    return streamController;
  }
}
