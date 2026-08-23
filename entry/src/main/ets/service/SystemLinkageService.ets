import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppLogger } from '../common/AppLogger';
import { SceneContextStateRepository } from '../repository/SceneContextStateRepository';
import { SettingsRepository } from '../repository/SettingsRepository';

const STORE_NAME: string = 'moment_scene_linkage';
const KEY_ENABLED: string = 'linkageEnabled';
const KEY_APPLIED: string = 'linkageApplied';
const KEY_SAVED_RINGER: string = 'savedRingerMode';
const UNKNOWN_RINGER_MODE: number = -1;

export class SystemLinkageService {
  static isEnabled(context: common.Context): boolean {
    const store: preferences.Preferences | undefined =
      SystemLinkageService.store(context);
    if (store === undefined) {
      return false;
    }
    try {
      return store.getSync(KEY_ENABLED, false) === true;
    } catch (error) {
      AppLogger.error('Unable to read the scene linkage setting', error as Object);
      return false;
    }
  }

  static setEnabled(context: common.Context, enabled: boolean): boolean {
    const store: preferences.Preferences | undefined =
      SystemLinkageService.store(context);
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(KEY_ENABLED, enabled);
      store.flushSync();
    } catch (error) {
      AppLogger.error('Unable to save the scene silence setting', error as Object);
      return false;
    }
    if (!enabled) {
      if (SystemLinkageService.isApplied(store)) {
        SystemLinkageService.restoreLinkedRinger(store);
      }
      return true;
    }
    if (SystemLinkageService.hasActiveScene(context)) {
      SystemLinkageService.applySceneEntry(context);
    }
    return true;
  }

  static applySceneEntry(context: common.Context): Promise<void> {
    const store: preferences.Preferences | undefined =
      SystemLinkageService.store(context);
    if (store === undefined || !SystemLinkageService.isEnabled(context)) {
      return Promise.resolve();
    }
    if (!SystemLinkageService.isApplied(store)) {
      try {
        store.putSync(KEY_APPLIED, true);
        store.putSync(KEY_SAVED_RINGER, SystemLinkageService.currentRinger());
        store.flushSync();
      } catch (error) {
        AppLogger.error('Unable to save the linked ringer state', error as Object);
        return Promise.resolve();
      }
    }
    return SystemLinkageService.writeRinger(audio.AudioRingMode.RINGER_MODE_SILENT);
  }

  static applySceneExit(context: common.Context): Promise<void> {
    const store: preferences.Preferences | undefined =
      SystemLinkageService.store(context);
    if (store === undefined) {
      return Promise.resolve();
    }
    return SystemLinkageService.restoreLinkedRinger(store);
  }

  static ringerGroupManager(): audio.AudioVolumeGroupManager | undefined {
    try {
      return audio.getAudioManager().getVolumeManager()
        .getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID);
    } catch (error) {
      AppLogger.error('Unable to access the system volume group manager', error as Object);
      return undefined;
    }
  }

  private static hasActiveScene(context: common.Context): boolean {
    try {
      if (new SceneContextStateRepository(context).load() !== undefined) {
        return true;
      }
      const settings = new SettingsRepository(context).initialize().settings;
      return settings.manualScene !== undefined &&
        (settings.manualSceneLocked || settings.manualSceneExpireAt > Date.now());
    } catch (error) {
      AppLogger.error('Unable to inspect the active scene state', error as Object);
      return false;
    }
  }

  private static store(context: common.Context): preferences.Preferences | undefined {
    try {
      return preferences.getPreferencesSync(context, {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      });
    } catch (error) {
      AppLogger.error('Unable to open the scene linkage store', error as Object);
      return undefined;
    }
  }

  private static isApplied(store: preferences.Preferences): boolean {
    try {
      return store.getSync(KEY_APPLIED, false) === true;
    } catch (error) {
      AppLogger.error('Unable to read the linked ringer flag', error as Object);
      return false;
    }
  }

  private static restoreLinkedRinger(store: preferences.Preferences): Promise<void> {
    if (!SystemLinkageService.isApplied(store)) {
      return Promise.resolve();
    }
    let savedMode: number = UNKNOWN_RINGER_MODE;
    try {
      const savedValue: preferences.ValueType = store.getSync(KEY_SAVED_RINGER,
        UNKNOWN_RINGER_MODE);
      savedMode = typeof savedValue === 'number' ? savedValue : UNKNOWN_RINGER_MODE;
      store.putSync(KEY_APPLIED, false);
      store.putSync(KEY_SAVED_RINGER, UNKNOWN_RINGER_MODE);
      store.flushSync();
    } catch (error) {
      AppLogger.error('Unable to clear the linked ringer state', error as Object);
      return Promise.resolve();
    }
    if (savedMode !== audio.AudioRingMode.RINGER_MODE_SILENT &&
      savedMode !== audio.AudioRingMode.RINGER_MODE_VIBRATE &&
      savedMode !== audio.AudioRingMode.RINGER_MODE_NORMAL) {
      return Promise.resolve();
    }
    return SystemLinkageService.writeRinger(savedMode as audio.AudioRingMode);
  }

  private static currentRinger(): number {
    const manager: audio.AudioVolumeGroupManager | undefined =
      SystemLinkageService.ringerGroupManager();
    if (manager === undefined) {
      return UNKNOWN_RINGER_MODE;
    }
    try {
      return manager.getRingerModeSync();
    } catch (error) {
      AppLogger.error('Unable to read the system ringer mode', error as Object);
      return UNKNOWN_RINGER_MODE;
    }
  }

  private static async writeRinger(mode: audio.AudioRingMode): Promise<void> {
    try {
      await audio.getAudioManager().setRingerMode(mode);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      AppLogger.error(
        `Unable to update the system ringer mode, code: ${businessError.code}`,
        error as Object);
      return;
    }
    const actual: number = SystemLinkageService.currentRinger();
    if (mode === audio.AudioRingMode.RINGER_MODE_SILENT ||
      mode === audio.AudioRingMode.RINGER_MODE_VIBRATE ||
      mode === audio.AudioRingMode.RINGER_MODE_NORMAL) {
      if (actual !== mode) {
        AppLogger.error(`System ringer mode mismatch after write: ` +
          `requested ${mode}, actual ${actual}`);
        return;
      }
    }
    AppLogger.info(`Updated the system ringer mode for scene silence linkage: ${mode}`);
  }
}
