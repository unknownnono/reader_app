import 'package:flutter/material.dart';

import '../../formats/text_content.dart';

/// 본문에서 찾은 한 곳
class TextMatch {
  const TextMatch(this.offset, this.snippet);

  /// 찾은 말이 시작하는 글자 오프셋
  final int offset;

  /// 앞뒤 글을 조금 붙인 미리보기
  final String snippet;
}

const maxSearchResults = 300;

/// [text]에서 [query]를 대소문자 구분 없이 찾는다. 최대 [maxSearchResults]곳까지.
List<TextMatch> searchText(String text, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final haystack = text.toLowerCase();
  final matches = <TextMatch>[];
  var from = 0;
  while (matches.length < maxSearchResults) {
    final index = haystack.indexOf(needle, from);
    if (index == -1) break;
    final start = (index - 20).clamp(0, text.length);
    final end = (index + needle.length + 40).clamp(0, text.length);
    final snippet = text
        .substring(start, end)
        .replaceAll(imagePlaceholder, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    matches.add(TextMatch(index, '${start > 0 ? '…' : ''}$snippet${end < text.length ? '…' : ''}'));
    from = index + needle.length;
  }
  return matches;
}

/// 본문 검색 화면. 결과를 누르면 (찾은 위치, 검색어)를 돌려주며 닫힌다.
class TextSearchScreen extends StatefulWidget {
  const TextSearchScreen({super.key, required this.text, this.initialQuery = ''});

  final String text;
  final String initialQuery;

  @override
  State<TextSearchScreen> createState() => _TextSearchScreenState();
}

class _TextSearchScreenState extends State<TextSearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late List<TextMatch> _matches = searchText(widget.text, widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: '본문 검색', border: InputBorder.none),
          onChanged: (value) => setState(() => _matches = searchText(widget.text, value)),
        ),
      ),
      body: query.isEmpty
          ? const Center(child: Text('찾을 말을 입력하세요.'))
          : _matches.isEmpty
              ? const Center(child: Text('찾는 말이 없습니다.'))
              : ListView.builder(
                  itemCount: _matches.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final capped = _matches.length >= maxSearchResults;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          capped
                              ? '처음 $maxSearchResults곳만 보여 줍니다.'
                              : '${_matches.length}곳에서 찾았습니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    final match = _matches[index - 1];
                    final percent = match.offset * 100 / widget.text.length;
                    return ListTile(
                      title: Text(match.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${percent.toStringAsFixed(1)}%'),
                      onTap: () => Navigator.pop(context, (match.offset, query)),
                    );
                  },
                ),
    );
  }
}
