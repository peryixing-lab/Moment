export enum SceneType {
  LIBRARY = 'library',
  CLASS = 'class',
  MEETING = 'meeting',
  COMMUTE = 'commute'
}

export class SceneTypeCodec {
  static toStorage(sceneType: SceneType): string {
    switch (sceneType) {
      case SceneType.LIBRARY:
        return 'library';
      case SceneType.CLASS:
        return 'class';
      case SceneType.MEETING:
        return 'meeting';
      case SceneType.COMMUTE:
        return 'commute';
      default:
        return 'library';
    }
  }

  static fromStorage(value: string, fallback: SceneType): SceneType {
    switch (value) {
      case 'library':
        return SceneType.LIBRARY;
      case 'class':
        return SceneType.CLASS;
      case 'meeting':
        return SceneType.MEETING;
      case 'commute':
        return SceneType.COMMUTE;
      default:
        return fallback;
    }
  }

  static next(sceneType: SceneType): SceneType {
    switch (sceneType) {
      case SceneType.LIBRARY:
        return SceneType.CLASS;
      case SceneType.CLASS:
        return SceneType.MEETING;
      case SceneType.MEETING:
        return SceneType.COMMUTE;
      case SceneType.COMMUTE:
        return SceneType.LIBRARY;
      default:
        return SceneType.LIBRARY;
    }
  }
}

export class SceneTypes {
  static all(): SceneType[] {
    return [SceneType.LIBRARY, SceneType.CLASS, SceneType.MEETING, SceneType.COMMUTE];
  }
}
