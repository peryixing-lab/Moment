import { common } from '@kit.AbilityKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AppLogger } from '../common/AppLogger';
import {
  ActiveSceneContext,
  ResolvedSceneLocation,
  ResolvedSceneWifi,
  SceneContextRule,
  SceneContextTriggerType
} from '../model/SceneContextModels';
import { SceneContextStateRepository } from '../repository/SceneContextStateRepository';
import { SettingsRepository } from '../repository/SettingsRepository';
import { SceneContextPermissionService } from './SceneContextPermissionService';
import { SceneContextLocationService } from './SceneContextLocationService';
import { SceneContextRuleService } from './SceneContextRuleService';
import { SceneContextWifiService } from './SceneContextWifiService';

const EARTH_RADIUS_METERS: number = 6371000;
const RECHECK_INTERVAL_MS: number = 60000;

export class SceneContextMonitor {
  private readonly context: common.Context;
  private readonly onPrompt: (rule: SceneContextRule) => boolean;
  private readonly onStateChanged: () => void;
  private running: boolean = false;
  private evaluating: boolean = false;
  private wifiListening: boolean = false;
  private locationListening: boolean = false;
  private timerId: number = -1;
  private promptedRuleId: number = 0;
  private dismissedRuleId: number = 0;
  private readonly wifiConnectionCallback = (_state: number): void => {
    this.evaluateNow();
  };
  private readonly locationCallback = (_location: geoLocationManager.Location): void => {
    this.evaluateNow();
  };

  constructor(context: common.Context, onPrompt: (rule: SceneContextRule) => boolean,
    onStateChanged: () => void) {
    this.context = context;
    this.onPrompt = onPrompt;
    this.onStateChanged = onStateChanged;
  }

