import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLogger } from '../common/AppLogger';
import { AppSettings, SettingsReadResult } from '../model/SceneModels';
import { SceneType, SceneTypeCodec } from '../model/SceneType';

const STORE_NAME: string = 'moment_settings';
const KEY_AUTO_RECOMMENDATION: string = 'autoRecommendationEnabled';
const KEY_DEFAULT_SCENE: string = 'defaultScene';
const KEY_MANUAL_SCENE: string = 'manualScene';
const KEY_MANUAL_ACTIVATED_AT: string = 'manualSceneActivatedAt';
const KEY_MANUAL_EXPIRE_AT: string = 'manualSceneExpireAt';
const KEY_MANUAL_LOCKED: string = 'manualSceneLocked';
const KEY_SHOW_SECONDARY: string = 'showSecondaryInfo';
const KEY_LAST_UPDATE: string = 'lastSceneUpdateTime';
const KEY_ONBOARDING: string = 'onboardingCompleted';
const EMPTY_SCENE: string = '';
const DEFAULT_MANUAL_DURATION_MINUTES: number = 120;
const MANUAL_DURATION_MS: number = DEFAULT_MANUAL_DURATION_MINUTES * 60 * 1000;

export class SettingsRepository {
  private readonly context: common.Context;
  private store: preferences.Preferences | undefined = undefined;

  constructor(context: common.Context) {
    this.context = context;
  }

