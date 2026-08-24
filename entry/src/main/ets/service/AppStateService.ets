import { common } from '@kit.AbilityKit';
import { SettingsReadResult } from '../model/SceneModels';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';

export class AppStateService {
  static settings(context: common.Context): SettingsReadResult {
    return new SettingsRepository(context).initialize();
  }

  static shouldShowOnboarding(context: common.Context): boolean {
    return !new SettingsRepository(context).initialize().settings.onboardingCompleted;
  }

  static updateAutoRecommendation(context: common.Context, enabled: boolean): boolean {
    const repository: SettingsRepository = new SettingsRepository(context);
    const result: SettingsReadResult = repository.initialize();
    result.settings.autoRecommendationEnabled = enabled;
    result.settings.manualScene = undefined;
    result.settings.manualSceneActivatedAt = 0;
    result.settings.manualSceneExpireAt = 0;
    result.settings.manualSceneLocked = false;
    result.settings.lastSceneUpdateTime = Date.now();
    return repository.save(result.settings);
  }

  static updateDefaultScene(context: common.Context, scene: SceneType): boolean {
    const repository: SettingsRepository = new SettingsRepository(context);
    const result: SettingsReadResult = repository.initialize();
    result.settings.defaultScene = scene;
    result.settings.lastSceneUpdateTime = Date.now();
    return repository.save(result.settings);
  }

  static updateSecondaryInfo(context: common.Context, enabled: boolean): boolean {
    const repository: SettingsRepository = new SettingsRepository(context);
    const result: SettingsReadResult = repository.initialize();
    result.settings.showSecondaryInfo = enabled;
    return repository.save(result.settings);
  }

  static resetDisplaySettings(context: common.Context): boolean {
    return new SettingsRepository(context).reset();
  }
}
