import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ResumeService, InterviewService, ResumeDetail, AnalysisHistory } from '../services/ApiServices';

interface InterviewItem {
  id: number;
  sessionId: string;
  totalQuestions: number;
  status: string;
  evaluateStatus: string;
  overallScore: number;
  createdAt: string;
  completedAt: string;
}

@Entry
@ComponentV2
struct ResumeDetailPage {
  @Local resumeId: number = 0;
  @Local detail: ResumeDetail | null = null;
  @Local isLoading: boolean = false;
  @Local activeTab: number = 0;
  @Local questionCount: number = 5;
  @Local interviewList: InterviewItem[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    if (params && params['id']) {
      this.resumeId = params['id'];
      this.loadDetail();
    }
  }

  async loadDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await ResumeService.getDetail(this.resumeId);
      this.detail = res.data;
      // 加载面试记录
      if (res.data.interviews && res.data.interviews.length > 0) {
        this.interviewList = [];
        for (let i = 0; i < res.data.interviews.length; i++) {
          this.interviewList.push(res.data.interviews[i] as InterviewItem);
        }
      }
    } catch (e) {
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleStartInterview(): Promise<void> {
    if (!this.detail || !this.detail.resumeText) {
      promptAction.showToast({ message: '简历内容为空，请等待分析完成' });
      return;
    }
    try {
      promptAction.showToast({ message: '正在创建面试...' });
      const res = await InterviewService.create(this.resumeId, this.questionCount, this.detail.resumeText);
      router.pushUrl({
        url: 'pages/Interview',
        params: { sessionId: res.data.sessionId }
      });
    } catch (e) {
      promptAction.showToast({ message: '创建面试失败' });
    }
  }

  async handleReanalyze(): Promise<void> {
    try {
      await ResumeService.reanalyze(this.resumeId);
      promptAction.showToast({ message: '重新分析中...' });
      await this.loadDetail();
    } catch (e) {
      promptAction.showToast({ message: '重新分析失败' });
    }
  }

  formatDate(dateStr: string): string {
    if (!dateStr) {
      return '';
    }
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  getStatusColor(status: string): string {
    if (status === 'COMPLETED') {
      return '#52C41A';
    } else if (status === 'PROCESSING') {
      return '#1890FF';
    } else if (status === 'PENDING') {
      return '#FAAD14';
    } else if (status === 'FAILED') {
      return '#FF4D4F';
    }
    return '#999';
  }

  getStatusText(status: string): string {
    if (status === 'COMPLETED') {
      return '分析完成';
    } else if (status === 'PROCESSING') {
      return '分析中';
    } else if (status === 'PENDING') {
      return '待分析';
    } else if (status === 'FAILED') {
      return '分析失败';
    }
    return status;
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

  getInterviewStatusText(status: string): string {
    if (status === 'EVALUATED') {
      return '已完成';
    } else if (status === 'COMPLETED') {
      return '待评估';
    } else if (status === 'IN_PROGRESS') {
      return '进行中';
    } else if (status === 'CREATED') {
      return '已创建';
    }
    return status;
  }

  getInterviewStatusColor(status: string): string {
    if (status === 'EVALUATED') {
      return '#52C41A';
    } else if (status === 'COMPLETED') {
      return '#FAAD14';
    } else if (status === 'IN_PROGRESS') {
      return '#1890FF';
    }
    return '#999';
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .onClick(() => router.back())
        Text('简历详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        Blank()
        Text('重新分析')
          .fontSize(14)
          .fontColor('#1890FF')
          .onClick(() => this.handleReanalyze())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      Divider().color('#F0F0F0')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.detail) {
        Column() {
          // 基本信息
          Column({ space: 8 }) {
            Row() {
              Text(decodeURIComponent(this.detail.filename))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.getStatusText(this.detail.analyzeStatus))
                .fontSize(12)
                .fontColor(this.getStatusColor(this.detail.analyzeStatus))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(this.getStatusColor(this.detail.analyzeStatus) + '15')
                .borderRadius(4)
            }
            .width('100%')

            Text(`上传时间: ${this.formatDate(this.detail.uploadedAt)}`)
              .fontSize(14)
              .fontColor('#666')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')

          // Tab 切换
          Row() {
            Text('分析结果')
              .fontSize(14)
              .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.activeTab === 0 ? '#1890FF' : '#666')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .onClick(() => {
                this.activeTab = 0;
              })
            Text('面试记录')
              .fontSize(14)
              .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.activeTab === 1 ? '#1890FF' : '#666')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .onClick(() => {
                this.activeTab = 1;
              })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')

          Divider().color('#F0F0F0')

          // 内容区域
          Scroll() {
            Column({ space: 12 }) {
              if (this.activeTab === 0) {
                // 分析结果
                if (this.detail.analyses && this.detail.analyses.length > 0) {
                  ForEach(this.detail.analyses, (analysis: AnalysisHistory) => {
                    Column({ space: 12 }) {
                      Row() {
                        Text('综合评分')
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                        Blank()
                        Text(`${analysis.overallScore}`)
                          .fontSize(32)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.getScoreColor(analysis.overallScore))
                        Text('分')
                          .fontSize(14)
                          .fontColor('#999')
                          .margin({ left: 4 })
                      }
                      .width('100%')

                      Column({ space: 8 }) {
                        Row() {
                          this.ScoreItem('内容', analysis.contentScore)
                          this.ScoreItem('结构', analysis.structureScore)
                          this.ScoreItem('技能', analysis.skillMatchScore)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.SpaceAround)

                        Row() {
                          this.ScoreItem('表达', analysis.expressionScore)
                          this.ScoreItem('项目', analysis.projectScore)
                          this.ScoreItem('', 0)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.SpaceAround)
                      }

                      Column({ space: 8 }) {
                        Text('总结')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                        Text(analysis.summary)
                          .fontSize(14)
                          .fontColor('#666')
                      }
                      .width('100%')
                      .alignItems(HorizontalAlign.Start)

                      if (analysis.strengths && analysis.strengths.length > 0) {
                        Column({ space: 8 }) {
                          Text('优势')
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                          ForEach(analysis.strengths, (strength: string, index?: number) => {
                            Row({ space: 8 }) {
                              Text('•')
                                .fontSize(14)
                                .fontColor('#52C41A')
                              Text(strength)
                                .fontSize(14)
                                .fontColor('#666')
                            }
                            .width('100%')
                          }, (item: string, index?: number) => index !== undefined ? index.toString() : item)
                        }
                        .width('100%')
                        .alignItems(HorizontalAlign.Start)
                      }

                      Text(`分析时间: ${this.formatDate(analysis.analyzedAt)}`)
                        .fontSize(12)
                        .fontColor('#999')
                    }
                    .width('100%')
                    .padding(16)
                    .backgroundColor('#FFFFFF')
                    .borderRadius(8)
                  }, (item: AnalysisHistory) => item.id.toString())
                } else {
                  Column() {
                    Text('暂无分析结果')
                      .fontSize(14)
                      .fontColor('#999')
                  }
                  .width('100%')
                  .height(100)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)
                }
              } else {
                // 面试记录
                Column({ space: 12 }) {
                  // 面试配置
                  Column({ space: 8 }) {
                    Text('面试配置')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)

                    Row() {
                      Text('题目数量')
                        .fontSize(14)
                        .fontColor('#333')
                        .layoutWeight(1)

                      Row({ space: 8 }) {
                        Button('-')
                          .width(32)
                          .height(32)
                          .backgroundColor('#F0F0F0')
                          .fontColor('#333')
                          .fontSize(18)
                          .borderRadius(16)
                          .onClick(() => {
                            if (this.questionCount > 3) {
                              this.questionCount--;
                            }
                          })

                        Text(`${this.questionCount}`)
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .width(40)
                          .textAlign(TextAlign.Center)

                        Button('+')
                          .width(32)
                          .height(32)
                          .backgroundColor('#F0F0F0')
                          .fontColor('#333')
                          .fontSize(18)
                          .borderRadius(16)
                          .onClick(() => {
                            if (this.questionCount < 20) {
                              this.questionCount++;
                            }
                          })
                      }
                    }
                    .width('100%')

                    Text('范围：3-20题')
                      .fontSize(12)
                      .fontColor('#999')
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)

                  Button('开始模拟面试')
                    .width('100%')
                    .height(44)
                    .backgroundColor('#1890FF')
                    .onClick(() => this.handleStartInterview())

                  // 面试记录列表
                  if (this.interviewList.length > 0) {
                    Column({ space: 8 }) {
                      Text('历史面试')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)

                      ForEach(this.interviewList, (item: InterviewItem) => {
                        Row() {
                          Column({ space: 4 }) {
                            Row() {
                              Text(`面试 #${item.id}`)
                                .fontSize(14)
                                .fontWeight(FontWeight.Medium)
                              Blank()
                              Text(this.getInterviewStatusText(item.status))
                                .fontSize(12)
                                .fontColor(this.getInterviewStatusColor(item.status))
                                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                                .backgroundColor(this.getInterviewStatusColor(item.status) + '15')
                                .borderRadius(4)
                            }
                            .width('100%')

                            Row({ space: 12 }) {
                              Text(`${item.totalQuestions}题`)
                                .fontSize(12)
                                .fontColor('#999')
                              Text(this.formatDate(item.createdAt))
                                .fontSize(12)
                                .fontColor('#999')
                              if (item.overallScore > 0) {
                                Text(`评分: ${item.overallScore}`)
                                  .fontSize(12)
                                  .fontColor('#1890FF')
                              }
                            }
                            .width('100%')
                          }
                          .layoutWeight(1)

                          Text('>')
                            .fontSize(16)
                            .fontColor('#999')
                        }
                        .width('100%')
                        .padding(12)
                        .backgroundColor('#FAFAFA')
                        .borderRadius(8)
                        .onClick(() => {
                          if (item.status === 'EVALUATED' || item.status === 'COMPLETED') {
                            router.pushUrl({
                              url: 'pages/InterviewReport',
                              params: { sessionId: item.sessionId }
                            });
                          } else if (item.status === 'IN_PROGRESS') {
                            router.pushUrl({
                              url: 'pages/Interview',
                              params: { sessionId: item.sessionId }
                            });
                          }
                        })
                      }, (item: InterviewItem) => item.id.toString())
                    }
                    .width('100%')
                    .padding(16)
                    .backgroundColor('#FFFFFF')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(16)
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  ScoreItem(label: string, score: number) {
    Column({ space: 4 }) {
      if (label) {
        Text(label)
          .fontSize(12)
          .fontColor('#999')
        Text(`${score}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor(score))
      }
    }
    .width(80)
    .alignItems(HorizontalAlign.Center)
  }
}
