import { common } from '@kit.AbilityKit';
import { OperationResult } from '../model/ServiceModels';
import { SceneRule } from '../model/SceneRuleModels';
import { SceneRuleRepository } from '../repository/SceneRuleRepository';

export class SceneRuleService {
  private readonly repository: SceneRuleRepository;

  constructor(context: common.Context) {
    this.repository = new SceneRuleRepository(context);
  }

  listRules(): SceneRule[] {
    return this.repository.list(false);
  }

  listEnabledRules(): SceneRule[] {
    return this.repository.list(true);
  }

  getRule(id: number): SceneRule | undefined {
    return this.repository.getById(id);
  }

  saveRule(rule: SceneRule): OperationResult {
    if (rule.name.trim().length === 0) {
      return OperationResult.fail('name');
    }
    if (rule.daysOfWeek.length === 0) {
      return OperationResult.fail('days');
    }
    if (rule.startMinutes < 0 || rule.startMinutes >= 1440 || rule.endMinutes <= 0 ||
      rule.endMinutes > 1440 || rule.startMinutes >= rule.endMinutes) {
      return OperationResult.fail('time');
    }
    if (rule.priority < 1 || rule.priority > 20) {
      return OperationResult.fail('priority');
    }
    return this.repository.save(rule) ? OperationResult.ok() : OperationResult.fail('storage');
  }

  deleteRule(id: number): boolean {
    return id > 0 && this.repository.remove(id);
  }

  setRuleEnabled(id: number, enabled: boolean): boolean {
    return id > 0 && this.repository.setEnabled(id, enabled);
  }
}
