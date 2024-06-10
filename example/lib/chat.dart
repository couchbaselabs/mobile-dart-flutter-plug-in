import 'dart:async';
import 'dart:convert';

import 'package:cbl_flutter_multiplatform/cbl_flutter_multiplatform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMessagesPage extends StatefulWidget {
  const ChatMessagesPage({super.key});

  @override
  State<ChatMessagesPage> createState() => _ChatMessagesPageState();
}

class _ChatMessagesPageState extends State<ChatMessagesPage> {
  List<dynamic> webMessages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  Future<ChatMessageRepository> setup() async {
    late Database database;
    late Collection chatMessages;
    late Replicator replicator;
    late ChatMessageRepository chatMessageRepository;

    database = await Database.openAsync('examplechat');

    chatMessages = await database.createCollection('message', 'chat');

    // update this with your device ip
    final targetURL = Uri.parse('ws://192.168.0.116:4984/examplechat');

    final targetEndpoint = UrlEndpoint(targetURL);

    final config = ReplicatorConfiguration(target: targetEndpoint);

    config.replicatorType = ReplicatorType.pushAndPull;

    config.enableAutoPurge = false;

    config.continuous = true;

    config.authenticator =
        BasicAuthenticator(username: "bob", password: "12345");

    config.addCollection(chatMessages);

    replicator = await Replicator.create(config);

    replicator.addChangeListener((change) {
      if (change.status.activity == ReplicatorActivityLevel.stopped) {
        print('Replication stopped');
      } else {
        print('Replicator is currently: ${change.status.activity.name}');
      }

      if (kIsWeb) {
        print("Web Data: ${change.status.webData}");

        if (change.status.webData != null &&
            change.status.webData != '' &&
            change.status.webData is String) {
          List<String> decodedMsg = json.decode(change.status.webData ?? '');

          setState(() {
            webMessages.addAll(decodedMsg);
          });
        }

        // for scrolling effect in web

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          } else {
            setState(() {});
          }
        });
      }
    });

    await replicator.start();

// for web to pass the replicator configuration back to the collection
    chatMessages.replicatorConfig(config);
    chatMessageRepository = ChatMessageRepository(database, chatMessages);

    return chatMessageRepository;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: kIsWeb
          ? ChatMessagesPageWeb(webMessages: webMessages)
          : FutureBuilder<ChatMessageRepository>(
              future: setup(),
              builder: (context, snapshot) => snapshot.data == null
                  ? const Center(child: CircularProgressIndicator())
                  : ChatMessagesPageMobile(
                      repository: snapshot.data,
                    )),
    );
  }
}

class ChatMessagesPageWeb extends StatefulWidget {
  final ScrollController? scrollController;
  final List<dynamic>? webMessages;

  const ChatMessagesPageWeb(
      {this.scrollController, this.webMessages, super.key});

  @override
  State<ChatMessagesPageWeb> createState() => _ChatMessagesPageWebState();
}

class _ChatMessagesPageWebState extends State<ChatMessagesPageWeb> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView.builder(
                reverse: false,
                controller: widget.scrollController,
                itemCount: widget.webMessages?.length,
                itemBuilder: (context, index) {
                  final item = widget.webMessages?[index];
                  return ChatMessageTileWeb(
                    message: item.containsKey('doc')
                        ? item['doc']['chatMessage']
                        : '-',
                    createdAt: item.containsKey('doc')
                        ? item['doc']['createdAt']
                        : DateFormat("yyyy-MM-ddTHH:mm:ss.SSSSSS")
                            .format(DateTime.now()),
                  );
                },
              ),
            ),
            const Divider(height: 0),
            _ChatMessageForm(
              onSubmit: (message) {},
            )
          ]),
        ),
      );
}

class ChatMessagesPageMobile extends StatefulWidget {
  const ChatMessagesPageMobile({this.repository, super.key});
  final ChatMessageRepository? repository;

  @override
  State<ChatMessagesPageMobile> createState() => _ChatMessagesPageMobileState();
}

class _ChatMessagesPageMobileState extends State<ChatMessagesPageMobile> {
  List<ChatMessage> _chatMessages = [];
  late StreamSubscription _chatMessagesSub;
  final CblPerformanceLogger _cblPerformanceLogger = CblPerformanceLogger();
  int count = 0;

