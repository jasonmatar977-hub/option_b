part of '../../main.dart';

class DemoChatScreen extends StatefulWidget {
  const DemoChatScreen({
    super.key,
    required this.title,
    required this.meLabel,
    required this.themLabel,
  });

  final String title;
  final String meLabel;
  final String themLabel;

  @override
  State<DemoChatScreen> createState() => _DemoChatScreenState();
}

class _DemoChatScreenState extends State<DemoChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final List<_ChatMessage> _messages = const [
    _ChatMessage(sender: 'System', text: 'Live simulation chat'),
    _ChatMessage(sender: 'Customer', text: 'I am near the main entrance.'),
    _ChatMessage(
      sender: 'Driver',
      text: 'I am on my way. Please confirm the pickup point.',
    ),
  ].toList();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(sender: widget.meLabel, text: text));
      _messageCtrl.clear();
    });
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            sender: widget.themLabel,
            text: 'Got it. I am on the way.',
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final mine = message.sender == widget.meLabel;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: mine
                            ? kAccentBlue.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.sender,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(message.text),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final String sender;
  final String text;
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
