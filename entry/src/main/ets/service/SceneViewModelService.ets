import { common } from '@kit.AbilityKit';
import { ResourceText } from '../common/ResourceText';
import { DatabaseManager } from '../database/DatabaseManager';
import { FocusSession } from '../model/FocusModels';
import { SceneSource, SceneState } from '../model/SceneModels';
import { SceneType } from '../model/SceneType';
import { RankingItem, SceneAction, SceneActionType, SceneViewModel } from '../model/ViewModels';
import { SceneEngine } from './SceneEngine';
import { FocusService } from './FocusService';
import { InformationRankingService } from './InformationRankingService';
import { ScenePresentationService } from './ScenePresentationService';
import { SceneSignalBundle, SceneSignalService } from './SceneSignalService';

export class SceneViewModelService {
  static build(context: common.Context, now: number = Date.now()): SceneViewModel {
    DatabaseManager.initialize(context);
    const bundle: SceneSignalBundle = SceneSignalService.collect(context, now);
    const state: SceneState = SceneEngine.resolve(bundle.settings, bundle.signals);
    const model: SceneViewModel = new SceneViewModel();
    model.scene = state.currentScene;
    model.sceneName = ResourceText.get(context,
      ScenePresentationService.getPresentation(state.currentScene).name, '此刻');
    model.subtitle = ResourceText.get(context,
      ScenePresentationService.getPresentation(state.currentScene).subtitle, '此刻最重要的信息');
    model.sceneSymbol = SceneViewModelService.symbolText(state.currentScene);
    model.sceneSymbolResource = SceneViewModelService.symbol(state.currentScene);
    model.source = state.source;
    model.sourceLabel = SceneViewModelService.sourceLabel(context, state.source);
    model.reasonText = SceneViewModelService.reasonText(context, state);
    model.confidence = state.confidence;
    model.updatedAt = now;
    model.isManualOverride = state.source === SceneSource.MANUAL;
    model.isManualLocked = state.isLocked;
    model.manualOverrideRemainingMinutes = state.expiresAt === undefined ? 0 :
      Math.max(0, Math.ceil((state.expiresAt - now) / 60000));
    model.hasDataError = DatabaseManager.hasInitializationError() || !bundle.storageReady;

    const ranking: RankingItem[] = InformationRankingService.build(context, state.currentScene, now);
    if (ranking.length > 0) {
      model.primaryInfo = ranking[0];
    }
    if (bundle.settings.showSecondaryInfo) {
      for (let index: number = 1; index < ranking.length && model.secondaryInfo.length < 2; index += 1) {
        model.secondaryInfo.push(ranking[index]);
      }
    }
    const todayLimit: number = bundle.settings.showSecondaryInfo ? 5 : 1;
    for (let index: number = 0; index < ranking.length && model.todayFocus.length < todayLimit; index += 1) {
      model.todayFocus.push(ranking[index]);
      if (bundle.settings.showSecondaryInfo && ranking[index].type === 'course' && model.upcoming.length < 3) {
        model.upcoming.push(ranking[index]);
      }
    }

    const focusService: FocusService = new FocusService(context);
    const session: FocusSession | undefined = focusService.getActiveSession(now);
    model.hasRunningFocus = session !== undefined;
    model.focusRemainingMinutes = session === undefined ? 0 : focusService.remainingMinutes(session, now);
    model.primaryAction = SceneViewModelService.primaryAction(context, model);
    return model;
  }

  static safeEmpty(context: common.Context): SceneViewModel {
    const model: SceneViewModel = SceneViewModel.empty();
    model.sceneName = ResourceText.get(context, $r('app.string.app_name'), '此刻');
    model.subtitle = ResourceText.get(context, $r('app.string.form_fallback'), '重要的信息正在准备中');
    model.primaryAction = SceneAction.create(SceneActionType.OPEN_SERVICE,
      ResourceText.get(context, $r('app.string.form_open'), '打开此刻'));
    model.hasDataError = true;
    return model;
  }

