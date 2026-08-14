import { common } from '@kit.AbilityKit';
import { formBindingData } from '@kit.FormKit';
import { AppLogger } from '../common/AppLogger';
import { TimeUtils } from '../common/TimeUtils';
import { RankingItem, SceneViewModel } from '../model/ViewModels';
import { SceneViewModelService } from '../service/SceneViewModelService';

const MAX_CARD_COUNTDOWN_MINUTES: number = 180;

export class SceneFormPayload {
  formDimension: number = 3;
  sceneName: string = '';
  sceneSymbol: string = '●';
  subtitle: string = '';
  currentTime: string = '';
  primaryType: string = 'reminder';
  primaryTitle: string = '';
  primaryValue: string = '';
  primaryDescription: string = '';
  primaryCountdownMinutes: number = 0;
  primaryTime: string = '';
  primaryMeta: string = '';
  secondaryOne: string = '';
  secondaryTwo: string = '';
  supportOneTitle: string = '';
  supportOneValue: string = '';
  supportOneDescription: string = '';
  supportOneAction: string = '';
  supportOneActionLabel: string = '';
  supportOneTaskId: number = 0;
  supportOneDurationMinutes: number = 0;
  supportTwoTitle: string = '';
  supportTwoValue: string = '';
  supportTwoDescription: string = '';
  supportTwoAction: string = '';
  supportTwoActionLabel: string = '';
  supportTwoTaskId: number = 0;
  supportTwoDurationMinutes: number = 0;
  reason: string = '';
  sourceLabel: string = '';
  primaryAction: string = 'openService';
  primaryActionLabel: string = '';
  primaryTaskId: number = 0;
  primaryDurationMinutes: number = 0;
  isManualOverride: boolean = false;
  manualRemainingMinutes: number = 0;
}

export class SceneFormDataAdapter {
  static createBindingData(context: common.Context, formDimension: number = 3): formBindingData.FormBindingData {
    try {
      const now: number = Date.now();
      const model: SceneViewModel = SceneViewModelService.build(context, now);
      const payload: SceneFormPayload = new SceneFormPayload();
      payload.formDimension = SceneFormDataAdapter.normalizeDimension(formDimension);
      payload.sceneName = model.sceneName;
      payload.sceneSymbol = model.sceneSymbol;
      payload.subtitle = model.subtitle;
      payload.currentTime = TimeUtils.formatTime(now);
      if (model.primaryInfo !== undefined) {
        payload.primaryType = model.primaryInfo.type;
        payload.primaryTitle = model.primaryInfo.title;
        payload.primaryValue = model.primaryInfo.value;
        payload.primaryDescription = model.primaryInfo.description;
        payload.primaryCountdownMinutes =
          SceneFormDataAdapter.extractCountdownMinutes(model.primaryInfo.description);
        payload.primaryTime = SceneFormDataAdapter.firstClock(model.primaryInfo.description);
        payload.primaryMeta = SceneFormDataAdapter.primaryMeta(model.primaryInfo, now);
      }
      if (model.secondaryInfo.length > 0) {
        payload.secondaryOne = SceneFormDataAdapter.compact(model.secondaryInfo[0]);
      }
      if (model.secondaryInfo.length > 1) {
        payload.secondaryTwo = SceneFormDataAdapter.compact(model.secondaryInfo[1]);
      }
      const supportItems: RankingItem[] = SceneFormDataAdapter.supportItems(model);
      if (supportItems.length > 0) {
        SceneFormDataAdapter.assignSupportOne(payload, supportItems[0]);
      }
      if (supportItems.length > 1) {
        SceneFormDataAdapter.assignSupportTwo(payload, supportItems[1]);
      }
      payload.reason = model.reasonText;
      payload.sourceLabel = model.sourceLabel;
      payload.primaryAction = model.primaryAction.type;
      payload.primaryActionLabel = model.primaryAction.label;
      payload.primaryTaskId = model.primaryAction.taskId;
      payload.primaryDurationMinutes = model.primaryAction.durationMinutes;
      payload.isManualOverride = model.isManualOverride;
      payload.manualRemainingMinutes = model.manualOverrideRemainingMinutes;
      return formBindingData.createFormBindingData(payload);
    } catch (error) {
      AppLogger.error('Unable to build form data', error as Object);
      return formBindingData.createFormBindingData(new SceneFormPayload());
    }
  }

  private static compact(item: RankingItem): string {
    return item.value.length > 0 ? item.value : item.title;
  }

