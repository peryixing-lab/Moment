import { ScenePresentation } from '../model/SceneModels';
import { SceneType } from '../model/SceneType';
import { MockDataProvider } from './MockDataProvider';

export class ScenePresentationService {
  static getPresentation(sceneType: SceneType): ScenePresentation {
    switch (sceneType) {
      case SceneType.LIBRARY:
        return ScenePresentation.create(sceneType, $r('app.string.scene_library_name'),
          $r('app.string.scene_library_subtitle'), $r('app.string.action_start_focus'),
          $r('app.string.value_class_time'), $r('app.string.value_data_structure'),
          $r('app.string.value_class_distance'), MockDataProvider.getInfoItems(sceneType));
      case SceneType.CLASS:
        return ScenePresentation.create(sceneType, $r('app.string.scene_class_name'),
          $r('app.string.scene_class_subtitle'), $r('app.string.action_view_course'),
          $r('app.string.value_class_time'), $r('app.string.value_data_structure'),
          $r('app.string.value_class_in_progress'), MockDataProvider.getInfoItems(sceneType));
      case SceneType.MEETING:
        return ScenePresentation.create(sceneType, $r('app.string.scene_meeting_name'),
          $r('app.string.scene_meeting_subtitle'), $r('app.string.action_ready_meeting'),
          $r('app.string.value_meeting_time'), $r('app.string.value_weekly_meeting'),
          $r('app.string.value_meeting_soon'), MockDataProvider.getInfoItems(sceneType));
      case SceneType.COMMUTE:
        return ScenePresentation.create(sceneType, $r('app.string.scene_commute_name'),
          $r('app.string.scene_commute_subtitle'), $r('app.string.action_check_items'),
          $r('app.string.value_departure_time'), $r('app.string.value_departure_suggestion'),
          $r('app.string.value_next_data_course'), MockDataProvider.getInfoItems(sceneType));
      default:
        return ScenePresentationService.getPresentation(SceneType.LIBRARY);
    }
  }
}
