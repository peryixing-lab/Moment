import { common } from '@kit.AbilityKit';
import { SceneTypeCodec } from '../model/SceneType';
import { SceneFormAction } from './FormActionParser';
import { FocusService } from './FocusService';
import { SceneStateService } from './SceneStateService';
import { SceneViewModelService } from './SceneViewModelService';
import { TaskService } from './TaskService';

export class SceneActionService {
  static execute(context: common.Context, action: SceneFormAction): boolean {
    switch (action.action) {
      case 'switchScene':
        return SceneStateService.activateManual(context,
          SceneTypeCodec.next(SceneViewModelService.build(context).scene), false);
      case 'completeTask':
        return action.taskId > 0 && new TaskService(context).completeTask(action.taskId);
      case 'startFocus':
        return action.durationMinutes >= 1 && action.durationMinutes <= 240 &&
          new FocusService(context).startFocus(action.durationMinutes);
      case 'stopFocus':
        return new FocusService(context).stopFocus();
      case 'restoreAutoScene':
        return SceneStateService.restoreAutomatic(context);
      case 'openService':
        return true;
      default:
        return false;
    }
  }
}
