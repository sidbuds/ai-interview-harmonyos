import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { InterviewService, InterviewSession, InterviewQuestion } from '../services/ApiServices';

@Entry
@ComponentV2
struct InterviewPage {
  @Local sessionId: string = '';
  @Local session: InterviewSession | null = null;
  @Local currentQuestion: InterviewQuestion | null = null;
  @Local answerInput: string = '';
  @Local isLoading: boolean = false;
  @Local isSubmitting: boolean = false;
  @Local questionIndex: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['sessionId']) {
      this.sessionId = params['sessionId'];
      this.loadSession();
    }
  }

  async loadSession(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await InterviewService.getSession(this.sessionId);
      this.session = res.data;
      this.questionIndex = res.data.currentQuestionIndex;

      // 从session的questions数组中获取当前问题
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

      const responseData = res.data as Record<string, Object>;
      const hasNext = responseData['hasNext'] as boolean;

      if (hasNext === false || this.questionIndex >= (this.session?.totalQuestions || 1) - 1) {
        promptAction.showToast({ message: '面试完成！' });
        router.replaceUrl({
          url: 'pages/InterviewReport',
          params: { sessionId: this.sessionId }
        });
      } else {
        this.questionIndex++;
        this.answerInput = '';
        // 从session的questions数组中获取下一个问题
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
          router.replaceUrl({
            url: 'pages/InterviewReport',
            params: { sessionId: this.sessionId }
          });
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
    if (category === 'PROJECT') {
      return '项目经历';
    } else if (category === 'JAVA_BASIC') {
      return 'Java基础';
    } else if (category === 'JAVA_COLLECTION') {
      return 'Java集合';
    } else if (category === 'JAVA_CONCURRENT') {
      return 'Java并发';
    } else if (category === 'MYSQL') {
      return 'MySQL';
    } else if (category === 'REDIS') {
      return 'Redis';
    } else if (category === 'SPRING') {
      return 'Spring';
    } else if (category === 'SPRING_BOOT') {
      return 'Spring Boot';
    }
    return category;
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .onClick(() => {
            this.handleCompleteInterview();
          })
        Text('模拟面试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        Blank()
        Text('交卷')
          .fontSize(14)
          .fontColor('#1890FF')
          .onClick(() => this.handleCompleteInterview())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

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

      Divider().color('#F0F0F0')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载问题中...')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 16 }) {
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
              .height(200)
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
        }
        .layoutWeight(1)
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
