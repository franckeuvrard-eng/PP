/// Marqueur « paramètre non fourni », pour les `copyWith`.
///
/// Sans lui, un `copyWith` ne peut pas distinguer « laisse ce champ tel quel »
/// de « mets ce champ à null » : passer `null` revient à ne rien passer, et il
/// devient impossible de retirer une photo, une note ou un email.
///
/// Usage dans un modèle :
/// ```dart
/// Child copyWith({Object? lastname = kUndefined}) => Child(
///       lastname: lastname == kUndefined ? this.lastname : lastname as String?,
///     );
/// ```
const Object kUndefined = Object();
