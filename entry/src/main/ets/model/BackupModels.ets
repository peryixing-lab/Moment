export class BackupResult {
  success: boolean = false;
  detail: string = '';

  // Export counts.
  exportedCourseCount: number = 0;
  exportedTaskCount: number = 0;
  exportedRuleCount: number = 0;

  // Import counts (scene rules + context rules are combined into the rule fields).
  importedCourses: number = 0;
  skippedCourses: number = 0;
  failedCourses: number = 0;
  importedTasks: number = 0;
  skippedTasks: number = 0;
  failedTasks: number = 0;
  importedRules: number = 0;
  skippedRules: number = 0;
  failedRules: number = 0;

  static ok(detail: string): BackupResult {
    const result: BackupResult = new BackupResult();
    result.success = true;
    result.detail = detail;
    return result;
  }

  static fail(detail: string): BackupResult {
    const result: BackupResult = new BackupResult();
    result.detail = detail;
    return result;
  }
}

export class BackupCounts {
  imported: number = 0;
  skipped: number = 0;
  failed: number = 0;
}
