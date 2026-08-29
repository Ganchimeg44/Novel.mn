import '../models/user_model.dart';

/// `UserModel` классыг ӨӨРЧЛӨХГҮЙГЭЭР (шинэ field нэмэхгүйгээр) 18+
/// эсэхийг `birthDate`-ээс тооцоолох Dart extension.
///
/// Ашиглах жишээ: `user.isAdult`, `user.age`
extension UserModelAge on UserModel {
  /// Одоогийн насыг бүтэн жилээр тооцоолно. `birthDate` null бол null.
  int? get age {
    final birth = birthDate;
    if (birth == null) return null;

    final now = DateTime.now();
    var years = now.year - birth.year;
    final hasHadBirthdayThisYear = (now.month > birth.month) ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hasHadBirthdayThisYear) years -= 1;
    return years;
  }

  /// Төрсөн өдрөөс автоматаар тооцсон 18+ эсэх (BOL adult18Days эрхийн
  /// нэрлэгдсэн 18+ КОНТЕНТ ЭРХТЭЙ эсэхтэй ХОЛБООГҮЙ — энэ бол зөвхөн
  /// нас 18-аас дээш эсэхийг илэрхийлнэ).
  bool get isAdult {
    final calculatedAge = age;
    if (calculatedAge == null) return false;
    return calculatedAge >= 18;
  }
}