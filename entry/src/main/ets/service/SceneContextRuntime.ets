import { SceneContextMonitor } from './SceneContextMonitor';

export class SceneContextRuntime {
  private static monitor: SceneContextMonitor | undefined = undefined;

  static attach(monitor: SceneContextMonitor): void {
    SceneContextRuntime.monitor = monitor;
  }

  static detach(monitor: SceneContextMonitor): void {
    if (SceneContextRuntime.monitor === monitor) {
      SceneContextRuntime.monitor = undefined;
    }
  }

  static notifyRulesChanged(): void {
    SceneContextRuntime.monitor?.rulesChanged();
  }
}
