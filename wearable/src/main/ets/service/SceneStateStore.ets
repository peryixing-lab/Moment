import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SceneType, SceneTypeCodec } from '../model/SceneType';

export class SceneState {
  sceneType: SceneType = SceneType.LIBRARY;
  isManual: boolean = false;
}

export class SceneStateStore {
  private static readonly STORE_NAME: string = 'wearable_scene_state';
  private static readonly KEY_SCENE_TYPE: string = 'scene_type';
  private static readonly KEY_IS_MANUAL: string = 'is_manual';

  static load(context: common.Context): SceneState {
    const state: SceneState = new SceneState();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: SceneStateStore.STORE_NAME });
      state.sceneType = SceneTypeCodec.fromStorage(
        store.getSync(SceneStateStore.KEY_SCENE_TYPE, '') as string, SceneType.LIBRARY);
      state.isManual = store.getSync(SceneStateStore.KEY_IS_MANUAL, false) as boolean;
    } catch (_) {
      state.sceneType = SceneType.LIBRARY;
      state.isManual = false;
    }
    return state;
  }

  static save(context: common.Context, sceneType: SceneType): void {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: SceneStateStore.STORE_NAME });
      store.putSync(SceneStateStore.KEY_SCENE_TYPE, SceneTypeCodec.toStorage(sceneType));
      store.putSync(SceneStateStore.KEY_IS_MANUAL, true);
      store.flush();
    } catch (_) {
    }
  }
}
