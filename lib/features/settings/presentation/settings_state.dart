import 'package:equatable/equatable.dart';

/// How far deleting all data has got.
enum DataDeletion { notStarted, inProgress, done, failed }

/// What the settings screen shows beyond its fixed rows.
class SettingsState extends Equatable {
  const SettingsState({
    this.deletion = DataDeletion.notStarted,
    this.couldNotOpenLink = false,
  });

  final DataDeletion deletion;

  /// Whether the last link the user tapped failed to open.
  final bool couldNotOpenLink;

  bool get isDeleting => deletion == DataDeletion.inProgress;

  SettingsState copyWith({DataDeletion? deletion, bool? couldNotOpenLink}) {
    return SettingsState(
      deletion: deletion ?? this.deletion,
      couldNotOpenLink: couldNotOpenLink ?? this.couldNotOpenLink,
    );
  }

  @override
  List<Object?> get props => [deletion, couldNotOpenLink];
}
