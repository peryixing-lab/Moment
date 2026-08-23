import { common } from '@kit.AbilityKit';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';
import { SystemLinkageService } from './SystemLinkageService';

export class SceneStateService {
  static activateManual(context: common.Context, scene: SceneType, locked: boolean = false,
    durationMinutes: number = 120): boolean {
    if (!locked && (durationMinutes < 1 || durationMinutes > 1440)) {
      return false;
    }
    const changed: boolean =
      new SettingsRepository(context).setManualScene(scene, locked, durationMinutes);
    if (changed) {
      SystemLinkageService.applySceneEntry(context);
    }
    return changed;
  }

  static setManualLocked(context: common.Context, locked: boolean): boolean {
    return new SettingsRepository(context).setManualSceneLocked(locked);
  }

  static restoreAutomatic(context: common.Context): boolean {
    const changed: boolean = new SettingsRepository(context).clearManualScene();
    if (changed) {
      SystemLinkageService.applySceneExit(context);
    }
    return changed;
  }
}
