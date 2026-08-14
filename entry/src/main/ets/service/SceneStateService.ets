import { common } from '@kit.AbilityKit';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';

export class SceneStateService {
  static activateManual(context: common.Context, scene: SceneType, locked: boolean = false,
    durationMinutes: number = 120): boolean {
    if (!locked && (durationMinutes < 1 || durationMinutes > 1440)) {
      return false;
    }
    return new SettingsRepository(context).setManualScene(scene, locked, durationMinutes);
  }

  static setManualLocked(context: common.Context, locked: boolean): boolean {
    return new SettingsRepository(context).setManualSceneLocked(locked);
  }

  static restoreAutomatic(context: common.Context): boolean {
    return new SettingsRepository(context).clearManualScene();
  }
}