  @override
  void initState() {
    super.initState();
    _cblPerformanceLogger.start('wsPerformance');

    _chatMessagesSub =
        widget.repository!.allChatMessagesStream().listen((chatMessages) {
      setState(() {
        _chatMessages = chatMessages;
        count = count + 1;
        _cblPerformanceLogger.end('wsPerformance');
        print(count);
      });
    });
  }

  @override
  void dispose() {
    _chatMessagesSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).primaryColor,
              child: Center(
                child: Text(
                  'Chat Count: ${_chatMessages.length}',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final chatMessage =
                      _chatMessages[_chatMessages.length - 1 - index];
                  return ChatMessageTileMobile(chatMessage: chatMessage);
                },
              ),
            ),
            const Divider(height: 0),
            _ChatMessageForm(onSubmit: widget.repository!.createChatMessage)
          ]),
        ),
      );
}

class ChatMessageTileWeb extends StatelessWidget {
  const ChatMessageTileWeb({this.message, required this.createdAt, super.key});

  final String? message;
  final String createdAt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMd().add_jm().format(DateTime.parse(createdAt)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            Text(message ?? '')
          ],
        ),
      );
}

class ChatMessageTileMobile extends StatelessWidget {
  const ChatMessageTileMobile({super.key, required this.chatMessage});
  final ChatMessage chatMessage;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMd().add_jm().format(chatMessage.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            Text(chatMessage.chatMessage.toString())
          ],
        ),
      );
}

class _ChatMessageForm extends StatefulWidget {
  const _ChatMessageForm({required this.onSubmit});
  final ValueChanged<String> onSubmit;
  @override
  _ChatMessageFormState createState() => _ChatMessageFormState();
}

class _ChatMessageFormState extends State<_ChatMessageForm> {
  late final TextEditingController _messageController;
  late final FocusNode _messageFocusNode;
  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    widget.onSubmit(message);
    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration:
                    const InputDecoration.collapsed(hintText: 'Message'),
                autofocus: true,
                focusNode: _messageFocusNode,
                controller: _messageController,
                minLines: 1,
                maxLines: 10,
                style: Theme.of(context).textTheme.bodyMedium,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 5),
            TextButton(
              onPressed: _onSubmit,
              child: const Text('Send'),
            )
          ],
        ),
      );
}

abstract class ChatMessage {
  String get id;
  String get chatMessage;
  DateTime get createdAt;
}

class CblChatMessage extends ChatMessage {
  CblChatMessage(this.dict);
  final DictionaryInterface dict;
  @override
  String get id => dict.documentId;

  @override
  DateTime get createdAt => dict.value('createdAt')!;

  @override
  String get chatMessage => dict.value('chatMessage') ?? '-';
}

extension DictionaryDocumentIdExt on DictionaryInterface {
  String get documentId {
    final self = this;
    return self is Document ? self.id : self.value('id')!;
  }
}

class ChatMessageRepository {
  ChatMessageRepository(this.database, this.collection);
  final Database database;
  final Collection collection;

  Future<ChatMessage> createChatMessage(String message) async {
    final doc = MutableDocument({
      'type': 'chatMessage',
      'createdAt': DateTime.now(),
      'userId': 'bob',
      'chatMessage': message,
    });
    await collection.saveDocument(doc);
    return CblChatMessage(doc);
  }

  Stream<List<ChatMessage>> allChatMessagesStream() {
    // this is needed because this is not available currently in web since we don't have
    // database that handles the data of the web.
    if (!kIsWeb) {
      final query = const QueryBuilder()
          .select(
            SelectResult.expression(Meta.id),
            SelectResult.property('createdAt'),
            SelectResult.property('chatMessage'),
          )
          .from(DataSource.collection(collection))
          .where(Expression.property('type')
              .equalTo(Expression.value('chatMessage')))
          .orderBy(Ordering.property('createdAt'));

      return query.changes().asyncMap(
            (change) => change.results
                .asStream()
                .map((result) => CblChatMessage(result))
                .toList(),
          );
    } else {
      return const Stream.empty();
    }
  }
}