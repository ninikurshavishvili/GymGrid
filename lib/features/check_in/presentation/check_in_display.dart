import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/entities/check_in.dart';
import '../domain/entities/check_in_photo.dart';
import '../domain/repositories/photo_locator.dart';

/// Turns stored photo paths into images.
extension PhotoImages on PhotoLocator {
  /// The image at [photoPath].
  ///
  /// A path the store rejects, which only a damaged database could hold,
  /// gives an image that fails to load. Every photo widget shows that as
  /// unavailable, so one bad path can't take a screen down.
  ImageProvider imageOf(String photoPath) {
    try {
      return FileImage(File.fromUri(uriOf(photoPath)));
    } on ArgumentError {
      return FileImage(File(''));
    }
  }

  /// The image for [photo], whether it's stored yet or not.
  ImageProvider imageOfPhoto(CheckInPhoto photo) => switch (photo) {
    StoredPhoto(:final photoPath) => imageOf(photoPath),
    PickedPhoto(:final sourcePath) => FileImage(File(sourcePath)),
  };
}

/// The time a check-in was made, in the device's 12 or 24-hour format.
extension CheckInTime on CheckIn {
  String timeLabel(BuildContext context) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(createdAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}
