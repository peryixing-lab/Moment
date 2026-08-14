import { AppDimensions } from '../../common/AppDimensions';
import { AppTypography } from '../../common/AppTypography';
import { ImmersiveMaterials } from '../../common/ImmersiveMaterials';

const cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct SceneCard {
  @LocalStorageProp('formDimension') formDimension: number = 3;
  @LocalStorageProp('sceneName') sceneName: string = '';
  @LocalStorageProp('sceneSymbol') sceneSymbol: string = '●';
  @LocalStorageProp('subtitle') subtitle: string = '';
  @LocalStorageProp('currentTime') currentTime: string = '';
  @LocalStorageProp('primaryType') primaryType: string = 'reminder';
  @LocalStorageProp('primaryTitle') primaryTitle: string = '';
  @LocalStorageProp('primaryValue') primaryValue: string = '';
  @LocalStorageProp('primaryDescription') primaryDescription: string = '';
  @LocalStorageProp('primaryCountdownMinutes') primaryCountdownMinutes: number = 0;
  @LocalStorageProp('primaryTime') primaryTime: string = '';
  @LocalStorageProp('primaryMeta') primaryMeta: string = '';
  @LocalStorageProp('secondaryOne') secondaryOne: string = '';
  @LocalStorageProp('secondaryTwo') secondaryTwo: string = '';
  @LocalStorageProp('supportOneTitle') supportOneTitle: string = '';
  @LocalStorageProp('supportOneValue') supportOneValue: string = '';
  @LocalStorageProp('supportOneDescription') supportOneDescription: string = '';
  @LocalStorageProp('supportOneAction') supportOneAction: string = '';
  @LocalStorageProp('supportOneActionLabel') supportOneActionLabel: string = '';
  @LocalStorageProp('supportOneTaskId') supportOneTaskId: number = 0;
  @LocalStorageProp('supportOneDurationMinutes') supportOneDurationMinutes: number = 0;
  @LocalStorageProp('supportTwoTitle') supportTwoTitle: string = '';
  @LocalStorageProp('supportTwoValue') supportTwoValue: string = '';
  @LocalStorageProp('supportTwoDescription') supportTwoDescription: string = '';
  @LocalStorageProp('supportTwoAction') supportTwoAction: string = '';
  @LocalStorageProp('supportTwoActionLabel') supportTwoActionLabel: string = '';
  @LocalStorageProp('supportTwoTaskId') supportTwoTaskId: number = 0;
  @LocalStorageProp('supportTwoDurationMinutes') supportTwoDurationMinutes: number = 0;
  @LocalStorageProp('reason') reason: string = '';
  @LocalStorageProp('sourceLabel') sourceLabel: string = '';
  @LocalStorageProp('primaryAction') primaryAction: string = 'openService';
  @LocalStorageProp('primaryActionLabel') primaryActionLabel: string = '';
  @LocalStorageProp('primaryTaskId') primaryTaskId: number = 0;
  @LocalStorageProp('primaryDurationMinutes') primaryDurationMinutes: number = 0;
  @LocalStorageProp('isManualOverride') isManualOverride: boolean = false;
  @LocalStorageProp('manualRemainingMinutes') manualRemainingMinutes: number = 0;

  private isMessageAction(action: string): boolean {
    return action === 'completeTask' || action === 'startFocus' || action === 'stopFocus' ||
      action === 'restoreAutoScene' || action === 'switchScene';
  }

  private postMessage(action: string, taskId: number = 0, durationMinutes: number = 0): void {
    postCardAction(this, {
      action: 'message',
      params: {
        action: action,
        taskId: taskId,
        durationMinutes: durationMinutes
      }
    });
  }

  private openApplication(source: string, targetPage: string = '', targetAction: string = ''): void {
    postCardAction(this, {
      action: 'router',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      params: {
        source: source,
        targetPage: targetPage,
        targetAction: targetAction
      }
    });
  }

  private primaryTargetPage(): string {
    if (this.primaryAction === 'openCourses') {
      return 'pages/CourseListPage';
    }
    if (this.primaryAction === 'openTasks') {
      return 'pages/TaskListPage';
    }
    return '';
  }

  private handlePrimaryAction(): void {
    if (this.isMessageAction(this.primaryAction)) {
      this.postMessage(this.primaryAction, this.primaryTaskId, this.primaryDurationMinutes);
      return;
    }
    this.openApplication('sceneFormPrimary', this.primaryTargetPage());
  }

  private primaryLabel(compact: boolean): ResourceStr {
    if (compact && this.primaryAction === 'startFocus' && this.primaryDurationMinutes === 25) {
      return $r('app.string.form_focus_25');
    }
    return this.primaryActionLabel.length > 0 ? this.primaryActionLabel : $r('app.string.form_open');
  }

  private sceneLabel(): ResourceStr {
    return this.sceneName.length > 0 ? this.sceneName : $r('app.string.scene_library_name');
  }

  private timeLabel(): ResourceStr {
    return this.currentTime.length > 0 ? this.currentTime : $r('app.string.form_fallback_clock');
  }

  private heroValue(): ResourceStr {
    return this.primaryValue.length > 0 ? this.primaryValue : $r('app.string.form_fallback_title');
  }

  private heroMeta(): ResourceStr {
    if (this.primaryMeta.length > 0) {
      return this.primaryMeta;
    }
    return this.primaryDescription.length > 0 ? this.primaryDescription : $r('app.string.form_fallback_note');
  }

  private mediumFooterNote(): string {
    if (this.supportOneValue.length > 0) {
      return `${this.supportOneValue}${this.supportOneDescription.length > 0 ?
        ` · ${this.supportOneDescription}` : ''}`;
    }
    return this.reason.length > 0 ? this.reason : this.subtitle;
  }

  @Builder
  private SceneMeta(showIcon: boolean) {
    Row({ space: showIcon ? 7 : 0 }) {
      if (showIcon) {
        SymbolGlyph($r('sys.symbol.book_open_fill'))
          .fontSize(AppTypography.FORM_SCENE)
          .fontColor([$r('app.color.text_primary')])
      }
      Text(this.sceneLabel())
        .fontSize(AppTypography.FORM_SCENE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
      if (showIcon && this.sourceLabel.length > 0) {
        Text('·')
          .fontSize(AppTypography.FORM_META)
          .fontColor($r('app.color.text_secondary'))
        Text(this.sourceLabel)
          .fontSize(AppTypography.FORM_META)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      Blank()
      Text(this.timeLabel())
        .fontSize(AppTypography.FORM_META)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
    }
    .width('100%')
  }

  @Builder
  private CompactHero() {
    if (this.primaryCountdownMinutes > 0) {
      Row({ space: 5 }) {
        Text(this.primaryCountdownMinutes.toString())
          .fontSize(AppTypography.FORM_COMPACT_HERO)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Text($r('app.string.minutes_later'))
          .fontSize(AppTypography.FORM_LARGE_TITLE)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)
      Row({ space: 5 }) {
        Text(this.heroValue())
          .fontSize(AppTypography.FORM_SCENE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.primaryTime.length > 0) {
          Text('·')
            .fontSize(AppTypography.FORM_META)
            .fontColor($r('app.color.text_secondary'))
          Text(this.primaryTime)
            .fontSize(AppTypography.FORM_SCENE)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Text(this.heroValue())
        .width('100%')
        .fontSize(AppTypography.FORM_MEDIUM_HERO)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 5 }) {
        Text(this.primaryTitle.length > 0 ? this.primaryTitle : $r('app.string.form_fallback_note'))
          .fontSize(AppTypography.FORM_SCENE)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.primaryTime.length > 0) {
          Text('·')
            .fontSize(AppTypography.FORM_META)
            .fontColor($r('app.color.text_secondary'))
          Text(this.primaryTime)
            .fontSize(AppTypography.FORM_SCENE)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private ExpandedHero(large: boolean) {
    if (this.primaryCountdownMinutes > 0) {
      Row({ space: large ? 7 : 5 }) {
        Text($r('app.string.form_distance'))
          .fontSize(large ? AppTypography.FORM_LARGE_HERO : AppTypography.FORM_SCENE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.heroValue())
          .fontSize(large ? AppTypography.FORM_LARGE_HERO : AppTypography.FORM_MEDIUM_HERO)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text($r('app.string.form_remaining'))
          .fontSize(large ? AppTypography.FORM_LARGE_TITLE : AppTypography.FORM_SCENE)
          .fontColor($r('app.color.text_secondary'))
        Text(this.primaryCountdownMinutes.toString())
          .fontSize(large ? AppTypography.FORM_LARGE_HERO : AppTypography.FORM_MEDIUM_HERO)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Text($r('app.string.unit_minute'))
          .fontSize(large ? AppTypography.FORM_LARGE_TITLE : AppTypography.FORM_SCENE)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    } else {
      Column({ space: 2 }) {
        Text(this.primaryTitle.length > 0 ? this.primaryTitle : $r('app.string.form_fallback'))
          .width('100%')
          .fontSize(AppTypography.FORM_BODY)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
        Text(this.heroValue())
          .width('100%')
          .fontSize(large ? AppTypography.FORM_LARGE_HERO : AppTypography.FORM_MEDIUM_HERO)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    Row({ space: large ? 8 : 5 }) {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(large ? AppTypography.FORM_SCENE : AppTypography.FORM_META)
        .fontColor([$r('app.color.text_secondary')])
      Text(this.heroMeta())
        .fontSize(large ? AppTypography.FORM_SCENE : AppTypography.FORM_META)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  private PrimaryActionButton(height: Resource, compact: boolean) {
    Text(this.primaryLabel(compact))
      .width('100%')
      .height(height)
      .fontSize(AppTypography.FORM_ACTION)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.accent'))
      .textAlign(TextAlign.Center)
      .borderRadius(AppDimensions.FORM_BUTTON_RADIUS)
      .systemMaterial(ImmersiveMaterials.PRIMARY_ACTION)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Clip })
      .onClick(() => this.handlePrimaryAction())
  }

  @Builder
  private SwitchAction(height: Resource) {
    Row({ space: 2 }) {
      Text($r('app.string.form_switch'))
        .fontSize(AppTypography.FORM_ACTION)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(AppTypography.FORM_ACTION)
        .fontColor([$r('app.color.accent')])
    }
    .height(height)
    .padding({ left: 12, right: 12 })
    .borderRadius(AppDimensions.FORM_BUTTON_RADIUS)
    .justifyContent(FlexAlign.Center)
    .systemMaterial(ImmersiveMaterials.SECONDARY_ACTION)
    .onClick(() => this.openApplication('sceneFormSwitch', 'pages/Index', 'openSceneSwitcher'))
  }

  @Builder
  private SupportRow(title: string, value: string, description: string, action: string,
    actionLabel: string, taskId: number, durationMinutes: number, showDivider: boolean) {
    Row({ space: 8 }) {
      Text(title)
        .width(62)
        .fontSize(AppTypography.FORM_BODY)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(value)
        .layoutWeight(1)
        .fontSize(AppTypography.FORM_SCENE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (description.length > 0) {
        Text(description)
          .fontSize(AppTypography.FORM_BODY)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      if (action === 'completeTask' && taskId > 0) {
        Text(actionLabel.length > 0 ? actionLabel : $r('app.string.complete'))
          .fontSize(AppTypography.FORM_ACTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
          .maxLines(1)
          .onClick(() => this.postMessage(action, taskId, durationMinutes))
      }
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
    if (showDivider) {
      Divider()
        .width('100%')
        .strokeWidth(1)
        .color($r('app.color.border'))
    }
  }

  @Builder
  private CompactCard() {
    Column() {
      Column() {
        this.SceneMeta(false)
        Column({ space: 2 }) {
          this.CompactHero()
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .onClick(() => this.openApplication('sceneFormCompact', this.primaryTargetPage()))
      this.PrimaryActionButton(AppDimensions.FORM_COMPACT_BUTTON_HEIGHT, true)
    }
    .width('100%')
    .height('100%')
    .padding(AppDimensions.FORM_COMPACT_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }

  @Builder
  private MediumCard() {
    Column({ space: 5 }) {
      Column({ space: 4 }) {
        this.SceneMeta(true)
        this.ExpandedHero(false)
      }
      .width('100%')
      .onClick(() => this.openApplication('sceneFormMedium', this.primaryTargetPage()))

      Blank()
        .layoutWeight(1)

      Row({ space: 8 }) {
        Column() {
          this.PrimaryActionButton(AppDimensions.FORM_BUTTON_HEIGHT, false)
        }
        .width(AppDimensions.FORM_PRIMARY_BUTTON_WIDTH)
        Blank()
        this.SwitchAction(AppDimensions.FORM_BUTTON_HEIGHT)
      }
      .width('100%')

      if (this.mediumFooterNote().length > 0) {
        Text(this.mediumFooterNote())
          .width('100%')
          .fontSize(AppTypography.FORM_BODY)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textAlign(TextAlign.End)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height('100%')
    .padding(AppDimensions.FORM_MEDIUM_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }

  @Builder
  private LargeCard() {
    Column({ space: 12 }) {
      Column({ space: 12 }) {
        this.SceneMeta(true)
        this.ExpandedHero(true)
      }
      .width('100%')
      .onClick(() => this.openApplication('sceneFormLarge', this.primaryTargetPage()))

      Row({ space: 12 }) {
        Column() {
          this.PrimaryActionButton(AppDimensions.FORM_LARGE_BUTTON_HEIGHT, false)
        }
        .width(AppDimensions.FORM_PRIMARY_BUTTON_WIDTH)
        Blank()
        this.SwitchAction(AppDimensions.FORM_LARGE_BUTTON_HEIGHT)
      }
      .width('100%')

      Divider()
        .width('100%')
        .strokeWidth(1)
        .color($r('app.color.border'))

      Column({ space: 4 }) {
        Text($r('app.string.today_focus'))
          .width('100%')
          .fontSize(AppTypography.FORM_LARGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        if (this.supportOneValue.length > 0) {
          this.SupportRow(this.supportOneTitle, this.supportOneValue, this.supportOneDescription,
            this.supportOneAction, this.supportOneActionLabel, this.supportOneTaskId,
            this.supportOneDurationMinutes, this.supportTwoValue.length > 0)
        }
        if (this.supportTwoValue.length > 0) {
          this.SupportRow(this.supportTwoTitle, this.supportTwoValue, this.supportTwoDescription,
            this.supportTwoAction, this.supportTwoActionLabel, this.supportTwoTaskId,
            this.supportTwoDurationMinutes, false)
        }
        if (this.supportOneValue.length === 0) {
          Text($r('app.string.no_today_focus'))
            .width('100%')
            .fontSize(AppTypography.FORM_SCENE)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(AppDimensions.FORM_LARGE_PADDING)
    .borderRadius(AppDimensions.RADIUS_PRIMARY)
    .systemMaterial(ImmersiveMaterials.CARD)
  }

  build() {
    if (this.formDimension === 2) {
      this.CompactCard()
    } else if (this.formDimension === 4) {
      this.LargeCard()
    } else {
      this.MediumCard()
    }
  }
}