  start(): void {
    if (this.running) {
      this.evaluateNow();
      return;
    }
    this.running = true;
    this.evaluateNow();
    this.timerId = setInterval(() => this.evaluateNow(), RECHECK_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.evaluating = false;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.stopWifiListening();
    this.stopLocationListening();
    this.promptedRuleId = 0;
  }

  rulesChanged(): void {
    if (this.running) {
      this.evaluateNow();
    }
  }

  acceptRule(rule: SceneContextRule, alwaysAutomatic: boolean): boolean {
    if (alwaysAutomatic &&
      !new SceneContextRuleService(this.context).setAutoSwitchEnabled(rule.id, true)) {
      return false;
    }
    const activated: boolean = new SceneContextStateRepository(this.context).activate(rule);
    if (activated) {
      this.promptedRuleId = 0;
      this.dismissedRuleId = 0;
      this.onStateChanged();
    }
    return activated;
  }

  dismissRule(ruleId: number): void {
    if (ruleId > 0) {
      this.dismissedRuleId = ruleId;
    }
    this.promptedRuleId = 0;
  }

  private async evaluateNow(): Promise<void> {
    if (!this.running || this.evaluating) {
      return;
    }
    this.evaluating = true;
    try {
      if (!new SettingsRepository(this.context).initialize().settings.autoRecommendationEnabled) {
        this.syncSubscriptions(new Array<SceneContextRule>());
        this.clearActiveState();
        this.dismissedRuleId = 0;
        return;
      }
      const rules: SceneContextRule[] =
        new SceneContextRuleService(this.context).listEnabledRules();
      this.syncSubscriptions(rules);
      if (rules.length === 0) {
        this.clearActiveState();
        this.dismissedRuleId = 0;
        return;
      }

      const needsWifi: boolean = this.hasType(rules, SceneContextTriggerType.WIFI);
      const needsLocation: boolean = this.hasType(rules, SceneContextTriggerType.LOCATION) &&
        SceneContextPermissionService.hasPreciseLocationPermission();
      const wifiTask: Promise<ResolvedSceneWifi> = needsWifi ?
        SceneContextWifiService.currentWifi() :
        Promise.resolve(ResolvedSceneWifi.fail('not_needed'));
      const locationTask: Promise<ResolvedSceneLocation | undefined> = needsLocation ?
        SceneContextLocationService.currentCoordinates(true) :
        Promise.resolve<ResolvedSceneLocation | undefined>(undefined);
      const wifiResult: ResolvedSceneWifi = await wifiTask;
      const location: ResolvedSceneLocation | undefined = await locationTask;
      const ssid: string = wifiResult.success ? wifiResult.ssid : '';
      const matches: SceneContextRule[] = this.matchingRules(rules, ssid, location);
      this.handleMatches(matches);
    } catch (error) {
      AppLogger.error('Unable to evaluate scene context rules', error as Object);
    } finally {
      this.evaluating = false;
    }
  }

  private syncSubscriptions(rules: SceneContextRule[]): void {
    const needsWifi: boolean = this.hasType(rules, SceneContextTriggerType.WIFI);
    if (needsWifi && !this.wifiListening) {
      try {
        wifiManager.on('wifiConnectionChange', this.wifiConnectionCallback);
        this.wifiListening = true;
      } catch (error) {
        AppLogger.error('Unable to monitor Wi-Fi scene context', error as Object);
      }
    } else if (!needsWifi && this.wifiListening) {
      this.stopWifiListening();
    }

    const needsLocation: boolean = this.hasType(rules, SceneContextTriggerType.LOCATION) &&
      SceneContextPermissionService.hasPreciseLocationPermission();
    if (needsLocation && !this.locationListening) {
      try {
        geoLocationManager.onLocationChange({
          interval: 30,
          locationScenario: geoLocationManager.PowerConsumptionScenario.LOW_POWER_CONSUMPTION
        }, this.locationCallback);
        this.locationListening = true;
      } catch (error) {
        AppLogger.error('Unable to monitor location scene context', error as Object);
      }
    } else if (!needsLocation && this.locationListening) {
      this.stopLocationListening();
    }
  }

  private stopWifiListening(): void {
    if (!this.wifiListening) {
      return;
    }
    try {
      wifiManager.off('wifiConnectionChange', this.wifiConnectionCallback);
    } catch (error) {
      AppLogger.error('Unable to stop Wi-Fi scene monitoring', error as Object);
    }
    this.wifiListening = false;
  }

  private stopLocationListening(): void {
    if (!this.locationListening) {
      return;
    }
    try {
      geoLocationManager.offLocationChange(this.locationCallback);
    } catch (error) {
      AppLogger.error('Unable to stop location scene monitoring', error as Object);
    }
    this.locationListening = false;
  }

  private hasType(rules: SceneContextRule[], type: SceneContextTriggerType): boolean {
    for (let index: number = 0; index < rules.length; index += 1) {
      if (rules[index].triggerType === type) {
        return true;
      }
    }
    return false;
  }

  private matchingRules(rules: SceneContextRule[], ssid: string,
    location: ResolvedSceneLocation | undefined): SceneContextRule[] {
    const matches: SceneContextRule[] = new Array<SceneContextRule>();
    for (let index: number = 0; index < rules.length; index += 1) {
      const rule: SceneContextRule = rules[index];
      if (rule.triggerType === SceneContextTriggerType.WIFI) {
        if (ssid.length > 0 && rule.wifiSsid === ssid) {
          matches.push(rule);
        }
      } else if (location !== undefined && location.success) {
        const distance: number = SceneContextMonitor.distanceMeters(
          location.latitude, location.longitude, rule.latitude, rule.longitude);
        if (distance <= rule.radiusMeters) {
          matches.push(rule);
        }
      }
    }
    matches.sort((left: SceneContextRule, right: SceneContextRule) => {
      if (left.autoSwitchEnabled !== right.autoSwitchEnabled) {
        return left.autoSwitchEnabled ? -1 : 1;
      }
      return right.updatedAt - left.updatedAt;
    });
    return matches;
  }

  private handleMatches(matches: SceneContextRule[]): void {
    const stateRepository: SceneContextStateRepository =
      new SceneContextStateRepository(this.context);
    const active: ActiveSceneContext | undefined = stateRepository.load();
    if (matches.length === 0) {
      if (active !== undefined) {
        stateRepository.clear();
        this.onStateChanged();
      }
      this.dismissedRuleId = 0;
      this.promptedRuleId = 0;
      return;
    }

    const best: SceneContextRule = matches[0];
    if (this.dismissedRuleId > 0 && !this.containsRule(matches, this.dismissedRuleId)) {
      this.dismissedRuleId = 0;
    }
    if (active !== undefined && active.ruleId === best.id) {
      return;
    }
    if (active !== undefined && active.ruleId !== best.id) {
      stateRepository.clear();
      this.onStateChanged();
    }
    if (best.autoSwitchEnabled) {
      if (stateRepository.activate(best)) {
        this.promptedRuleId = 0;
        this.dismissedRuleId = 0;
        this.onStateChanged();
      }
      return;
    }
    if (this.promptedRuleId === best.id || this.dismissedRuleId === best.id) {
      return;
    }
    if (this.onPrompt(best)) {
      this.promptedRuleId = best.id;
    }
  }

  private clearActiveState(): void {
    const stateRepository: SceneContextStateRepository =
      new SceneContextStateRepository(this.context);
    if (stateRepository.load() !== undefined && stateRepository.clear()) {
      this.onStateChanged();
    }
  }

  private containsRule(rules: SceneContextRule[], ruleId: number): boolean {
    for (let index: number = 0; index < rules.length; index += 1) {
      if (rules[index].id === ruleId) {
        return true;
      }
    }
    return false;
  }

  private static distanceMeters(latitudeA: number, longitudeA: number,
    latitudeB: number, longitudeB: number): number {
    const toRadians: number = Math.PI / 180;
    const latitudeDelta: number = (latitudeB - latitudeA) * toRadians;
    const longitudeDelta: number = (longitudeB - longitudeA) * toRadians;
    const startLatitude: number = latitudeA * toRadians;
    const endLatitude: number = latitudeB * toRadians;
    const haversine: number = Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
      Math.cos(startLatitude) * Math.cos(endLatitude) *
      Math.sin(longitudeDelta / 2) * Math.sin(longitudeDelta / 2);
    return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
  }
}