  initialize(): SettingsReadResult {
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return SettingsReadResult.create(AppSettings.defaults(), false);
    }
    try {
      if (!store.hasSync(KEY_ONBOARDING)) {
        const defaults: AppSettings = AppSettings.defaults(false);
        if (!this.save(defaults)) {
          return SettingsReadResult.create(defaults, false);
        }
      }
      const result: SettingsReadResult = this.load();
      if (result.success && this.needsManualMigration(store, result.settings)) {
        const now: number = Date.now();
        result.settings.manualSceneActivatedAt = now;
        result.settings.manualSceneExpireAt = now + MANUAL_DURATION_MS;
        result.settings.manualSceneLocked = false;
        result.settings.lastSceneUpdateTime = now;
        if (!this.save(result.settings)) {
          result.success = false;
        } else {
          AppLogger.info('Migrated legacy manual scene state');
        }
      }
      return result;
    } catch (error) {
      AppLogger.error('Unable to initialize preferences', error as Object);
      return SettingsReadResult.create(AppSettings.defaults(), false);
    }
  }

  load(): SettingsReadResult {
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return SettingsReadResult.create(AppSettings.defaults(), false);
    }
    try {
      const defaultScene: SceneType = SceneTypeCodec.fromStorage(
        this.readString(store, KEY_DEFAULT_SCENE, SceneTypeCodec.toStorage(SceneType.LIBRARY)),
        SceneType.LIBRARY
      );
      const manualValue: string = this.readString(store, KEY_MANUAL_SCENE, EMPTY_SCENE);
      const manualScene: SceneType | undefined = manualValue.length === 0 ? undefined :
        SceneTypeCodec.fromStorage(manualValue, defaultScene);
      const settings: AppSettings = AppSettings.create(
        this.readBoolean(store, KEY_AUTO_RECOMMENDATION, true),
        defaultScene,
        manualScene,
        this.readNumber(store, KEY_MANUAL_ACTIVATED_AT, 0),
        this.readNumber(store, KEY_MANUAL_EXPIRE_AT, 0),
        this.readBoolean(store, KEY_MANUAL_LOCKED, false),
        this.readBoolean(store, KEY_SHOW_SECONDARY, true),
        this.readNumber(store, KEY_LAST_UPDATE, 0),
        this.readBoolean(store, KEY_ONBOARDING, false)
      );
      return SettingsReadResult.create(settings, true);
    } catch (error) {
      AppLogger.error('Unable to read preferences', error as Object);
      return SettingsReadResult.create(AppSettings.defaults(), false);
    }
  }

  save(settings: AppSettings): boolean {
    const store: preferences.Preferences | undefined = this.getStore();
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(KEY_AUTO_RECOMMENDATION, settings.autoRecommendationEnabled);
      store.putSync(KEY_DEFAULT_SCENE, SceneTypeCodec.toStorage(settings.defaultScene));
      store.putSync(KEY_MANUAL_SCENE, settings.manualScene === undefined ? EMPTY_SCENE :
        SceneTypeCodec.toStorage(settings.manualScene));
      store.putSync(KEY_MANUAL_ACTIVATED_AT, settings.manualSceneActivatedAt);
      store.putSync(KEY_MANUAL_EXPIRE_AT, settings.manualSceneExpireAt);
      store.putSync(KEY_MANUAL_LOCKED, settings.manualSceneLocked);
      store.putSync(KEY_SHOW_SECONDARY, settings.showSecondaryInfo);
      store.putSync(KEY_LAST_UPDATE, settings.lastSceneUpdateTime);
      store.putSync(KEY_ONBOARDING, settings.onboardingCompleted);
      store.flushSync();
      AppLogger.info('Preferences saved');
      return true;
    } catch (error) {
      AppLogger.error('Unable to save preferences', error as Object);
      return false;
    }
  }

  setManualScene(sceneType: SceneType, locked: boolean = false,
    durationMinutes: number = DEFAULT_MANUAL_DURATION_MINUTES, now: number = Date.now()): boolean {
    const result: SettingsReadResult = this.initialize();
    result.settings.manualScene = sceneType;
    result.settings.manualSceneActivatedAt = now;
    result.settings.manualSceneExpireAt = locked ? 0 : now + durationMinutes * 60 * 1000;
    result.settings.manualSceneLocked = locked;
    result.settings.lastSceneUpdateTime = now;
    return this.save(result.settings);
  }

  setManualSceneLocked(locked: boolean, now: number = Date.now()): boolean {
    const result: SettingsReadResult = this.initialize();
    if (result.settings.manualScene === undefined) {
      return false;
    }
    result.settings.manualSceneLocked = locked;
    result.settings.manualSceneActivatedAt = now;
    result.settings.manualSceneExpireAt = locked ? 0 : now + MANUAL_DURATION_MS;
    result.settings.lastSceneUpdateTime = now;
    return this.save(result.settings);
  }

  clearManualScene(now: number = Date.now()): boolean {
    const result: SettingsReadResult = this.initialize();
    result.settings.manualScene = undefined;
    result.settings.manualSceneActivatedAt = 0;
    result.settings.manualSceneExpireAt = 0;
    result.settings.manualSceneLocked = false;
    result.settings.lastSceneUpdateTime = now;
    return this.save(result.settings);
  }

  completeOnboarding(defaultScene: SceneType): boolean {
    const result: SettingsReadResult = this.initialize();
    result.settings.defaultScene = defaultScene;
    result.settings.onboardingCompleted = true;
    return this.save(result.settings);
  }

  reset(): boolean {
    const current: SettingsReadResult = this.initialize();
    const defaults: AppSettings = AppSettings.defaults(current.settings.onboardingCompleted);
    return this.save(defaults);
  }

  private needsManualMigration(store: preferences.Preferences, settings: AppSettings): boolean {
    if (settings.manualScene === undefined) {
      return false;
    }
    try {
      return !store.hasSync(KEY_MANUAL_ACTIVATED_AT) || !store.hasSync(KEY_MANUAL_EXPIRE_AT) ||
        !store.hasSync(KEY_MANUAL_LOCKED);
    } catch (error) {
      AppLogger.error('Unable to inspect preference migration state', error as Object);
      return false;
    }
  }

  private getStore(): preferences.Preferences | undefined {
    if (this.store !== undefined) {
      return this.store;
    }
    try {
      const options: preferences.Options = {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      };
      this.store = preferences.getPreferencesSync(this.context, options);
      return this.store;
    } catch (error) {
      AppLogger.error('Unable to open preferences', error as Object);
      this.store = undefined;
      return undefined;
    }
  }

  private readBoolean(store: preferences.Preferences, key: string, fallback: boolean): boolean {
    try {
      const value: preferences.ValueType = store.getSync(key, fallback);
      return typeof value === 'boolean' ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  private readString(store: preferences.Preferences, key: string, fallback: string): string {
    try {
      const value: preferences.ValueType = store.getSync(key, fallback);
      return typeof value === 'string' ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  private readNumber(store: preferences.Preferences, key: string, fallback: number): number {
    try {
      const value: preferences.ValueType = store.getSync(key, fallback);
      return typeof value === 'number' ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }
}
