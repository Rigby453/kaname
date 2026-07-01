// Локальная "личность" профиля: отображаемое имя + выбранный аватар-пресет.
//
// Хранится локально (SharedPreferences), по образцу остальных
// core/settings/*_provider.dart (mascot_provider и т.д.) — работает и без
// аккаунта (офлайн/гость). Для реального аккаунта имя и аватар ДОПОЛНИТЕЛЬНО
// пушатся на сервер (PATCH /api/v1/auth/me: name, avatar_preset — ADR-062-подобный
// профиль-синк) и подхватываются на новом устройстве через applyServerProfile()
// (services/sync/profile_adoption_service.dart). Локальная запись — всегда
// первична и синхронна; серверный пуш — fire-and-forget, не блокирует UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart' show authControllerProvider;

// ---------------------------------------------------------------------------
// Аватар-пресеты
// ---------------------------------------------------------------------------

/// Набор безобидных пресетов-аватаров (без доступа к галерее/камере — не
/// тянем дополнительных разрешений для смены аватара). Первый — дефолт,
/// визуально совпадает с прежней иконкой-заглушкой профиля.
enum AvatarPreset {
  defaultAvatar,
  cat,
  dog,
  bird,
  fish,
  leaf,
  rocket,
  star,
  sun,
}

extension AvatarPresetX on AvatarPreset {
  /// Иконка пресета (рисуется в акцентном кружке текущей темы — см. _AvatarCircle).
  PhosphorIconData icon([PhosphorIconsStyle style = PhosphorIconsStyle.fill]) =>
      switch (this) {
        AvatarPreset.defaultAvatar => PhosphorIcons.user(style),
        AvatarPreset.cat => PhosphorIcons.cat(style),
        AvatarPreset.dog => PhosphorIcons.dog(style),
        AvatarPreset.bird => PhosphorIcons.bird(style),
        AvatarPreset.fish => PhosphorIcons.fish(style),
        AvatarPreset.leaf => PhosphorIcons.leaf(style),
        AvatarPreset.rocket => PhosphorIcons.rocket(style),
        AvatarPreset.star => PhosphorIcons.star(style),
        AvatarPreset.sun => PhosphorIcons.sun(style),
      };

  /// Ключ для хранения в SharedPreferences.
  String get storageKey => name;

  static AvatarPreset fromKey(String? key) => AvatarPreset.values.firstWhere(
        (a) => a.name == key,
        orElse: () => AvatarPreset.defaultAvatar,
      );
}

// ---------------------------------------------------------------------------
// Состояние: имя + аватар
// ---------------------------------------------------------------------------

class ProfileIdentity {
  const ProfileIdentity({this.displayName, this.avatar = AvatarPreset.defaultAvatar});

  /// Локальное переопределение имени. null/пусто → используем имя аккаунта
  /// (или дефолтную подпись "You" / "Offline mode" — резолвится в UI).
  final String? displayName;

  final AvatarPreset avatar;

  ProfileIdentity copyWith({String? displayName, AvatarPreset? avatar}) =>
      ProfileIdentity(
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
      );

  @override
  bool operator ==(Object other) =>
      other is ProfileIdentity &&
      other.displayName == displayName &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(displayName, avatar);
}

/// Публичные ключи SharedPreferences — переиспользуются в
/// profile_adoption_service.dart при адопции имени/аватара с сервера.
const kProfileDisplayNameKey = 'profile_display_name';
const kProfileAvatarPresetKey = 'profile_avatar_preset';

/// Максимальная длина имени (защита от overflow в шапке/строках профиля —
/// текст всё равно укорачивается ellipsis, но не даём вводить абсурдно длинные
/// строки).
const int kProfileDisplayNameMaxLength = 40;

class ProfileIdentityNotifier extends Notifier<ProfileIdentity> {
  @override
  ProfileIdentity build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final storedName = prefs.getString(kProfileDisplayNameKey);
    final storedAvatar = prefs.getString(kProfileAvatarPresetKey);
    return ProfileIdentity(
      displayName: (storedName != null && storedName.trim().isNotEmpty)
          ? storedName.trim()
          : null,
      avatar: AvatarPresetX.fromKey(storedAvatar),
    );
  }

  /// Сохранить новое отображаемое имя. Пустая строка / null сбрасывает
  /// переопределение — UI вернётся к имени аккаунта (или дефолту).
  Future<void> setDisplayName(String? name) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(kProfileDisplayNameKey);
      // copyWith() трактует null как "не менять", поэтому сброс задаём
      // через прямой конструктор, а не через copyWith(displayName: null).
      state = ProfileIdentity(displayName: null, avatar: state.avatar);
      return;
    }
    final clipped = trimmed.length > kProfileDisplayNameMaxLength
        ? trimmed.substring(0, kProfileDisplayNameMaxLength)
        : trimmed;
    await prefs.setString(kProfileDisplayNameKey, clipped);
    state = ProfileIdentity(displayName: clipped, avatar: state.avatar);
    _pushToServer(name: clipped);
  }

  Future<void> setAvatar(AvatarPreset avatar) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(kProfileAvatarPresetKey, avatar.storageKey);
    state = state.copyWith(avatar: avatar);
    _pushToServer(avatarPreset: avatar.storageKey);
  }

  /// Пуш имени/аватара на сервер (PATCH /auth/me) — только для реального
  /// аккаунта (гость/оффлайн не имеют куда слать). Локальная запись УЖЕ
  /// выполнена вызывающим методом — сеть не блокирует UI. Fire-and-forget:
  /// `.ignore()` глушит ошибки сети/сервера, не пробрасывая их в UI.
  void _pushToServer({String? name, String? avatarPreset}) {
    if (!ref.read(authControllerProvider.notifier).isAuthenticated) return;
    ref
        .read(apiClientProvider)
        .updateProfile(name: name, avatarPreset: avatarPreset)
        .ignore();
  }
}

final profileIdentityProvider =
    NotifierProvider<ProfileIdentityNotifier, ProfileIdentity>(
        ProfileIdentityNotifier.new);
