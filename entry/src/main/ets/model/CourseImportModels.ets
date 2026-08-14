export class CourseImportCandidate {
  key: string = '';
  name: string = '';
  dayOfWeek: number = 1;
  startMinutes: number = 540;
  endMinutes: number = 600;
  location: string = '';
  teacher: string = '';
  validFrom: number = 0;
  validUntil: number = 0;
  reminderMinutes: number = 30;
}

export class CourseImportLoadResult {
  success: boolean = false;
  errorCode: string = '';
  source: string = '';
  candidates: CourseImportCandidate[] = new Array<CourseImportCandidate>();

  static ok(source: string, candidates: CourseImportCandidate[]): CourseImportLoadResult {
    const result: CourseImportLoadResult = new CourseImportLoadResult();
    result.success = true;
    result.source = source;
    result.candidates = candidates;
    return result;
  }

  static fail(errorCode: string): CourseImportLoadResult {
    const result: CourseImportLoadResult = new CourseImportLoadResult();
    result.errorCode = errorCode;
    return result;
  }
}

export class CourseImportSaveResult {
  importedCount: number = 0;
  skippedCount: number = 0;
  failedCount: number = 0;
}
