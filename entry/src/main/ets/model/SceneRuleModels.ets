import { SceneType } from './SceneType';

export class SceneRule {
  id: number = 0;
  name: string = '';
  sceneType: SceneType = SceneType.LIBRARY;
  daysOfWeek: number[] = new Array<number>();
  startMinutes: number = 540;
  endMinutes: number = 600;
  priority: number = 10;
  isEnabled: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;

  static create(name: string, sceneType: SceneType, daysOfWeek: number[], startMinutes: number,
    endMinutes: number, priority: number): SceneRule {
    const rule: SceneRule = new SceneRule();
    rule.name = name;
    rule.sceneType = sceneType;
    rule.daysOfWeek = daysOfWeek;
    rule.startMinutes = startMinutes;
    rule.endMinutes = endMinutes;
    rule.priority = priority;
    rule.createdAt = Date.now();
    rule.updatedAt = rule.createdAt;
    return rule;
  }
}
