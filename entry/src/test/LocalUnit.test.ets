import { describe, it, expect } from '@ohos/hypium';
import { AppSettings, SceneDecision, SceneSignal, SceneSource } from '../main/ets/model/SceneModels';
import { SceneType, SceneTypeCodec } from '../main/ets/model/SceneType';
import { FormActionParser, SceneFormAction } from '../main/ets/service/FormActionParser';
import { CourseImportService } from '../main/ets/service/CourseImportService';
import { SceneEngine } from '../main/ets/service/SceneEngine';
import { TimeUtils } from '../main/ets/common/TimeUtils';

export default function localUnitTest() {
  describe('SceneEngine', () => {
    it('manual scene has highest score', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.TIME_RULE, SceneType.COMMUTE, 80, 10, 10),
        signal(SceneSource.MANUAL, SceneType.MEETING, 100, 100, 20)
      ];
      const decision: SceneDecision = SceneEngine.decide(signals);
      expect(decision.scene).assertEqual(SceneType.MEETING);
      expect(decision.source).assertEqual(SceneSource.MANUAL);
    });

    it('locked manual scene beats every regular signal', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.SCHEDULE, SceneType.CLASS, 90, 90, 20),
        signal(SceneSource.MANUAL, SceneType.LIBRARY, 120, 120, 10)
      ];
      expect(SceneEngine.decide(signals).scene).assertEqual(SceneType.LIBRARY);
    });

    it('current course beats time rule', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.TIME_RULE, SceneType.COMMUTE, 80, 20, 20),
        signal(SceneSource.SCHEDULE, SceneType.CLASS, 90, 90, 10)
      ];
      expect(SceneEngine.decide(signals).scene).assertEqual(SceneType.CLASS);
    });

    it('same score uses source precedence', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.TIME_RULE, SceneType.COMMUTE, 80, 20, 20),
        signal(SceneSource.SCHEDULE, SceneType.CLASS, 80, 20, 10)
      ];
      expect(SceneEngine.decide(signals).scene).assertEqual(SceneType.CLASS);
    });

    it('same rule score uses priority', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.TIME_RULE, SceneType.COMMUTE, 70, 8, 30),
        signal(SceneSource.TIME_RULE, SceneType.MEETING, 70, 12, 20)
      ];
      expect(SceneEngine.decide(signals).scene).assertEqual(SceneType.MEETING);
    });

    it('same rule priority uses latest update', 0, () => {
      const signals: SceneSignal[] = [
        signal(SceneSource.TIME_RULE, SceneType.COMMUTE, 70, 10, 20),
        signal(SceneSource.TIME_RULE, SceneType.MEETING, 70, 10, 30)
      ];
      expect(SceneEngine.decide(signals).scene).assertEqual(SceneType.MEETING);
    });

    it('default signal is safe fallback', 0, () => {
      const settings: AppSettings = AppSettings.defaults(true);
      const signals: SceneSignal[] = [signal(SceneSource.DEFAULT, SceneType.LIBRARY, 10, 0, 1)];
      expect(SceneEngine.resolve(settings, signals).currentScene).assertEqual(SceneType.LIBRARY);
    });

    it('scene cycle covers every scene', 0, () => {
      expect(SceneTypeCodec.next(SceneType.LIBRARY)).assertEqual(SceneType.CLASS);
      expect(SceneTypeCodec.next(SceneType.CLASS)).assertEqual(SceneType.MEETING);
      expect(SceneTypeCodec.next(SceneType.MEETING)).assertEqual(SceneType.COMMUTE);
      expect(SceneTypeCodec.next(SceneType.COMMUTE)).assertEqual(SceneType.LIBRARY);
    });
  });

  describe('FormActionParser', () => {
    it('parses valid task action', 0, () => {
      const action: SceneFormAction | undefined =
        FormActionParser.parse('{"action":"completeTask","taskId":8}');
      expect(action !== undefined).assertTrue();
      expect(action?.taskId).assertEqual(8);
    });

    it('rejects task action without id', 0, () => {
      expect(FormActionParser.parse('{"action":"completeTask"}') === undefined).assertTrue();
    });

    it('rejects invalid focus duration', 0, () => {
      expect(FormActionParser.parse('{"action":"startFocus","durationMinutes":500}') === undefined)
        .assertTrue();
    });

    it('rejects malformed json', 0, () => {
      expect(FormActionParser.parse('not-json') === undefined).assertTrue();
    });

    it('rejects unsupported and oversized form actions', 0, () => {
      expect(FormActionParser.parse('{"action":"deleteEverything"}') === undefined).assertTrue();
      expect(FormActionParser.parse('x'.repeat(1025)) === undefined).assertTrue();
    });
  });

  describe('CourseImportService', () => {
    it('keeps weekly course date range and identifies teacher', 0, () => {
      const content: string = 'BEGIN:VCALENDAR\nBEGIN:VEVENT\n' +
        'DESCRIPTION:4.5 学分\\n第1 - 12周 周一 第1 - 2节\\n黎梨苗\\n涵虚楼A1303\n' +
        'DTSTART:20260302T080000\nDTEND:20260302T094000\nLOCATION:涵虚楼A1303\n' +
        'RRULE:FREQ=WEEKLY;UNTIL=20260524T160000Z;INTERVAL=1;BYDAY=MO\n' +
        'SUMMARY:数据结构与算法\nEND:VEVENT\nEND:VCALENDAR';
      const candidates = CourseImportService.parseVcs(content);
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].teacher).assertEqual('黎梨苗');
      expect(candidates[0].validFrom).assertEqual(new Date(2026, 2, 2, 0, 0, 0, 0).getTime());
      expect(candidates[0].validUntil).assertEqual(new Date(2026, 4, 18, 0, 0, 0, 0).getTime());
    });

    it('limits a non-recurring event to its actual date', 0, () => {
      const content: string = 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20260908T140000\n' +
        'DTEND:20260908T154000\nSUMMARY:临时课程\nEND:VEVENT\nEND:VCALENDAR';
      const candidates = CourseImportService.parseVcs(content);
      const expectedDate: number = new Date(2026, 8, 8, 0, 0, 0, 0).getTime();
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].validFrom).assertEqual(expectedDate);
      expect(candidates[0].validUntil).assertEqual(expectedDate);
    });
  });

  describe('TimeUtils', () => {
    it('accepts only complete clock values', 0, () => {
      expect(TimeUtils.parseClock('09:30')).assertEqual(570);
      expect(TimeUtils.parseClock('09:30abc')).assertEqual(-1);
      expect(TimeUtils.parseClock('9:30')).assertEqual(-1);
    });

    it('rejects normalized and suffixed invalid dates', 0, () => {
      expect(TimeUtils.parseDate('2026-02-29')).assertEqual(-1);
      expect(TimeUtils.parseDate('2026-07-23extra')).assertEqual(-1);
      expect(TimeUtils.parseDateTime('2026-07-23 18:30extra')).assertEqual(-1);
    });
  });
}

function signal(source: SceneSource, scene: SceneType, score: number, priority: number,
  timestamp: number): SceneSignal {
  return {
    source: source,
    targetScene: scene,
    score: score,
    reason: 'test',
    timestamp: timestamp,
    priority: priority,
    isLocked: false
  };
}
