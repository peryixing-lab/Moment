import {
  abilityAccessCtrl,
  bundleManager,
  common,
  Permissions
} from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AppLogger } from '../common/AppLogger';

const APPROXIMATE_LOCATION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PRECISE_LOCATION: Permissions = 'ohos.permission.LOCATION';
const WIFI_INFO: Permissions = 'ohos.permission.GET_WIFI_INFO';

interface ScenePermissionRequestResult {
  authResults: number[];
  dialogShownResults?: boolean[];
}

export class SceneContextPermissionService {
  static hasPreciseLocationPermission(): boolean {
    return SceneContextPermissionService.hasPermission(APPROXIMATE_LOCATION) &&
      SceneContextPermissionService.hasPermission(PRECISE_LOCATION);
  }

  static hasWifiInfoPermission(): boolean {
    return SceneContextPermissionService.hasPermission(WIFI_INFO);
  }

  private static hasPermission(permission: Permissions): boolean {
    try {
      const bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = bundleInfo.appInfo.accessTokenId;
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      return manager.checkAccessTokenSync(tokenId, permission) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      AppLogger.error('Unable to check scene context permission', error as Object);
      return false;
    }
  }

  static async requestPreciseLocation(context: common.UIAbilityContext): Promise<boolean> {
    if (SceneContextPermissionService.hasPreciseLocationPermission()) {
      return true;
    }
    try {
      const permissions: Permissions[] = [APPROXIMATE_LOCATION, PRECISE_LOCATION];
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: ScenePermissionRequestResult = await (
        manager.requestPermissionsFromUser(context, permissions) as Promise<ScenePermissionRequestResult>
      );
      const granted: boolean = result.authResults.length === permissions.length &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED &&
        result.authResults[1] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      if (granted) {
        return true;
      }
      if (result.dialogShownResults !== undefined &&
        !SceneContextPermissionService.containsTrue(result.dialogShownResults)) {
        const statuses: abilityAccessCtrl.GrantStatus[] =
          await manager.requestPermissionOnSetting(context, permissions);
        return statuses.length === permissions.length &&
          statuses[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED &&
          statuses[1] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      }
      return false;
    } catch (error) {
      AppLogger.error('Unable to request location permission', error as Object);
      return false;
    }
  }

  static async ensureLocationSwitch(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (geoLocationManager.isLocationEnabled()) {
        return true;
      }
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      return await manager.requestGlobalSwitch(context, abilityAccessCtrl.SwitchType.LOCATION);
    } catch (error) {
      AppLogger.error('Unable to enable the system location switch', error as Object);
      try {
        return geoLocationManager.isLocationEnabled();
      } catch (_) {
        return false;
      }
    }
  }

  private static containsTrue(values: boolean[]): boolean {
    for (let index: number = 0; index < values.length; index += 1) {
      if (values[index]) {
        return true;
      }
    }
    return false;
  }
}