  private static primaryAction(context: common.Context, model: SceneViewModel): SceneAction {
    for (let index: number = 0; index < model.todayFocus.length; index += 1) {
      if (model.todayFocus[index].type === 'task' && model.todayFocus[index].action !== undefined) {
        return model.todayFocus[index].action as SceneAction;
      }
    }
    if (model.hasRunningFocus) {
      return SceneAction.create(SceneActionType.STOP_FOCUS,
        ResourceText.get(context, $r('app.string.action_stop_focus'), '结束专注'));
    }
    if (model.scene === SceneType.LIBRARY) {
      return SceneAction.create(SceneActionType.START_FOCUS,
        ResourceText.get(context, $r('app.string.action_start_25_focus'), '开始 25 分钟专注'), 0, 25);
    }
    if (model.scene === SceneType.CLASS) {
      return SceneAction.create(SceneActionType.OPEN_COURSES,
        ResourceText.get(context, $r('app.string.action_open_course'), '打开课程'));
    }
    if (model.scene === SceneType.COMMUTE) {
      return SceneAction.create(SceneActionType.OPEN_TASKS,
        ResourceText.get(context, $r('app.string.action_open_tasks'), '打开任务'));
    }
    return SceneAction.create(SceneActionType.OPEN_SERVICE,
      ResourceText.get(context, $r('app.string.form_open'), '打开此刻'));
  }

  private static sourceLabel(context: common.Context, source: SceneSource): string {
    switch (source) {
      case SceneSource.MANUAL:
        return ResourceText.get(context, $r('app.string.source_manual'), '手动选择');
      case SceneSource.CONTEXT_RULE:
        return ResourceText.get(context, $r('app.string.source_context_rule'), '位置与 Wi-Fi');
      case SceneSource.TIME_RULE:
        return ResourceText.get(context, $r('app.string.source_time_rule'), '时间规则');
      case SceneSource.SCHEDULE:
        return ResourceText.get(context, $r('app.string.source_schedule'), '课程安排');
      case SceneSource.DEFAULT:
        return ResourceText.get(context, $r('app.string.source_default'), '默认场景');
      default:
        return '';
    }
  }

  private static reasonText(context: common.Context, state: SceneState): string {
    switch (state.source) {
      case SceneSource.MANUAL:
        return state.isLocked ?
          ResourceText.get(context, $r('app.string.reason_manual_locked'), '场景会保持到你手动恢复') :
          ResourceText.get(
            context,
            $r('app.string.reason_manual_temporary'),
            '手动场景将在两小时后恢复自动推荐'
          );
      case SceneSource.CONTEXT_RULE:
        return ResourceText.get(
          context,
          $r('app.string.reason_context_rule'),
          '已命中你设置的位置或 Wi-Fi 场景规则'
        );
      case SceneSource.TIME_RULE:
        return ResourceText.get(context, $r('app.string.reason_time_rule'), '命中你设置的场景时间规则');
      case SceneSource.SCHEDULE:
        return ResourceText.get(context, $r('app.string.reason_schedule'), '课程即将开始或正在进行');
      case SceneSource.DEFAULT:
        return ResourceText.get(context, $r('app.string.reason_default'), '使用默认场景');
      default:
        return '';
    }
  }

  private static symbol(scene: SceneType): Resource {
    switch (scene) {
      case SceneType.LIBRARY:
        return $r('sys.symbol.doc');
      case SceneType.CLASS:
        return $r('sys.symbol.clock');
      case SceneType.MEETING:
        return $r('sys.symbol.person');
      case SceneType.COMMUTE:
        return $r('sys.symbol.chevron_right');
      default:
        return $r('sys.symbol.clock');
    }
  }

  private static symbolText(scene: SceneType): string {
    switch (scene) {
      case SceneType.LIBRARY:
        return '▤';
      case SceneType.CLASS:
        return '□';
      case SceneType.MEETING:
        return '◇';
      case SceneType.COMMUTE:
        return '→';
      default:
        return '●';
    }
  }
}
