import { SceneType } from './SceneType';

export enum SceneContextTriggerType {
  WIFI = 'wifi',
  LOCATION = 'location'
}

export class SceneContextRule {
  id: number = 0;
  name: string = '';
  sceneType: SceneType = SceneType.LIBRARY;
  triggerType: SceneContextTriggerType = SceneContextTriggerType.WIFI;
  wifiSsid: string = '';
  addressName: string = '';
  latitude: number = 0;
  longitude: number = 0;
  radiusMeters: number = 300;
  autoSwitchEnabled: boolean = false;
  isEnabled: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;

  static create(name: string, sceneType: SceneType,
    triggerType: SceneContextTriggerType): SceneContextRule {
    const rule: SceneContextRule = new SceneContextRule();
    rule.name = name;
    rule.sceneType = sceneType;
    rule.triggerType = triggerType;
    rule.createdAt = Date.now();
    rule.updatedAt = rule.createdAt;
    return rule;
  }
}

export class ActiveSceneContext {
  ruleId: number = 0;
  sceneType: SceneType = SceneType.LIBRARY;
  triggerType: SceneContextTriggerType = SceneContextTriggerType.WIFI;
  activatedAt: number = 0;

  static fromRule(rule: SceneContextRule, activatedAt: number = Date.now()): ActiveSceneContext {
    const state: ActiveSceneContext = new ActiveSceneContext();
    state.ruleId = rule.id;
    state.sceneType = rule.sceneType;
    state.triggerType = rule.triggerType;
    state.activatedAt = activatedAt;
    return state;
  }
}

export class ResolvedSceneLocation {
  success: boolean = false;
  addressName: string = '';
  latitude: number = 0;
  longitude: number = 0;
  errorCode: string = '';

  static ok(addressName: string, latitude: number, longitude: number): ResolvedSceneLocation {
    const result: ResolvedSceneLocation = new ResolvedSceneLocation();
    result.success = true;
    result.addressName = addressName;
    result.latitude = latitude;
    result.longitude = longitude;
    return result;
  }

  static fail(errorCode: string): ResolvedSceneLocation {
    const result: ResolvedSceneLocation = new ResolvedSceneLocation();
    result.errorCode = errorCode;
    return result;
  }
}

export class ResolvedSceneWifi {
  success: boolean = false;
  ssid: string = '';
  errorCode: string = '';

  static ok(ssid: string): ResolvedSceneWifi {
    const result: ResolvedSceneWifi = new ResolvedSceneWifi();
    result.success = true;
    result.ssid = ssid;
    return result;
  }

  static fail(errorCode: string): ResolvedSceneWifi {
    const result: ResolvedSceneWifi = new ResolvedSceneWifi();
    result.errorCode = errorCode;
    return result;
  }
}
