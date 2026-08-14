import { SceneInfoItem } from '../model/SceneModels';
import { SceneType } from '../model/SceneType';

export class MockDataProvider {
  static getInfoItems(sceneType: SceneType): SceneInfoItem[] {
    switch (sceneType) {
      case SceneType.LIBRARY:
        return MockDataProvider.libraryItems();
      case SceneType.CLASS:
        return MockDataProvider.classItems();
      case SceneType.MEETING:
        return MockDataProvider.meetingItems();
      case SceneType.COMMUTE:
        return MockDataProvider.commuteItems();
      default:
        return MockDataProvider.libraryItems();
    }
  }

  private static libraryItems(): SceneInfoItem[] {
    return [
      SceneInfoItem.create('library_next_class', $r('app.string.info_next_class'),
        $r('app.string.value_data_structure'), $r('app.string.value_class_time'), 100),
      SceneInfoItem.create('library_tasks', $r('app.string.info_study_tasks'),
        $r('app.string.value_two_learning_tasks'), $r('app.string.value_quicksort_review'), 90),
      SceneInfoItem.create('library_borrow', $r('app.string.info_borrow_due'),
        $r('app.string.value_network_book'), $r('app.string.value_due_three_days'), 80)
    ];
  }

  private static classItems(): SceneInfoItem[] {
    return [
      SceneInfoItem.create('class_current', $r('app.string.info_current_course'),
        $r('app.string.value_data_structure'), $r('app.string.value_class_time'), 100),
      SceneInfoItem.create('class_room', $r('app.string.info_classroom'),
        $r('app.string.value_classroom'), $r('app.string.value_arrive_early'), 90),
      SceneInfoItem.create('class_todo', $r('app.string.info_class_todo'),
        $r('app.string.value_lab_report'), $r('app.string.value_after_class'), 80)
    ];
  }

  private static meetingItems(): SceneInfoItem[] {
    return [
      SceneInfoItem.create('meeting_topic', $r('app.string.info_meeting_topic'),
        $r('app.string.value_weekly_meeting'), $r('app.string.value_meeting_room'), 100),
      SceneInfoItem.create('meeting_start', $r('app.string.info_start_time'),
        $r('app.string.value_meeting_time'), $r('app.string.value_arrive_early'), 90),
      SceneInfoItem.create('meeting_prepare', $r('app.string.info_meeting_prepare'),
        $r('app.string.value_progress_risk'), $r('app.string.value_before_meeting'), 80)
    ];
  }

  private static commuteItems(): SceneInfoItem[] {
    return [
      SceneInfoItem.create('commute_schedule', $r('app.string.info_next_schedule'),
        $r('app.string.value_data_structure_course'), $r('app.string.value_class_time'), 100),
      SceneInfoItem.create('commute_depart', $r('app.string.info_departure_time'),
        $r('app.string.value_departure_time'), $r('app.string.value_allow_walk'), 90),
      SceneInfoItem.create('commute_items', $r('app.string.info_carry_items'),
        $r('app.string.value_carry_items'), $r('app.string.value_checked'), 80)
    ];
  }
}
