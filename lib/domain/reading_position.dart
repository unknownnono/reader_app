/// 포맷과 무관하게 읽던 위치를 표현한다.
class ReadingPosition {
  const ReadingPosition({this.section = 0, this.offset = 0, this.progress = 0});

  /// epub: 챕터 번호 / 만화: 페이지 번호 / txt: 0
  final int section;

  /// txt: 글자 오프셋 / epub: 챕터 내 위치.
  /// 글꼴 크기가 바뀌어도 위치를 잃지 않도록 페이지 번호 대신 오프셋을 쓴다.
  final int offset;

  /// 0.0~1.0, 서재 진행률 표시용
  final double progress;
}
