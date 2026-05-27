import { promptAction } from '@kit.ArkUI';
import { ResumeService, InterviewService, ResumeDetail, AnalysisHistory, InterviewItem } from '../services/ApiServices';

interface InterviewParams {
  resumeId: number;
  questionCount: number;
}

@Component
struct ResumeDetailPage {
  @State resumeId: number = 0;
  @State detail: ResumeDetail | null = null;
  @State isLoading: boolean = false;
  @State activeTab: number = 0;
  @State questionCount: number = 5;
  @State interviewList: InterviewItem[] = [];
  private stack: NavPathStack | undefined = undefined;

  loadParams(): void {
    if (this.stack) {
      const paramObj = this.stack.getParamByIndex(0) as number;
      if (paramObj && paramObj > 0) {
        this.resumeId = paramObj;
        console.info('[ResumeDetail] resumeId: ' + this.resumeId);
        this.loadDetail();
      }
    }
  }

  async loadDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await ResumeService.getDetail(this.resumeId);
      this.detail = res.data;
      if (res.data.interviews) {
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
      const params: InterviewParams = { resumeId: this.resumeId, questionCount: this.questionCount };
      console.info('[ResumeDetail] handleStartInterview called with params: ' + JSON.stringify(params));
      this.stack?.pushPath(new NavPathInfo('Interview', params));
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
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  getStatusColor(status: string): string {
    if (status === 'COMPLETED') return '#52C41A';
    if (status === 'PROCESSING') return '#1890FF';
    if (status === 'PENDING') return '#FAAD14';
    if (status === 'FAILED') return '#FF4D4F';
    return '#999';
  }

  getStatusText(status: string): string {
    if (status === 'COMPLETED') return '分析完成';
    if (status === 'PROCESSING') return '分析中';
    if (status === 'PENDING') return '待分析';
    if (status === 'FAILED') return '分析失败';
    return status;
  }

  getScoreColor(score: number): string {
    if (score >= 80) return '#52C41A';
    if (score >= 60) return '#FAAD14';
    return '#FF4D4F';
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('加载中...').fontSize(14).fontColor('#999').margin({ top: 8 })
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)
        } else if (this.detail) {
          Column() {
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

          Row() {
            Text('分析结果')
              .fontSize(14)
              .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.activeTab === 0 ? '#1890FF' : '#666')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .onClick(() => { this.activeTab = 0; })
            Text('面试记录')
              .fontSize(14)
              .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.activeTab === 1 ? '#1890FF' : '#666')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .onClick(() => { this.activeTab = 1; })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')


          Divider().color('#F0F0F0').padding(0)

          Scroll() {
            Column({ space: 12 }) {
              if (this.activeTab === 0) {
                if (this.detail.analyses && this.detail.analyses.length > 0) {
                  ForEach(this.detail.analyses, (analysis: AnalysisHistory) => {
                    Column({ space: 12 }) {
                      Row() {
                        Text('综合评分').fontSize(16).fontWeight(FontWeight.Bold)
                        Blank()
                        Text(`${analysis.overallScore}`).fontSize(32).fontWeight(FontWeight.Bold).fontColor(this.getScoreColor(analysis.overallScore))
                        Text('分').fontSize(14).fontColor('#999').margin({ left: 4 })
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
                        Text('总结').fontSize(14).fontWeight(FontWeight.Bold)
                        Text(analysis.summary).fontSize(14).fontColor('#666')
                      }
                      .width('100%')
                      .alignItems(HorizontalAlign.Start)

                      if (analysis.strengths && analysis.strengths.length > 0) {
                        Column({ space: 8 }) {
                          Text('优势').fontSize(14).fontWeight(FontWeight.Bold)
                          ForEach(analysis.strengths, (strength: string, index?: number) => {
                            Row({ space: 8 }) {
                              Text('•').fontSize(14).fontColor('#52C41A')
                              Text(strength).fontSize(14).fontColor('#666')
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
                    Text('暂无分析结果').fontSize(14).fontColor('#999')
                  }
                  .width('100%')
                  .height(100)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(8)
                }
              } else {
                Column({ space: 12 }) {
                  Column({ space: 12 }) {
                    Text('面试配置')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)

                    Column({ space: 8 }) {
                      Text('题目数量')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#333')

                      Row({ space: 12 }) {
                        ForEach([6, 8, 10, 12, 15], (count: number) => {
                          Button(`${count}`)
                            .width(56)
                            .height(44)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .backgroundColor(this.questionCount === count ? '#1890FF' : '#F0F0F0')
                            .fontColor(this.questionCount === count ? '#FFFFFF' : '#666')
                            .borderRadius(8)
                            .onClick(() => {
                              this.questionCount = count;
                            })
                        })
                      }
                      .width('100%')
                    }
                    .width('100%')

                    Column({ space: 8 }) {
                      Text('简历预览（前500字）')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#333')

                      Scroll() {
                        Text(this.detail?.resumeText ? this.detail.resumeText.substring(0, 500) + (this.detail.resumeText.length > 500 ? '...' : '') : '暂无简历内容')
                          .fontSize(12)
                          .fontColor('#666')
                          .padding(12)
                          .width('100%')
                      }
                      .backgroundColor('#F5F5F5')
                      .borderRadius(8)
                      .width('100%')
                      .height(120)
                      .scrollBar(BarState.Auto)
                      .edgeEffect(EdgeEffect.Spring)
                    }
                    .width('100%')

                    Text('题目分布：项目经历(20%) + MySQL(20%) + Redis(20%) + Java基础/集合/并发(30%) + Spring(10%)')
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
                              Text(item.status === 'EVALUATED' ? '已完成' : '进行中')
                                .fontSize(12)
                                .fontColor(item.status === 'EVALUATED' ? '#52C41A' : '#1890FF')
                            }
                            .width('100%')

                            Row({ space: 12 }) {
                              Text(`${item.totalQuestions}题`).fontSize(12).fontColor('#999')
                              Text(this.formatDate(item.createdAt)).fontSize(12).fontColor('#999')
                              if (item.overallScore > 0) {
                                Text(`评分: ${item.overallScore}`).fontSize(12).fontColor('#1890FF')
                              }
                            }
                            .width('100%')
                          }
                          .layoutWeight(1)

                          Text('>').fontSize(16).fontColor('#999')
                        }
                        .width('100%')
                        .padding(12)
                        .backgroundColor('#FAFAFA')
                        .borderRadius(8)
                        .onClick(() => {
                          if (item.status === 'EVALUATED' || item.status === 'COMPLETED') {
                            this.stack?.pushPath(new NavPathInfo('InterviewReport', item.sessionId));
                          } else if (item.status === 'IN_PROGRESS') {
                            promptAction.showToast({ message: '报告生成中，请稍后查看' });
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

              Blank()
                .width('100%')
                .height(1)
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
    .title('简历详情')
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
      this.loadParams();
    })
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
@Builder
function ResumeDetailBuilder() {
  ResumeDetailPage()
}
