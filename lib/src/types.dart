/// Sentinel class for unset values.
///
/// Used to distinguish between null (meaning "set to null" or "no value")
/// and unset (meaning "do not update").
class Unset {
  const Unset();

  @override
  String toString() => 'UNSET';
}

const unset = Unset();
