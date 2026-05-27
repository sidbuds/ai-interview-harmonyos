import { promptAction } from '@kit.ArkUI';
import { InterviewService, ResumeService, InterviewSession, InterviewQuestion } from '../services/ApiServices';

@Component
struct InterviewPage {
  @State sessionId: string = '';
  @State resumeId: number = 0;
  @State resumeText: string = '';
  @State session: InterviewSession | null = null;
  @State currentQuestion: InterviewQuestion | null = null;
  @State answerInput: string = '';
  @State isLoading: boolean = false;
  @State isSubmitting: boolean = false;
  @State questionIndex: number = 0;
  @State showUnfinishedDialog: boolean = false;
  @State unfinishedSession: InterviewSession | null = null;
  @State checkingUnfinished: boolean = false;
  @State isCreating: boolean = false;
  @State questionCount: number = 8;
  private stack: NavPathStack | undefined = undefined;

  loadParamsFromParam(param: Object): void {
    console.info('[Interview] loadParamsFromParam called, param: ' + JSON.stringify(param));
    if (typeof param === 'object' && param !== null) {
      const params = param as Record<string, Object>;
      this.resumeId = (params['resumeId'] as number) || 0;
      this.questionCount = (params['questionCount'] as number) || 8;
      console.info('[Interview] parsed resumeId: ' + this.resumeId + ', questionCount: ' + this.questionCount);
      this.loadResumeText();
      this.checkUnfinishedSession();
      return;
    }
    const paramStr = String(param);
    if (paramStr.startsWith('resume:')) {
      this.resumeId = Number(paramStr.substring(7));
      console.info('[Interview] parsed resumeId from string: ' + this.resumeId);
      this.loadResumeText();
      this.checkUnfinishedSession();
    } else {
      this.sessionId = paramStr;
      this.loadSession();
    }
  }

  async checkUnfinishedSession(): Promise<void> {
    if (!this.resumeId) return;
    this.checkingUnfinished = true;
    try {
      const res = await InterviewService.findUnfinished(this.resumeId);
      if (res?.data?.sessionId) {
        this.unfinishedSession = res.data;
        this.showUnfinishedDialog = true;
        this.checkingUnfinished = false;
      } else {
        this.checkingUnfinished = false;
        await this.createInterview();
      }
    } catch (e) {
      this.checkingUnfinished = false;
      await this.createInterview();
    }
  }

  async loadResumeText(): Promise<void> {
    if (!this.resumeId) return;
    try {
      const res = await ResumeService.getDetail(this.resumeId);
      if (res.data && res.data.resumeText) {
        this.resumeText = res.data.resumeText;
      }
    } catch (e) {
      console.error('加载简历内容失败');
    }
  }

  handleContinueUnfinished(): void {
    if (!this.unfinishedSession) return;
    this.sessionId = this.unfinishedSession.sessionId;
    this.showUnfinishedDialog = false;
    this.unfinishedSession = null;
    this.loadSession();
  }

  handleStartNew(): void {
    this.showUnfinishedDialog = false;
    this.unfinishedSession = null;
    this.createInterview();
  }

  async createInterview(): Promise<void> {
    if (!this.resumeId) return;
    console.info('[Interview] createInterview called with resumeId: ' + this.resumeId + ', questionCount: ' + this.questionCount);
    this.isCreating = true;
    try {
      const res = await InterviewService.create(this.resumeId, this.questionCount, this.resumeText);
      console.info('[Interview] createInterview response: ' + JSON.stringify(res.data));
      this.sessionId = res.data.sessionId;
      
      // 直接使用返回的数据
      if (res.data.questions && res.data.questions.length > 0) {
        this.session = res.data;
        this.questionIndex = res.data.currentQuestionIndex;
        this.currentQuestion = res.data.questions[this.questionIndex];
        this.isCreating = false;
      } else {
        // 如果返回的数据没有题目，等待一下再加载
        await new Promise<void>((resolve) => {
          setTimeout(() => { resolve(); }, 2000);
        });
        await this.loadSession();
      }
    } catch (e) {
      promptAction.showToast({ message: '创建面试失败' });
      this.isCreating = false;
    }
  }

