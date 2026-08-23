import { common } from '@kit.AbilityKit';
import { AppMode } from '../model/SceneModels';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';

export class OnboardingService {
  static complete(context: common.Context, defaultScene: SceneType, appMode: AppMode): boolean {
    return new SettingsRepository(context).completeOnboarding(defaultScene, appMode);
  }
}
