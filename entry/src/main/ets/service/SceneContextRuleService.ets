import { common } from '@kit.AbilityKit';
import { OperationResult } from '../model/ServiceModels';
import { SceneContextRule, SceneContextTriggerType } from '../model/SceneContextModels';
import { SceneContextRuleRepository } from '../repository/SceneContextRuleRepository';
import { SceneContextStateRepository } from '../repository/SceneContextStateRepository';

const MIN_RADIUS_METERS: number = 100;
const MAX_RADIUS_METERS: number = 5000;

export class SceneContextRuleService {
  private readonly repository: SceneContextRuleRepository;
  private readonly stateRepository: SceneContextStateRepository;

  constructor(context: common.Context) {
    this.repository = new SceneContextRuleRepository(context);
    this.stateRepository = new SceneContextStateRepository(context);
  }

  listRules(): SceneContextRule[] {
    return this.repository.list(false);
  }

  listEnabledRules(): SceneContextRule[] {
    return this.repository.list(true);
  }

  getRule(id: number): SceneContextRule | undefined {
    return this.repository.getById(id);
  }

  saveRule(rule: SceneContextRule): OperationResult {
    if (rule.name.trim().length === 0) {
      return OperationResult.fail('name');
    }
    if (rule.triggerType === SceneContextTriggerType.WIFI) {
      const ssid: string = rule.wifiSsid.trim();
      if (ssid.length === 0 || ssid.length > 32) {
        return OperationResult.fail('wifi');
      }
      rule.wifiSsid = ssid;
      rule.addressName = '';
      rule.latitude = 0;
      rule.longitude = 0;
    } else {
      if (rule.addressName.trim().length === 0) {
        return OperationResult.fail('address');
      }
      if (!SceneContextRuleService.validCoordinates(rule.latitude, rule.longitude)) {
        return OperationResult.fail('coordinates');
      }
      if (!Number.isInteger(rule.radiusMeters) || rule.radiusMeters < MIN_RADIUS_METERS ||
        rule.radiusMeters > MAX_RADIUS_METERS) {
        return OperationResult.fail('radius');
      }
      rule.addressName = rule.addressName.trim();
      rule.wifiSsid = '';
    }
    return this.repository.save(rule) ? OperationResult.ok() : OperationResult.fail('storage');
  }

  deleteRule(id: number): boolean {
    if (id <= 0) {
      return false;
    }
    const activeRuleId: number = this.stateRepository.load()?.ruleId ?? 0;
    const removed: boolean = this.repository.remove(id);
    if (removed && activeRuleId === id) {
      this.stateRepository.clear();
    }
    return removed;
  }

  setRuleEnabled(id: number, enabled: boolean): boolean {
    if (id <= 0) {
      return false;
    }
    const changed: boolean = this.repository.setEnabled(id, enabled);
    if (changed && !enabled && this.stateRepository.load()?.ruleId === id) {
      this.stateRepository.clear();
    }
    return changed;
  }

  setAutoSwitchEnabled(id: number, enabled: boolean): boolean {
    return id > 0 && this.repository.setAutoSwitch(id, enabled);
  }

  static validCoordinates(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) && Number.isFinite(longitude) &&
      latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180 &&
      !(latitude === 0 && longitude === 0);
  }
}
