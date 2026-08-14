import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_SCENE_CONTEXT_RULE } from '../database/DatabaseSchema';
import { SceneContextRule, SceneContextTriggerType } from '../model/SceneContextModels';
import { SceneType, SceneTypeCodec } from '../model/SceneType';

export class SceneContextRuleRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  list(enabledOnly: boolean = false): SceneContextRule[] {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_CONTEXT_RULE);
    const rules: SceneContextRule[] = new Array<SceneContextRule>();
    for (let index: number = 0; index < rows.length; index += 1) {
      const rule: SceneContextRule | undefined = this.decode(rows[index]);
      if (rule !== undefined && (!enabledOnly || rule.isEnabled)) {
        rules.push(rule);
      }
    }
    rules.sort((left: SceneContextRule, right: SceneContextRule) => {
      if (left.isEnabled !== right.isEnabled) {
        return left.isEnabled ? -1 : 1;
      }
      if (left.autoSwitchEnabled !== right.autoSwitchEnabled) {
        return left.autoSwitchEnabled ? -1 : 1;
      }
      return right.updatedAt - left.updatedAt;
    });
    return rules;
  }

  getById(id: number): SceneContextRule | undefined {
    const rules: SceneContextRule[] = this.list(false);
    for (let index: number = 0; index < rules.length; index += 1) {
      if (rules[index].id === id) {
        return rules[index];
      }
    }
    return undefined;
  }

  save(rule: SceneContextRule): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_CONTEXT_RULE);
    const now: number = Date.now();
    if (rule.id <= 0) {
      rule.id = DatabaseManager.nextId(this.context, TABLE_SCENE_CONTEXT_RULE);
      if (rule.id <= 0) {
        return false;
      }
      rule.createdAt = rule.createdAt > 0 ? rule.createdAt : now;
    }
    rule.updatedAt = now;
    const encoded: string = JSON.stringify(rule);
    let replaced: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const existing: SceneContextRule | undefined = this.decode(rows[index]);
      if (existing !== undefined && existing.id === rule.id) {
        rows[index] = encoded;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      rows.push(encoded);
    }
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_SCENE_CONTEXT_RULE, rows);
    if (saved) {
      AppLogger.info('Scene context rule saved');
    }
    return saved;
  }

  remove(id: number): boolean {
    return this.change(id, undefined, undefined);
  }

  setEnabled(id: number, enabled: boolean): boolean {
    return this.change(id, enabled, undefined);
  }

  setAutoSwitch(id: number, enabled: boolean): boolean {
    return this.change(id, undefined, enabled);
  }

  private change(id: number, enabled: boolean | undefined,
    autoSwitchEnabled: boolean | undefined): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_CONTEXT_RULE);
    const nextRows: string[] = new Array<string>();
    let found: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const rule: SceneContextRule | undefined = this.decode(rows[index]);
      if (rule !== undefined && rule.id === id) {
        found = true;
        if (enabled !== undefined || autoSwitchEnabled !== undefined) {
          if (enabled !== undefined) {
            rule.isEnabled = enabled;
          }
          if (autoSwitchEnabled !== undefined) {
            rule.autoSwitchEnabled = autoSwitchEnabled;
          }
          rule.updatedAt = Date.now();
          nextRows.push(JSON.stringify(rule));
        }
      } else {
        nextRows.push(rows[index]);
      }
    }
    return found && DatabaseManager.writeRows(this.context, TABLE_SCENE_CONTEXT_RULE, nextRows);
  }

  private decode(value: string): SceneContextRule | undefined {
    try {
      const raw: SceneContextRule = JSON.parse(value) as SceneContextRule;
      if (typeof raw.id !== 'number' || typeof raw.name !== 'string' ||
        typeof raw.sceneType !== 'string' || typeof raw.triggerType !== 'string') {
        return undefined;
      }
      const rule: SceneContextRule = new SceneContextRule();
      rule.id = raw.id;
      rule.name = raw.name;
      rule.sceneType = SceneTypeCodec.fromStorage(raw.sceneType, SceneType.LIBRARY);
      rule.triggerType = raw.triggerType === SceneContextTriggerType.LOCATION ?
        SceneContextTriggerType.LOCATION : SceneContextTriggerType.WIFI;
      rule.wifiSsid = typeof raw.wifiSsid === 'string' ? raw.wifiSsid : '';
      rule.addressName = typeof raw.addressName === 'string' ? raw.addressName : '';
      rule.latitude = typeof raw.latitude === 'number' ? raw.latitude : 0;
      rule.longitude = typeof raw.longitude === 'number' ? raw.longitude : 0;
      rule.radiusMeters = typeof raw.radiusMeters === 'number' ? raw.radiusMeters : 300;
      rule.autoSwitchEnabled = typeof raw.autoSwitchEnabled === 'boolean' ?
        raw.autoSwitchEnabled : false;
      rule.isEnabled = typeof raw.isEnabled === 'boolean' ? raw.isEnabled : true;
      rule.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : 0;
      rule.updatedAt = typeof raw.updatedAt === 'number' ? raw.updatedAt : 0;
      return rule;
    } catch (error) {
      AppLogger.error('Ignored invalid scene context rule row', error as Object);
      return undefined;
    }
  }
}
