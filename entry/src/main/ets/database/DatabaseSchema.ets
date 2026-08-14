export const DATABASE_NAME: string = 'moment_local.db';
export const DATABASE_VERSION: number = 2;

export const TABLE_COURSE: string = 'Course';
export const TABLE_TASK: string = 'TaskItem';
export const TABLE_SCENE_RULE: string = 'SceneRule';
export const TABLE_SCENE_CONTEXT_RULE: string = 'SceneContextRule';
export const TABLE_FOCUS_SESSION: string = 'FocusSession';

export const CREATE_COURSE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS Course (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'name TEXT NOT NULL, dayOfWeek INTEGER NOT NULL, startMinutes INTEGER NOT NULL, ' +
  'endMinutes INTEGER NOT NULL, location TEXT NOT NULL DEFAULT \'\', teacher TEXT NOT NULL DEFAULT \'\', ' +
  'reminderMinutes INTEGER NOT NULL DEFAULT 30, isEnabled INTEGER NOT NULL DEFAULT 1, ' +
  'createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)';

export const CREATE_TASK_TABLE: string =
  'CREATE TABLE IF NOT EXISTS TaskItem (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT \'\', ' +
  'dueAt INTEGER NOT NULL DEFAULT 0, priority INTEGER NOT NULL DEFAULT 2, sceneType TEXT NOT NULL DEFAULT \'\', ' +
  'isCompleted INTEGER NOT NULL DEFAULT 0, completedAt INTEGER NOT NULL DEFAULT 0, ' +
  'createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)';

export const CREATE_SCENE_RULE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS SceneRule (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, sceneType TEXT NOT NULL, ' +
  'daysOfWeek TEXT NOT NULL, startMinutes INTEGER NOT NULL, endMinutes INTEGER NOT NULL, ' +
  'priority INTEGER NOT NULL DEFAULT 10, isEnabled INTEGER NOT NULL DEFAULT 1, ' +
  'createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)';

export const CREATE_FOCUS_SESSION_TABLE: string =
  'CREATE TABLE IF NOT EXISTS FocusSession (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, durationMinutes INTEGER NOT NULL, startedAt INTEGER NOT NULL, ' +
  'plannedEndAt INTEGER NOT NULL, endedAt INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL, ' +
  'sceneType TEXT NOT NULL, createdAt INTEGER NOT NULL)';

export const CREATE_COURSE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_course_schedule ON Course(isEnabled, dayOfWeek, startMinutes)';
export const CREATE_TASK_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_task_open ON TaskItem(isCompleted, dueAt, priority)';
export const CREATE_RULE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_rule_enabled ON SceneRule(isEnabled, startMinutes, endMinutes)';
export const CREATE_FOCUS_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_focus_status ON FocusSession(status, startedAt)';
