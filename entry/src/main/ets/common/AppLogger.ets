import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x3200;
const TAG: string = 'MomentService';

export class AppLogger {
  static info(message: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', message);
  }

  static error(message: string, error?: Object): void {
    const detail: string = error === undefined ? '' : AppLogger.errorDetail(error);
    hilog.error(DOMAIN, TAG, '%{public}s %{private}s', message, detail);
  }

  private static errorDetail(error: Object): string {
    if (error instanceof Error) {
      return `${error.name}: ${error.message}`;
    }
    try {
      return JSON.stringify(error);
    } catch (_) {
      return 'Unserializable error';
    }
  }
}
