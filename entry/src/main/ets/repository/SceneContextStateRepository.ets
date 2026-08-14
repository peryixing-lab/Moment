import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLogger } from '../common/AppLogger';
import {
  ActiveSceneContext,
  SceneContextRule,
  SceneContextTriggerType
} from '../model/SceneContextModels';
import { SceneType, SceneTypeCodec } from '../model/SceneType';

const STORE_NAME: string = 'moment_scene_context_state';
const KEY_RULE_ID: string = 'ruleId';
const KEY_SCENE_TYPE: string = 'sceneType';
const KEY_TRIGGER_TYPE: string = 'triggerType';
const KEY_ACTIVATED_AT: string = 'activatedAt';

export class SceneContextStateRepository {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  load(): ActiveSceneContext | undefined {
    const store: preferences.Preferences | undefined = this.store();
    if (store === undefined) {
      return undefined;
    }
    try {
      const ruleValue: preferences.ValueType = store.getSync(KEY_RULE_ID, 0);
      const ruleId: number = typeof ruleValue === 'number' ? ruleValue : 0;
      if (ruleId <= 0) {
        return undefined;
      }
      const sceneValue: preferences.ValueType =
        store.getSync(KEY_SCENE_TYPE, SceneTypeCodec.toStorage(SceneType.LIBRARY));
      const triggerValue: preferences.ValueType =
        store.getSync(KEY_TRIGGER_TYPE, SceneContextTriggerType.WIFI);
      const activatedValue: preferences.ValueType = store.getSync(KEY_ACTIVATED_AT, 0);
      const state: ActiveSceneContext = new ActiveSceneContext();
      state.ruleId = ruleId;
      state.sceneType = SceneTypeCodec.fromStorage(
        typeof sceneValue === 'string' ? sceneValue : '', SceneType.LIBRARY);
      state.triggerType = triggerValue === SceneContextTriggerType.LOCATION ?
        SceneContextTriggerType.LOCATION : SceneContextTriggerType.WIFI;
      state.activatedAt = typeof activatedValue === 'number' ? activatedValue : 0;
      return state;
    } catch (error) {
      AppLogger.error('Unable to load active scene context', error as Object);
      return undefined;
    }
  }

  activate(rule: SceneContextRule): boolean {
    const store: preferences.Preferences | undefined = this.store();
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(KEY_RULE_ID, rule.id);
      store.putSync(KEY_SCENE_TYPE, SceneTypeCodec.toStorage(rule.sceneType));
      store.putSync(KEY_TRIGGER_TYPE, rule.triggerType);
      store.putSync(KEY_ACTIVATED_AT, Date.now());
      store.flushSync();
      AppLogger.info(`Activated scene context rule ${rule.id}`);
      return true;
    } catch (error) {
      AppLogger.error('Unable to activate scene context rule', error as Object);
      return false;
    }
  }

  clear(): boolean {
    const store: preferences.Preferences | undefined = this.store();
    if (store === undefined) {
      return false;
    }
    try {
      store.putSync(KEY_RULE_ID, 0);
      store.putSync(KEY_ACTIVATED_AT, 0);
      store.flushSync();
      AppLogger.info('Cleared active scene context rule');
      return true;
    } catch (error) {
      AppLogger.error('Unable to clear active scene context rule', error as Object);
      return false;
    }
  }

  private store(): preferences.Preferences | undefined {
    try {
      return preferences.getPreferencesSync(this.context, {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      });
    } catch (error) {
      AppLogger.error('Unable to open scene context state', error as Object);
      return undefined;
    }
  }
}
