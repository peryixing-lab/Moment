export class TimeUtils {
  static parseClock(value: string): number {
    const match: RegExpMatchArray | null = value.trim().match(/^([01]\d|2[0-3]):([0-5]\d)$/);
    if (match === null || match.length !== 3) {
      return -1;
    }
    const hours: number = Number.parseInt(match[1]);
    const minutes: number = Number.parseInt(match[2]);
    return hours * 60 + minutes;
  }

  static formatClock(minutesOfDay: number): string {
    const safe: number = Math.max(0, Math.min(1439, minutesOfDay));
    return `${Math.floor(safe / 60).toString().padStart(2, '0')}:${(safe % 60).toString().padStart(2, '0')}`;
  }

  static formatTime(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  static formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }

  static formatDateTime(timestamp: number): string {
    return `${TimeUtils.formatDate(timestamp)} ${TimeUtils.formatTime(timestamp)}`;
  }

  static parseDate(value: string): number {
    const trimmed: string = value.trim();
    if (trimmed.length === 0) {
      return 0;
    }
    const match: RegExpMatchArray | null = trimmed.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match === null || match.length !== 4) {
      return -1;
    }
    const year: number = Number.parseInt(match[1]);
    const month: number = Number.parseInt(match[2]);
    const day: number = Number.parseInt(match[3]);
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return -1;
    }
    const date: Date = new Date(year, month - 1, day, 0, 0, 0, 0);
    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
      return -1;
    }
    return date.getTime();
  }

  static parseDateTime(value: string): number {
    const trimmed: string = value.trim();
    if (trimmed.length === 0) {
      return 0;
    }
    const match: RegExpMatchArray | null =
      trimmed.match(/^(\d{4})-(\d{2})-(\d{2}) ([01]\d|2[0-3]):([0-5]\d)$/);
    if (match === null || match.length !== 6) {
      return -1;
    }
    const year: number = Number.parseInt(match[1]);
    const month: number = Number.parseInt(match[2]);
    const day: number = Number.parseInt(match[3]);
    const hour: number = Number.parseInt(match[4]);
    const minute: number = Number.parseInt(match[5]);
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) {
      return -1;
    }
    const date: Date = new Date(year, month - 1, day, hour, minute, 0, 0);
    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day ||
      date.getHours() !== hour || date.getMinutes() !== minute) {
      return -1;
    }
    return date.getTime();
  }

  static startOfDay(timestamp: number): number {
    const date: Date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  static containsDay(days: number[], target: number): boolean {
    return days.indexOf(target) >= 0;
  }
}
