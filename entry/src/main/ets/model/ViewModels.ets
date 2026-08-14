import { SceneSource } from './SceneModels';
import { SceneType } from './SceneType';

export enum SceneActionType {
  OPEN_SERVICE = 'openService',
  OPEN_COURSES = 'openCourses',
  OPEN_TASKS = 'openTasks',
  COMPLETE_TASK = 'completeTask',
  START_FOCUS = 'startFocus',
  STOP_FOCUS = 'stopFocus',
  RESTORE_AUTO_SCENE = 'restoreAutoScene'
}

export class SceneAction {
  type: SceneActionType = SceneActionType.OPEN_SERVICE;
  label: string = '';
  taskId: number = 0;
  durationMinutes: number = 0;

  static create(type: SceneActionType, label: string, taskId: number = 0,
    durationMinutes: number = 0): SceneAction {
    const action: SceneAction = new SceneAction();
    action.type = type;
    action.label = label;
    action.taskId = taskId;
    action.durationMinutes = durationMinutes;
    return action;
  }
}

export type RankingItemType = 'course' | 'task' | 'focus' | 'reminder';

export class RankingItem {
  id: string = '';
  type: RankingItemType = 'reminder';
  title: string = '';
  value: string = '';
  description: string = '';
  score: number = 0;
  action: SceneAction | undefined = undefined;
}

export class SceneViewModel {
  scene: SceneType = SceneType.LIBRARY;
  sceneName: string = '';
  sceneSymbol: string = '●';
  sceneSymbolResource: Resource = $r('sys.symbol.clock');
  subtitle: string = '';
  primaryInfo: RankingItem | undefined = undefined;
  secondaryInfo: RankingItem[] = new Array<RankingItem>();
  todayFocus: RankingItem[] = new Array<RankingItem>();
  upcoming: RankingItem[] = new Array<RankingItem>();
  primaryAction: SceneAction = new SceneAction();
  reasonText: string = '';
  sourceLabel: string = '';
  source: SceneSource = SceneSource.DEFAULT;
  confidence: number = 0;
  updatedAt: number = 0;
  isManualOverride: boolean = false;
  isManualLocked: boolean = false;
  manualOverrideRemainingMinutes: number = 0;
  focusRemainingMinutes: number = 0;
  hasRunningFocus: boolean = false;
  hasDataError: boolean = false;

  static empty(): SceneViewModel {
    const model: SceneViewModel = new SceneViewModel();
    model.sceneName = '此刻';
    model.subtitle = '重要的信息正在准备中';
    model.primaryAction = SceneAction.create(SceneActionType.OPEN_SERVICE, '打开此刻');
    model.updatedAt = Date.now();
    return model;
  }
}
