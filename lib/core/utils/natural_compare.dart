final _chunk = RegExp(r'\d+|\D+');

/// 숫자 부분을 수로 비교하는 정렬. "2.jpg"가 "10.jpg"보다 앞에 온다.
int naturalCompare(String a, String b) {
  final left = _chunk.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final right = _chunk.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = BigInt.tryParse(left[i]);
    final y = BigInt.tryParse(right[i]);
    final result = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (result != 0) return result;
  }
  return left.length.compareTo(right.length);
}