  private static normalizeDimension(dimension: number): number {
    return dimension === 2 || dimension === 4 ? dimension : 3;
  }

  private static extractCountdownMinutes(description: string): number {
    const match = description.match(/(\d+)\s*分钟后/);
    if (match === null || match.length < 2) {
      return 0;
    }
    const minutes: number = Number.parseInt(match[1]);
    if (Number.isNaN(minutes) || minutes < 1 || minutes > MAX_CARD_COUNTDOWN_MINUTES) {
      return 0;
    }
    return minutes;
  }

  private static firstClock(description: string): string {
    const match = description.match(/(?:[01]\d|2[0-3]):[0-5]\d/);
    return match === null || match.length === 0 ? '' : match[0];
  }

  private static location(description: string): string {
    const parts: string[] = description.split(' · ');
    if (parts.length < 3) {
      return '';
    }
    const candidate: string = parts[1].trim();
    if (candidate.includes('分钟') || candidate.includes('开始') || candidate.includes('截止')) {
      return '';
    }
    return candidate;
  }

  private static courseDate(description: string, now: number): string {
    const match = description.match(/(\d{4})-(\d{2})-(\d{2})/);
    if (match === null || match.length < 4 || match[0] === TimeUtils.formatDate(now)) {
      return '';
    }
    const month: number = Number.parseInt(match[2]);
    const day: number = Number.parseInt(match[3]);
    return Number.isNaN(month) || Number.isNaN(day) ? '' : `${month}月${day}日`;
  }

  private static primaryMeta(item: RankingItem, now: number): string {
    if (item.type !== 'course') {
      return SceneFormDataAdapter.conciseDescription(item.description);
    }
    const time: string = SceneFormDataAdapter.firstClock(item.description);
    if (time.length === 0) {
      return SceneFormDataAdapter.conciseDescription(item.description);
    }
    const location: string = SceneFormDataAdapter.location(item.description);
    const date: string = SceneFormDataAdapter.courseDate(item.description, now);
    const schedule: string = date.length > 0 ? `${date} ${time}` : time;
    return location.length > 0 ? `${schedule} 开始 · ${location}` : `${schedule} 开始`;
  }

  private static conciseDescription(description: string): string {
    const dueMatch = description.match(/截止\s+\d+月\d+日\s+((?:[01]\d|2[0-3]):[0-5]\d)/);
    if (dueMatch !== null && dueMatch.length > 1) {
      return `截止 ${dueMatch[1]}`;
    }
    const courseTime: string = SceneFormDataAdapter.firstClock(description);
    const location: string = SceneFormDataAdapter.location(description);
    if (courseTime.length > 0 && description.includes('分钟后')) {
      return location.length > 0 ? `${courseTime} · ${location}` : courseTime;
    }
    const parts: string[] = description.split(' · ');
    return parts.length > 0 ? parts[0] : description;
  }

  private static supportItems(model: SceneViewModel): RankingItem[] {
    const result: RankingItem[] = new Array<RankingItem>();
    for (let index: number = 0; index < model.todayFocus.length && result.length < 2; index += 1) {
      const item: RankingItem = model.todayFocus[index];
      if (model.primaryInfo !== undefined && item.id === model.primaryInfo.id) {
        continue;
      }
      result.push(item);
    }
    return result;
  }

  private static assignSupportOne(payload: SceneFormPayload, item: RankingItem): void {
    payload.supportOneTitle = item.title;
    payload.supportOneValue = item.value;
    payload.supportOneDescription = SceneFormDataAdapter.conciseDescription(item.description);
    if (item.action !== undefined) {
      payload.supportOneAction = item.action.type;
      payload.supportOneActionLabel = item.action.label;
      payload.supportOneTaskId = item.action.taskId;
      payload.supportOneDurationMinutes = item.action.durationMinutes;
    }
  }

  private static assignSupportTwo(payload: SceneFormPayload, item: RankingItem): void {
    payload.supportTwoTitle = item.title;
    payload.supportTwoValue = item.value;
    payload.supportTwoDescription = SceneFormDataAdapter.conciseDescription(item.description);
    if (item.action !== undefined) {
      payload.supportTwoAction = item.action.type;
      payload.supportTwoActionLabel = item.action.label;
      payload.supportTwoTaskId = item.action.taskId;
      payload.supportTwoDurationMinutes = item.action.durationMinutes;
    }
  }
}
