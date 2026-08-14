import { common } from '@kit.AbilityKit';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';

export class OnboardingService {
  static complete(context: common.Context, defaultScene: SceneType): boolean {
    return new SettingsRepository(context).completeOnboarding(defaultScene);
  }
}
