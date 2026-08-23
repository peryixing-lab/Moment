import { common } from '@kit.AbilityKit';
import { AppLogger } from '../common/AppLogger';
import { TimeUtils } from '../common/TimeUtils';
import { CourseOccurrence } from '../model/CourseModels';
import { ActiveSceneContext, SceneContextRule } from '../model/SceneContextModels';
import { AppSettings, SceneSignal, SceneSource, SettingsReadResult } from '../model/SceneModels';
import { SceneRule } from '../model/SceneRuleModels';
import { SceneType } from '../model/SceneType';
import { SettingsRepository } from '../repository/SettingsRepository';
import { SceneContextStateRepository } from '../repository/SceneContextStateRepository';
import { CourseService } from './CourseService';
import { SceneContextRuleService } from './SceneContextRuleService';
import { SceneRuleService } from './SceneRuleService';
import { SystemLinkageService } from './SystemLinkageService';

export class SceneSignalBundle {
  settings: AppSettings = AppSettings.defaults();
  signals: SceneSignal[] = new Array<SceneSignal>();
  storageReady: boolean = true;
}

export class SceneSignalService {
  static collect(context: common.Context, now: number = Date.now()): SceneSignalBundle {
    const bundle: SceneSignalBundle = new SceneSignalBundle();
    const settingsRepository: SettingsRepository = new SettingsRepository(context);
    const readResult: SettingsReadResult = settingsRepository.initialize();
    bundle.settings = readResult.settings;
    bundle.storageReady = readResult.success;

    if (bundle.settings.manualScene !== undefined && !bundle.settings.manualSceneLocked &&
      bundle.settings.manualSceneExpireAt > 0 && now >= bundle.settings.manualSceneExpireAt) {
      if (settingsRepository.clearManualScene(now)) {
        bundle.settings.manualScene = undefined;
        bundle.settings.manualSceneActivatedAt = 0;
        bundle.settings.manualSceneExpireAt = 0;
        bundle.settings.manualSceneLocked = false;
        if (new SceneContextStateRepository(context).load() === undefined) {
          SystemLinkageService.applySceneExit(context);
        }
        AppLogger.info('Expired manual scene was cleared');
      } else {
        bundle.storageReady = false;
      }
    }

    if (bundle.settings.manualScene !== undefined && (bundle.settings.manualSceneLocked ||
      bundle.settings.manualSceneExpireAt > now)) {
      bundle.signals.push({
        source: SceneSource.MANUAL,
        targetScene: bundle.settings.manualScene,
        score: bundle.settings.manualSceneLocked ? 120 : 100,
        reason: bundle.settings.manualSceneLocked ? 'manual_locked' : 'manual_temporary',
        timestamp: bundle.settings.manualSceneActivatedAt,
        priority: bundle.settings.manualSceneLocked ? 120 : 100,
        expiresAt: bundle.settings.manualSceneLocked ? undefined : bundle.settings.manualSceneExpireAt,
        isLocked: bundle.settings.manualSceneLocked
      });
    }

    if (bundle.settings.autoRecommendationEnabled) {
      SceneSignalService.appendCourseSignals(context, now, bundle.signals);
      SceneSignalService.appendContextSignal(context, bundle.signals);
      SceneSignalService.appendRuleSignals(context, now, bundle.signals);
    }

    bundle.signals.push({
      source: SceneSource.DEFAULT,
      targetScene: bundle.settings.defaultScene,
      score: 10,
      reason: bundle.settings.autoRecommendationEnabled ? 'default_fallback' : 'automatic_disabled',
      timestamp: bundle.settings.lastSceneUpdateTime,
      priority: 0,
      isLocked: false
    });
    AppLogger.info(`Collected ${bundle.signals.length} scene signals`);
    return bundle;
  }

  private static appendContextSignal(context: common.Context, signals: SceneSignal[]): void {
    const stateRepository: SceneContextStateRepository = new SceneContextStateRepository(context);
    const active: ActiveSceneContext | undefined = stateRepository.load();
    if (active === undefined) {
      return;
    }
    const rule: SceneContextRule | undefined =
      new SceneContextRuleService(context).getRule(active.ruleId);
    if (rule === undefined || !rule.isEnabled) {
      stateRepository.clear();
      return;
    }
    signals.push({
      source: SceneSource.CONTEXT_RULE,
      targetScene: rule.sceneType,
      score: 95,
      reason: `context_rule:${rule.id}:${rule.triggerType}`,
      timestamp: active.activatedAt,
      priority: 95,
      isLocked: false
    });
  }

  private static appendCourseSignals(context: common.Context, now: number, signals: SceneSignal[]): void {
    const service: CourseService = new CourseService(context);
    const current: CourseOccurrence | undefined = service.getCurrentCourse(now);
    if (current !== undefined) {
      signals.push({
        source: SceneSource.SCHEDULE,
        targetScene: SceneType.CLASS,
        score: 90,
        reason: `course_current:${current.course.id}`,
        timestamp: current.course.updatedAt,
        priority: 90,
        expiresAt: current.endAt,
        isLocked: false
      });
      return;
    }
    const upcoming: CourseOccurrence | undefined = service.getUpcomingCourse(now, 30);
    if (upcoming !== undefined) {
      signals.push({
        source: SceneSource.SCHEDULE,
        targetScene: SceneType.CLASS,
        score: 80,
        reason: `course_upcoming:${upcoming.course.id}`,
        timestamp: upcoming.course.updatedAt,
        priority: 80,
        expiresAt: upcoming.endAt,
        isLocked: false
      });
    }
  }

  private static appendRuleSignals(context: common.Context, now: number, signals: SceneSignal[]): void {
    const rules: SceneRule[] = new SceneRuleService(context).listEnabledRules();
    const date: Date = new Date(now);
    const minute: number = date.getHours() * 60 + date.getMinutes();
    for (let index: number = 0; index < rules.length; index += 1) {
      const rule: SceneRule = rules[index];
      if (TimeUtils.containsDay(rule.daysOfWeek, date.getDay()) && minute >= rule.startMinutes &&
        minute < rule.endMinutes) {
        signals.push({
          source: SceneSource.TIME_RULE,
          targetScene: rule.sceneType,
          score: 60 + Math.max(1, Math.min(20, rule.priority)),
          reason: `time_rule:${rule.id}`,
          timestamp: rule.updatedAt,
          priority: rule.priority,
          expiresAt: TimeUtils.startOfDay(now) + rule.endMinutes * 60 * 1000,
          isLocked: false
        });
      }
    }
  }

}
