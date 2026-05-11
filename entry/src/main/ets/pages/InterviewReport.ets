import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { InterviewService, InterviewReport, InterviewDetail, AnswerDetail, CategoryScore, QuestionEvaluation, ReferenceAnswer } from '../services/ApiServices';

@Entry
@ComponentV2
struct InterviewReportPage {
  @Local sessionId: string = '';
  @Local report: InterviewReport | null = null;
  @Local isLoading: boolean = false;
  @Local activeTab: number = 0;
  @Local errorMessage: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['sessionId']) {
      this.sessionId = params['sessionId'];
      this.loadReport();
    }
  }

  async loadReport(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const res = await InterviewService.getDetail(this.sessionId);
      const detail = res.data;
      if (detail.overallScore !== undefined) {
        this.report = this.convertDetailToReport(detail);
      }
    } catch (e) {
      const err = e as Error;
      this.errorMessage = `加载报告失败: ${err.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  convertDetailToReport(detail: InterviewDetail): InterviewReport {
    const questionDetails: QuestionEvaluation[] = [];
    const refAnswers: ReferenceAnswer[] = [];

    for (let i = 0; i < detail.answers.length; i++) {
      const a = detail.answers[i];
      questionDetails.push({
        questionIndex: a.questionIndex,
        question: a.question,
        category: a.category,
        userAnswer: a.userAnswer,
        score: a.score,
        feedback: a.feedback
      });
      if (a.referenceAnswer) {
        refAnswers.push({
          questionIndex: a.questionIndex,
          question: a.question,
          referenceAnswer: a.referenceAnswer,
          keyPoints: a.keyPoints || []
        });
      }
    }

    return {
      sessionId: detail.sessionId,
      totalQuestions: detail.totalQuestions,
      overallScore: detail.overallScore,
      categoryScores: [],
      questionDetails: questionDetails,
      overallFeedback: detail.overallFeedback,
      strengths: detail.strengths,
      improvements: detail.improvements,
      referenceAnswers: refAnswers
    };
  }

  async handleExport(): Promise<void> {
    try {
      promptAction.showToast({ message: '正在导出...' });
      // 保存到缓存目录
      const fileName = `面试报告_${this.sessionId}.pdf`;
      const savePath = `${getContext(this).cacheDir}/${fileName}`;
      console.info('[Export] Saving to: ' + savePath);
      await InterviewService.downloadReport(this.sessionId, savePath);
      promptAction.showToast({ message: `导出成功: ${fileName}` });
    } catch (e) {
      const err = e as Error;
      console.error('[Export] Error: ' + err.message);
      promptAction.showToast({ message: '导出失败: ' + err.message });
    }
  }

  getScoreColor(score: number): string {
    if (score >= 80) {
      return '#52C41A';
    }
    if (score >= 60) {
      return '#FAAD14';
    }
    return '#FF4D4F';
  }

  getScoreLevel(score: number): string {
    if (score >= 90) {
      return '优秀';
    }
    if (score >= 80) {
      return '良好';
    }
    if (score >= 60) {
      return '及格';
    }
    return '待提升';
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .onClick(() => router.back())
        Text('面试报告')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        Blank()
        Text('导出PDF')
          .fontSize(14)
          .fontColor('#1890FF')
          .onClick(() => this.handleExport())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Divider().color('#F0F0F0')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('加载报告中...')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column({ space: 12 }) {
          Text('加载失败')
            .fontSize(16)
            .fontColor('#FF4D4F')
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#999')
            .padding({ left: 16, right: 16 })
          Text(`SessionID: ${this.sessionId}`)
            .fontSize(12)
            .fontColor('#999')
            .padding({ left: 16, right: 16 })
          Button('重新加载')
            .width(120)
            .height(36)
            .backgroundColor('#1890FF')
            .onClick(() => this.loadReport())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.report) {
        Column() {
          Text('暂无报告数据')
            .fontSize(16)
            .fontColor('#999')
          Button('重新加载')
            .width(120)
            .height(36)
            .backgroundColor('#1890FF')
            .margin({ top: 12 })
            .onClick(() => this.loadReport())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Row() {
          Text('总览')
            .fontSize(14)
            .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.activeTab === 0 ? '#1890FF' : '#666')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(40)
            .onClick(() => {
              this.activeTab = 0;
            })
          Text('详情')
            .fontSize(14)
            .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.activeTab === 1 ? '#1890FF' : '#666')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(40)
            .onClick(() => {
              this.activeTab = 1;
            })
          Text('参考答案')
            .fontSize(14)
            .fontWeight(this.activeTab === 2 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.activeTab === 2 ? '#1890FF' : '#666')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(40)
            .onClick(() => {
              this.activeTab = 2;
            })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')

        Scroll() {
          Column({ space: 12 }) {
            if (this.activeTab === 0) {
              Column({ space: 16 }) {
                Column({ space: 8 }) {
                  Text('综合评分')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                  Text(`${this.report.overallScore}`)
                    .fontSize(48)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getScoreColor(this.report.overallScore))
                  Text(this.getScoreLevel(this.report.overallScore))
                    .fontSize(14)
                    .fontColor(this.getScoreColor(this.report.overallScore))
                    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                    .backgroundColor(this.getScoreColor(this.report.overallScore) + '15')
                    .borderRadius(12)
                }
                .width('100%')
                .padding(24)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)

                Column({ space: 12 }) {
                  Text('分类得分')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                  ForEach(this.report.categoryScores, (item: CategoryScore, index?: number) => {
                    Row() {
                      Text(item.category)
                        .fontSize(14)
                        .layoutWeight(1)
                      Progress({ value: item.score, total: 100, type: ProgressType.Linear })
                        .width(120)
                        .height(8)
                      Text(`${item.score}`)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getScoreColor(item.score))
                        .width(40)
                        .textAlign(TextAlign.End)
                    }
                    .width('100%')
                  }, (item: CategoryScore, index?: number) => index !== undefined ? index.toString() : item.category)

                  Row({ space: 12 }) {
                    Column({ space: 8 }) {
                      Text('优势')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#52C41A')
                      ForEach(this.report.strengths, (item: string, index?: number) => {
                        Text(`• ${item}`)
                          .fontSize(12)
                          .fontColor('#666')
                      }, (item: string, index?: number) => index !== undefined ? index.toString() : item)
                    }
                    .layoutWeight(1)
                    .padding(12)
                    .backgroundColor('#F6FFED')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)

                    Column({ space: 8 }) {
                      Text('待改进')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FAAD14')
                      ForEach(this.report.improvements, (item: string, index?: number) => {
                        Text(`• ${item}`)
                          .fontSize(12)
                          .fontColor('#666')
                      }, (item: string, index?: number) => index !== undefined ? index.toString() : item)
                    }
                    .layoutWeight(1)
                    .padding(12)
                    .backgroundColor('#FFFBE6')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')

                  Column({ space: 8 }) {
                    Text('总体评价')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                    Text(this.report.overallFeedback)
                      .fontSize(14)
                      .fontColor('#666')
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }
            } else if (this.activeTab === 1) {
              ForEach(this.report.questionDetails, (item: QuestionEvaluation, index?: number) => {
                Column({ space: 8 }) {
                  Row() {
                    Text(`问题 ${item.questionIndex + 1}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                    Text(item.category)
                      .fontSize(12)
                      .fontColor('#1890FF')
                      .margin({ left: 8 })
                    Blank()
                    Text(`${item.score}分`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.getScoreColor(item.score))
                  }
                  .width('100%')

                  Text(item.question)
                    .fontSize(14)
                    .fontColor('#333')

                  Column({ space: 4 }) {
                    Text('你的回答')
                      .fontSize(12)
                      .fontColor('#999')
                    Text(item.userAnswer || '未作答')
                      .fontSize(14)
                      .fontColor('#666')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: 4 }) {
                    Text('评价')
                      .fontSize(12)
                      .fontColor('#999')
                    Text(item.feedback)
                      .fontSize(14)
                      .fontColor('#666')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }, (item: QuestionEvaluation, index?: number) => index !== undefined ? index.toString() : item.questionIndex.toString())
            } else {
              ForEach(this.report.referenceAnswers, (item: ReferenceAnswer, index?: number) => {
                Column({ space: 8 }) {
                  Row() {
                    Text(`问题 ${item.questionIndex + 1}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')

                  Text(item.question)
                    .fontSize(14)
                    .fontColor('#333')

                  Column({ space: 4 }) {
                    Text('参考答案')
                      .fontSize(12)
                      .fontColor('#999')
                    Text(item.referenceAnswer)
                      .fontSize(14)
                      .fontColor('#666')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)

                  if (item.keyPoints && item.keyPoints.length > 0) {
                    Column({ space: 4 }) {
                      Text('关键点')
                        .fontSize(12)
                        .fontColor('#999')
                      ForEach(item.keyPoints, (point: string, pointIndex?: number) => {
                        Text(`• ${point}`)
                          .fontSize(14)
                          .fontColor('#666')
                      }, (point: string, pointIndex?: number) => pointIndex !== undefined ? pointIndex.toString() : point)
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }, (item: ReferenceAnswer, index?: number) => index !== undefined ? index.toString() : item.questionIndex.toString())
            }
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
