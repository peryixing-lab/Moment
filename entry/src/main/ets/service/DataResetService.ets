import { common } from '@kit.AbilityKit';
import { DatabaseManager } from '../database/DatabaseManager';
import {
  TABLE_COURSE,
  TABLE_TASK,
  TABLE_SCENE_RULE,
  TABLE_SCENE_CONTEXT_RULE,
  TABLE_FOCUS_SESSION
} from '../database/DatabaseSchema';

export class DataResetService {
  private static readonly SYNCED_TABLES: string[] = [
    TABLE_TASK,
    TABLE_COURSE,
    TABLE_SCENE_RULE,
    TABLE_SCENE_CONTEXT_RULE
  ];

  static hasLocalData(context: common.Context): boolean {
    if (!DatabaseManager.initialize(context)) {
      return false;
    }
    return DataResetService.SYNCED_TABLES.some(
      (table: string): boolean => DatabaseManager.readRows(context, table).length > 0);
  }

  static resetSyncedTables(context: common.Context): boolean {
    if (!DatabaseManager.initialize(context)) {
      return false;
    }
    let ok: boolean = true;
    const tables: string[] = [...DataResetService.SYNCED_TABLES, TABLE_FOCUS_SESSION];
    for (let index: number = 0; index < tables.length; index += 1) {
      const written: boolean = DatabaseManager.writeRows(context, tables[index], []);
      ok = written && ok;
    }
    return ok;
  }
}