  async loadSession(): Promise<void> {
    if (!this.sessionId) {
      promptAction.showToast({ message: '会话ID无效' });
      return;
    }
    this.isLoading = true;
    try {
      const res = await InterviewService.getSession(this.sessionId);
      this.session = res.data;
      this.questionIndex = res.data.currentQuestionIndex;

      if (res.data.questions && res.data.questions.length > 0) {
        this.currentQuestion = res.data.questions[this.questionIndex];
      }
    } catch (e) {
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleSubmitAnswer(): Promise<void> {
    if (!this.answerInput.trim()) {
      promptAction.showToast({ message: '请输入答案' });
      return;
    }

    this.isSubmitting = true;
    try {
      const res = await InterviewService.submitAnswer(
        this.sessionId,
        this.questionIndex,
        this.answerInput
      );

      const responseData = res.data as Record<string, boolean>;
      const hasNext = responseData['hasNext'];

      if (hasNext === false || this.questionIndex >= (this.session?.totalQuestions || 1) - 1) {
        promptAction.showToast({ message: '作答完成，报告生成中...' });
        this.stack?.pop();
      } else {
        this.questionIndex++;
        this.answerInput = '';
        if (this.session?.questions && this.questionIndex < this.session.questions.length) {
          this.currentQuestion = this.session.questions[this.questionIndex];
        }
      }
    } catch (e) {
      promptAction.showToast({ message: '提交失败' });
    } finally {
      this.isSubmitting = false;
    }
  }

  async handleSaveAnswer(): Promise<void> {
    if (!this.answerInput.trim()) {
      return;
    }

    try {
      await InterviewService.saveAnswer(
        this.sessionId,
        this.questionIndex,
        this.answerInput
      );
      promptAction.showToast({ message: '答案已暂存' });
    } catch (e) {
      promptAction.showToast({ message: '暂存失败' });
    }
  }

  async handleCompleteInterview(): Promise<void> {
    promptAction.showDialog({
      title: '确认交卷',
      message: '确定要提前交卷吗？',
      buttons: [
        { text: '取消', color: '#999' },
        { text: '确认交卷', color: '#1890FF' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        try {
          await InterviewService.complete(this.sessionId);
          promptAction.showToast({ message: '作答完成，报告生成中...' });
          this.stack?.pop();
        } catch (e) {
          promptAction.showToast({ message: '交卷失败' });
        }
      }
    });
  }

  getProgressPercent(): number {
    if (!this.session || this.session.totalQuestions === 0) {
      return 0;
    }
    return Math.round((this.questionIndex / this.session.totalQuestions) * 100);
  }

  getCategoryText(category: string): string {
    if (category === 'PROJECT') return '项目经历';
    if (category === 'JAVA_BASIC') return 'Java基础';
    if (category === 'JAVA_COLLECTION') return 'Java集合';
    if (category === 'JAVA_CONCURRENT') return 'Java并发';
    if (category === 'MYSQL') return 'MySQL';
    if (category === 'REDIS') return 'Redis';
    if (category === 'SPRING') return 'Spring';
    if (category === 'SPRING_BOOT') return 'Spring Boot';
    return category;
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('交卷')
            .fontSize(14)
            .fontColor('#1890FF')
            .onClick(() => this.handleCompleteInterview())
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')

        if (this.checkingUnfinished) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('检查未完成的面试...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.showUnfinishedDialog && this.unfinishedSession) {
          Column({ space: 16 }) {
            Column({ space: 8 }) {
              Text('检测到未完成的模拟面试')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#D97706')
              Text(`已完成 ${this.unfinishedSession.currentQuestionIndex} / ${this.unfinishedSession.totalQuestions} 题`)
                .fontSize(14)
                .fontColor('#92400E')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFBEB')
            .borderRadius(12)
            .border({ width: 1, color: '#FDE68A' })

            Row({ space: 12 }) {
              Button('继续完成')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#D97706')
                .onClick(() => this.handleContinueUnfinished())
              Button('开始新的')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#FFFFFF')
                .fontColor('#D97706')
                .border({ width: 1, color: '#D97706' })
                .onClick(() => this.handleStartNew())
            }
            .width('100%')
          }
          .layoutWeight(1)
          .padding(16)
          .justifyContent(FlexAlign.Center)
        } else if (this.isCreating) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('正在生成面试题目...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('加载问题中...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Column() {
              Row() {
                Text(`问题 ${this.questionIndex + 1}/${this.session?.totalQuestions || 0}`)
                  .fontSize(12)
                  .fontColor('#666')
                Blank()
                Text(`${this.getProgressPercent()}%`)
                  .fontSize(12)
                  .fontColor('#1890FF')
              }
              .width('100%')

              Progress({ value: this.getProgressPercent(), total: 100, type: ProgressType.Linear })
                .width('100%')
                .height(4)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')

            Scroll() {
              Column({ space: 12 }) {
                Column({ space: 12 }) {
                  if (this.currentQuestion?.category) {
                    Text(this.getCategoryText(this.currentQuestion.category))
                      .fontSize(12)
                      .fontColor('#1890FF')
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#E6F7FF')
                      .borderRadius(4)
                  }

                  Text(this.currentQuestion?.question || '暂无问题')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333')
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)

                Column({ space: 12 }) {
                  Text('你的回答')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)

                  TextArea({ placeholder: '请输入你的回答...', text: this.answerInput })
                    .width('100%')
                    .fontSize(14)
                    .backgroundColor('#F5F5F5')
                    .borderRadius(8)
                    .padding(12)
                    .onChange((value: string) => {
                      this.answerInput = value;
                    })
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)

            Row({ space: 12 }) {
              Button('暂存答案')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#F0F0F0')
                .fontColor('#333')
                .onClick(() => this.handleSaveAnswer())

              Button(this.isSubmitting ? '提交中...' : '提交并下一题')
                .layoutWeight(2)
                .height(44)
                .backgroundColor('#1890FF')
                .enabled(!this.isSubmitting)
                .onClick(() => this.handleSubmitAnswer())
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#F5F5F5')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .title('模拟面试')
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
      if (ctx.pathInfo && ctx.pathInfo.param) {
        this.loadParamsFromParam(ctx.pathInfo.param);
      }
    })
  }
}

@Builder
function InterviewBuilder() {
  InterviewPage()
}
