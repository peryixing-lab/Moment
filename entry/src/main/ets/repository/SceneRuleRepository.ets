import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { DatabaseManager } from '../database/DatabaseManager';
import { TABLE_SCENE_RULE } from '../database/DatabaseSchema';
import { SceneRule } from '../model/SceneRuleModels';

export class SceneRuleRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  list(enabledOnly: boolean = false): SceneRule[] {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_RULE);
    const rules: SceneRule[] = new Array<SceneRule>();
    for (let index: number = 0; index < rows.length; index += 1) {
      const rule: SceneRule | undefined = this.decode(rows[index]);
      if (rule !== undefined && (!enabledOnly || rule.isEnabled)) {
        rules.push(rule);
      }
    }
    rules.sort((left: SceneRule, right: SceneRule) => {
      if (left.isEnabled !== right.isEnabled) {
        return left.isEnabled ? -1 : 1;
      }
      if (left.priority !== right.priority) {
        return right.priority - left.priority;
      }
      return right.updatedAt - left.updatedAt;
    });
    return rules;
  }

  getById(id: number): SceneRule | undefined {
    const rules: SceneRule[] = this.list(false);
    for (let index: number = 0; index < rules.length; index += 1) {
      if (rules[index].id === id) {
        return rules[index];
      }
    }
    return undefined;
  }

  save(rule: SceneRule): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_RULE);
    const now: number = Date.now();
    if (rule.id <= 0) {
      rule.id = DatabaseManager.nextId(this.context, TABLE_SCENE_RULE);
      if (rule.id <= 0) {
        return false;
      }
      rule.createdAt = rule.createdAt > 0 ? rule.createdAt : now;
    }
    rule.updatedAt = now;
    const encoded: string = JSON.stringify(rule);
    let replaced: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const existing: SceneRule | undefined = this.decode(rows[index]);
      if (existing !== undefined && existing.id === rule.id) {
        rows[index] = encoded;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      rows.push(encoded);
    }
    const saved: boolean = DatabaseManager.writeRows(this.context, TABLE_SCENE_RULE, rows);
    if (saved) {
      AppLogger.info('Scene rule saved');
    }
    return saved;
  }

  remove(id: number): boolean {
    return this.change(id, undefined);
  }

  setEnabled(id: number, enabled: boolean): boolean {
    return this.change(id, enabled);
  }

  private change(id: number, enabled: boolean | undefined): boolean {
    const rows: string[] = DatabaseManager.readRows(this.context, TABLE_SCENE_RULE);
    const nextRows: string[] = new Array<string>();
    let found: boolean = false;
    for (let index: number = 0; index < rows.length; index += 1) {
      const rule: SceneRule | undefined = this.decode(rows[index]);
      if (rule !== undefined && rule.id === id) {
        found = true;
        if (enabled !== undefined) {
          rule.isEnabled = enabled;
          rule.updatedAt = Date.now();
          nextRows.push(JSON.stringify(rule));
        }
      } else {
        nextRows.push(rows[index]);
      }
    }
    return found && DatabaseManager.writeRows(this.context, TABLE_SCENE_RULE, nextRows);
  }

  private decode(value: string): SceneRule | undefined {
    try {
      const raw: SceneRule = JSON.parse(value) as SceneRule;
      if (typeof raw.id !== 'number' || typeof raw.name !== 'string' ||
        typeof raw.sceneType !== 'string' || !(raw.daysOfWeek instanceof Array) ||
        typeof raw.startMinutes !== 'number' || typeof raw.endMinutes !== 'number') {
        return undefined;
      }
      const rule: SceneRule = new SceneRule();
      rule.id = raw.id;
      rule.name = raw.name;
      rule.sceneType = raw.sceneType;
      rule.daysOfWeek = raw.daysOfWeek;
      rule.startMinutes = raw.startMinutes;
      rule.endMinutes = raw.endMinutes;
      rule.priority = typeof raw.priority === 'number' ? raw.priority : 10;
      rule.isEnabled = typeof raw.isEnabled === 'boolean' ? raw.isEnabled : true;
      rule.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : 0;
      rule.updatedAt = typeof raw.updatedAt === 'number' ? raw.updatedAt : 0;
      return rule;
    } catch (error) {
      AppLogger.error('Ignored invalid scene rule row', error as Object);
      return undefined;
    }
  }
}
