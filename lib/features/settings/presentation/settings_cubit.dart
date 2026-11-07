import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../check_in/domain/usecases/delete_all_check_ins.dart';
import 'link_opener.dart';
import 'settings_state.dart';

/// Runs the settings screen's actions: deleting all data and opening links.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required DeleteAllCheckIns deleteAllCheckIns,
    required LinkOpener linkOpener,
  }) : _deleteAllCheckIns = deleteAllCheckIns,
       _linkOpener = linkOpener,
       super(const SettingsState());

  final DeleteAllCheckIns _deleteAllCheckIns;
  final LinkOpener _linkOpener;

  /// Deletes every check-in and photo. The screen asks first.
  ///
  /// Screens showing check-ins empty by themselves, through the database
  /// stream. After a failure, calling this again deletes what's left.
  Future<void> deleteAllData() async {
    if (state.isDeleting) return;

    emit(state.copyWith(deletion: DataDeletion.inProgress));
    try {
      await _deleteAllCheckIns();
      if (isClosed) return;
      emit(state.copyWith(deletion: DataDeletion.done));
    } on Failure {
      if (isClosed) return;
      emit(state.copyWith(deletion: DataDeletion.failed));
    }
  }

  /// Opens [url] over the app, and says so if it can't.
  Future<void> openLink(Uri url) async {
    if (state.couldNotOpenLink) emit(state.copyWith(couldNotOpenLink: false));
    final opened = await _linkOpener.open(url);
    if (isClosed || opened) return;
    emit(state.copyWith(couldNotOpenLink: true));
  }
}
