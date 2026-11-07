/// How a check-in felt, on five steps from 20% to 100%. It's used for both
/// the workout's effort and the user's energy.
///
/// Five steps rather than any whole percentage, because nobody can honestly
/// tell 67% from 70%. Like a Swift enum with a raw value, each case carries
/// its [percent], which the charts plot. The database stores its own copy of
/// those numbers, so it can keep reading old rows if the steps ever change.
enum Rating {
  veryLow(20),
  low(40),
  medium(60),
  high(80),
  max(100);

  const Rating(this.percent);

  /// 20, 40, 60, 80 or 100.
  final int percent;
}
