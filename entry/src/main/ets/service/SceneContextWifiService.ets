import { BusinessError } from '@kit.BasicServicesKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { AppLogger } from '../common/AppLogger';
import { ResolvedSceneWifi } from '../model/SceneContextModels';
import { SceneContextPermissionService } from './SceneContextPermissionService';

const WIFI_INFO_TIMEOUT_MS: number = 5000;

export class SceneContextWifiService {
  static async currentWifi(): Promise<ResolvedSceneWifi> {
    if (!SceneContextPermissionService.hasWifiInfoPermission()) {
      return ResolvedSceneWifi.fail('permission');
    }
    try {
      if (!wifiManager.isWifiActive()) {
        return ResolvedSceneWifi.fail('wifi_disabled');
      }
    } catch (error) {
      AppLogger.error('Unable to inspect Wi-Fi state for scene context', error as Object);
      return SceneContextWifiService.failureFor(error as Object);
    }
    return SceneContextWifiService.linkedInfoWithTimeout();
  }

  private static linkedInfoWithTimeout(): Promise<ResolvedSceneWifi> {
    return new Promise<ResolvedSceneWifi>((resolve: (value: ResolvedSceneWifi) => void) => {
      let finished: boolean = false;
      const timerId: number = setTimeout(() => {
        if (!finished) {
          finished = true;
          AppLogger.error('Timed out while reading current Wi-Fi scene context');
          const fallback: ResolvedSceneWifi = SceneContextWifiService.linkedInfoSync();
          resolve(fallback.success ? fallback : ResolvedSceneWifi.fail('timeout'));
        }
      }, WIFI_INFO_TIMEOUT_MS);
      wifiManager.getLinkedInfo().then((info: wifiManager.WifiLinkedInfo) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        const ssid: string = SceneContextWifiService.normalizeSsid(info.ssid);
        resolve(ssid.length > 0 ? ResolvedSceneWifi.ok(ssid) : ResolvedSceneWifi.fail('not_connected'));
      }).catch((error: Object) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        AppLogger.error('Unable to read current Wi-Fi scene context', error);
        resolve(SceneContextWifiService.failureFor(error));
      });
    });
  }

  private static normalizeSsid(value: string): string {
    let ssid: string = value.trim();
    if (ssid.length >= 2 && ssid.startsWith('"') && ssid.endsWith('"')) {
      ssid = ssid.substring(1, ssid.length - 1).trim();
    }
    const normalized: string = ssid.toLowerCase();
    return normalized === '<unknown ssid>' || normalized === 'unknown ssid' ? '' : ssid;
  }

  private static linkedInfoSync(): ResolvedSceneWifi {
    try {
      const info: wifiManager.WifiLinkedInfo = wifiManager.getLinkedInfoSync();
      const ssid: string = SceneContextWifiService.normalizeSsid(info.ssid);
      return ssid.length > 0 ? ResolvedSceneWifi.ok(ssid) : ResolvedSceneWifi.fail('not_connected');
    } catch (error) {
      AppLogger.error('Unable to read current Wi-Fi with the synchronous fallback', error as Object);
      return SceneContextWifiService.failureFor(error as Object);
    }
  }

  private static failureFor(error: Object): ResolvedSceneWifi {
    const businessError: BusinessError = error as BusinessError;
    if (businessError.code === 201) {
      return ResolvedSceneWifi.fail('permission');
    }
    if (businessError.code === 2501001) {
      return ResolvedSceneWifi.fail('wifi_disabled');
    }
    return ResolvedSceneWifi.fail('unavailable');
  }
}
