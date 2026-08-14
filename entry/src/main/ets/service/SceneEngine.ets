import { AppLogger } from '../common/AppLogger';
import { AppSettings, SceneDecision, SceneSignal, SceneSource, SceneState } from '../model/SceneModels';

export class SceneEngine {
  static decide(signals: SceneSignal[]): SceneDecision {
    if (signals.length === 0) {
      throw new Error('SceneEngine requires at least one signal');
    }
    let winner: SceneSignal = signals[0];
    for (let index: number = 1; index < signals.length; index += 1) {
      if (SceneEngine.isBetter(signals[index], winner)) {
        winner = signals[index];
      }
    }
    const reasons: string[] = new Array<string>();
    reasons.push(winner.reason);
    for (let index: number = 0; index < signals.length; index += 1) {
      const signal: SceneSignal = signals[index];
      if (signal !== winner && signal.targetScene === winner.targetScene && reasons.length < 3) {
        reasons.push(signal.reason);
      }
    }
    const decision: SceneDecision = {
      scene: winner.targetScene,
      confidence: Math.min(1, winner.score / 100),
      source: winner.source,
      reasons: reasons,
      activatedAt: winner.timestamp,
      expiresAt: winner.expiresAt,
      isLocked: winner.isLocked
    };
    AppLogger.info(`Scene decision ${decision.scene} from ${decision.source} score ${winner.score}`);
    return decision;
  }

  static resolve(settings: AppSettings, signals: SceneSignal[]): SceneState {
    const decision: SceneDecision = SceneEngine.decide(signals);
    return {
      currentScene: decision.scene,
      source: decision.source,
      activatedAt: decision.activatedAt,
      expiresAt: decision.expiresAt,
      isLocked: decision.isLocked,
      reason: decision.reasons.join(' · '),
      confidence: decision.confidence
    };
  }

  private static isBetter(candidate: SceneSignal, current: SceneSignal): boolean {
    if (candidate.score !== current.score) {
      return candidate.score > current.score;
    }
    const candidateRank: number = SceneEngine.sourceRank(candidate.source);
    const currentRank: number = SceneEngine.sourceRank(current.source);
    if (candidateRank !== currentRank) {
      return candidateRank > currentRank;
    }
    if (candidate.priority !== current.priority) {
      return candidate.priority > current.priority;
    }
    return candidate.timestamp > current.timestamp;
  }

  private static sourceRank(source: SceneSource): number {
    switch (source) {
      case SceneSource.MANUAL:
        return 5;
      case SceneSource.CONTEXT_RULE:
        return 4;
      case SceneSource.SCHEDULE:
        return 3;
      case SceneSource.TIME_RULE:
        return 2;
      case SceneSource.DEFAULT:
        return 1;
      default:
        return 0;
    }
  }
}
