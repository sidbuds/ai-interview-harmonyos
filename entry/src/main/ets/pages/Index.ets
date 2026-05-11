import { picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { ResumeService, InterviewService, KbService, RagChatService, Resume, KbDoc, ResumeDetail, RagSession } from '../services/ApiServices';

interface InterviewItem {
  id: number;
  sessionId: string;
  totalQuestions: number;
  status: string;
  overallScore: number;
  createdAt: string;
  resumeFilename?: string;
}

@Entry
@ComponentV2
struct Index {
  @Local showFlag: Visibility = Visibility.Hidden;
  @Local showSideBar: boolean = false;
  @Local showKbDropdown: boolean = false;
  @Local isLoading: boolean = false;
  @Local showMore: boolean = false;

  @Local resumeList: Resume[] = [];
  @Local interviewList: InterviewItem[] = [];
  @Local chatList: RagSession[] = [];
  @Local kbList: KbDoc[] = [];
  @Local selectedKbIds: number[] = [];
  @Local chatInput: string = '';
  @Local isEditing: boolean = false;

  private sideBarWidth: number = 280;

  aboutToAppear(): void {
    this.chatInput = '';
    this.loadInitialData();
  }

  async loadInitialData(): Promise<void> {
    this.isLoading = true;
    try {
      const promiseResults = await Promise.all([
        ResumeService.getList(),
        KbService.list()
      ]);
      const resRes = promiseResults[0];
      const kbRes = promiseResults[1];

      this.resumeList = resRes.data;
      this.kbList = kbRes.data;

      // 加载面试记录
      await this.loadInterviews();
      // 加载对话历史
      await this.loadChatHistory();
    } catch (e) {
      console.error('初始加载失败');
    } finally {
      this.isLoading = false;
    }
  }

  getSelectedKbText(): string {
    if (this.selectedKbIds.length === 0) {
      return '未选择知识库';
    }
    if (this.selectedKbIds.length === 1) {
      for (let i = 0; i < this.kbList.length; i++) {
        if (Number(this.kbList[i].id) === this.selectedKbIds[0]) {
          return this.kbList[i].name;
        }
      }
    }
    return `已选择 ${this.selectedKbIds.length} 个知识库`;
  }

  isKbSelected(kbId: number): boolean {
    for (let i = 0; i < this.selectedKbIds.length; i++) {
      if (this.selectedKbIds[i] === kbId) {
        return true;
      }
    }
    return false;
  }

  toggleKbSelection(kbId: number): void {
    const newList: number[] = [];
    let found = false;
    for (let i = 0; i < this.selectedKbIds.length; i++) {
      if (this.selectedKbIds[i] === kbId) {
        found = true;
      } else {
        newList.push(this.selectedKbIds[i]);
      }
    }
    if (!found) {
      newList.push(kbId);
    }
    this.selectedKbIds = newList;
  }

  async loadInterviews(): Promise<void> {
    const allInterviews: InterviewItem[] = [];
    for (let i = 0; i < this.resumeList.length; i++) {
      const resume = this.resumeList[i];
      try {
        const detailRes = await ResumeService.getDetail(Number(resume.id));
        const detail = detailRes.data;
        if (detail.interviews && detail.interviews.length > 0) {
          for (let j = 0; j < detail.interviews.length; j++) {
            const interview = detail.interviews[j] as InterviewItem;
            interview.resumeFilename = decodeURIComponent(resume.filename);
            allInterviews.push(interview);
          }
        }
      } catch (e) {
        // 忽略单个简历加载失败
      }
    }
    allInterviews.sort((a: InterviewItem, b: InterviewItem) => {
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
    this.interviewList = allInterviews.slice(0, 10);
  }

  async loadChatHistory(): Promise<void> {
    try {
      const res = await RagChatService.list();
      this.chatList = res.data.slice(0, 10);
    } catch (e) {
      console.error('加载对话历史失败');
    }
  }

  cancel(): void {
    this.showFlag = Visibility.Hidden;
    this.isEditing = false;
    setTimeout(() => {
      this.showSideBar = false;
    }, 300);
  }

  async loadResumes(): Promise<void> {
    this.isLoading = true;
    try {
      const res = await ResumeService.getList();
      this.resumeList = res.data;
    } catch (e) {
      promptAction.showToast({ message: '简历加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  getDisplayLimit(): number {
    return this.showMore ? this.resumeList.length : 10;
  }

  async handleUploadResume(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options: picker.DocumentSelectOptions = { maxSelectNumber: 1 };
      const uris = await docPicker.select(options);

      if (uris.length > 0) {
        this.isLoading = true;
        await ResumeService.upload(uris[0]);
        promptAction.showToast({ message: '上传成功，AI分析中...' });
        await this.loadResumes();
      }
    } catch (e) {
      promptAction.showToast({ message: '上传失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleAddKnowledgeBase(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options: picker.DocumentSelectOptions = { maxSelectNumber: 1 };
      const uris = await docPicker.select(options);

      if (uris.length > 0) {
        this.isLoading = true;
        await KbService.upload(uris[0]);
        promptAction.showToast({ message: '知识库上传成功，向量化处理中...' });
        const res = await KbService.list();
        this.kbList = res.data;
      }
    } catch (e) {
      promptAction.showToast({ message: '知识库上传失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async handleSendChat(): Promise<void> {
    if (!this.chatInput.trim()) {
      return;
    }
    if (this.selectedKbIds.length === 0) {
      promptAction.showToast({ message: '请先选择知识库' });
      return;
    }
    const msg = this.chatInput;
    this.chatInput = '';
    router.pushUrl({
      url: 'pages/Chat',
      params: {
        question: msg,
        kbIds: JSON.stringify(this.selectedKbIds)
      }
    });
  }

  async handleDeleteInterview(sessionId: string): Promise<void> {
    try {
      await InterviewService.delete(sessionId);
      promptAction.showToast({ message: '删除成功' });
      await this.loadInterviews();
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async handleDeleteChat(sessionId: number): Promise<void> {
    try {
      await RagChatService.delete(sessionId);
      promptAction.showToast({ message: '删除成功' });
      await this.loadChatHistory();
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  async handleDeleteResume(resumeId: number): Promise<void> {
    try {
      await ResumeService.delete(resumeId);
      promptAction.showToast({ message: '删除成功' });
      await this.loadInitialData();
    } catch (e) {
      promptAction.showToast({ message: '删除失败' });
    }
  }

  @Builder
  sideBarMenu() {
    Column() {
      Row() {
        Text('历史')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Blank()
        Text(this.isEditing ? '退出编辑' : '编辑')
          .fontSize(14)
          .fontColor('#0A59F7')
          .onClick(() => {
            this.isEditing = !this.isEditing;
          })
      }
      .width('100%')
      .padding({ top: 24, bottom: 12, left: 16, right: 16 })
      Divider().color('#E5E7EB')

      Column() {
        Scroll() {
          Column({ space: 8 }) {
            if (this.isLoading) {
              Text('加载中...')
                .fontSize(14)
                .fontColor('#9CA3AF')
                .height(44)
                .width('100%')
                .textAlign(TextAlign.Start)
                .padding({ left: 16 })
            } else if (this.resumeList.length === 0 && this.interviewList.length === 0) {
              Text('暂无数据，请先上传简历')
                .fontSize(14)
                .fontColor('#9CA3AF')
                .height(44)
                .width('100%')
                .textAlign(TextAlign.Start)
                .padding({ left: 16 })
            } else {
              // 面试记录部分
              if (this.interviewList.length > 0) {
                Column({ space: 4 }) {
                  Text('面试记录')
                    .fontSize(12)
                    .fontColor('#999')
                    .width('100%')
                    .padding({ left: 16, top: 8 })

                  ForEach(this.interviewList, (item: InterviewItem) => {
                    Row() {
                      Column({ space: 2 }) {
                        Text(`面试 #${item.id}`)
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1F2937')
                          .width('100%')
                          .textAlign(TextAlign.Start)
                          .maxLines(1)
                        Text(item.status === 'EVALUATED' ? '已完成' : '进行中')
                          .fontSize(11)
                          .fontColor(item.status === 'EVALUATED' ? '#52C41A' : '#1890FF')
                      }
                      .layoutWeight(1)
                      if (this.isEditing) {
                        Text('✕')
                          .fontSize(16)
                          .fontColor('#FF4D4F')
                          .margin({ left: 8 })
                          .onClick(() => {
                            this.handleDeleteInterview(item.sessionId);
                          })
                      } else {
                        Text(item.createdAt.substring(5, 10))
                          .fontSize(11)
                          .fontColor('#9CA3AF')
                      }
                    }
                    .width('100%')
                    .height(44)
                    .padding({ left: 16, right: 16 })
                    .backgroundColor('#F0F7FF')
                    .borderRadius(6)
                    .onClick(() => {
                      if (this.isEditing) {
                        return;
                      }
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
                      this.cancel();
                    })
                  }, (item: InterviewItem) => item.id.toString())
                }
                .width('100%')
              }

              // 对话历史部分
              if (this.chatList.length > 0) {
                Column({ space: 4 }) {
                  Text('对话历史')
                    .fontSize(12)
                    .fontColor('#999')
                    .width('100%')
                    .padding({ left: 16, top: 8 })

                  ForEach(this.chatList, (item: RagSession) => {
                    Row() {
                      Column({ space: 2 }) {
                        Text(item.title)
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1F2937')
                          .width('100%')
                          .textAlign(TextAlign.Start)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(`${item.messageCount}条消息`)
                          .fontSize(11)
                          .fontColor('#6B7280')
                      }
                      .layoutWeight(1)
                      if (this.isEditing) {
                        Text('✕')
                          .fontSize(16)
                          .fontColor('#FF4D4F')
                          .margin({ left: 8 })
                          .onClick(() => {
                            this.handleDeleteChat(item.id);
                          })
                      } else {
                        Text(item.updatedAt.substring(5, 10))
                          .fontSize(11)
                          .fontColor('#9CA3AF')
                      }
                    }
                    .width('100%')
                    .height(44)
                    .padding({ left: 16, right: 16 })
                    .backgroundColor('#F9F0FF')
                    .borderRadius(6)
                    .onClick(() => {
                      if (this.isEditing) {
                        return;
                      }
                      router.pushUrl({
                        url: 'pages/RagChat',
                        params: { sessionId: item.id }
                      });
                      this.cancel();
                    })
                  }, (item: RagSession) => item.id.toString())
                }
                .width('100%')
              }

              // 简历部分
              if (this.resumeList.length > 0) {
                Column({ space: 4 }) {
                  Text('简历')
                    .fontSize(12)
                    .fontColor('#999')
                    .width('100%')
                    .padding({ left: 16, top: 8 })

                  ForEach(this.resumeList.slice(0, this.getDisplayLimit()), (item: Resume) => {
                    Row() {
                      Column({ space: 2 }) {
                        Text(decodeURIComponent(item.filename))
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1F2937')
                          .width('100%')
                          .textAlign(TextAlign.Start)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(item.latestScore > 0 ? `评分: ${item.latestScore}` : '待分析')
                          .fontSize(11)
                          .fontColor('#6B7280')
                          .width('100%')
                          .textAlign(TextAlign.Start)
                      }
                      .layoutWeight(1)
                      if (this.isEditing) {
                        Text('✕')
                          .fontSize(16)
                          .fontColor('#FF4D4F')
                          .margin({ left: 8 })
                          .onClick(() => {
                            this.handleDeleteResume(Number(item.id));
                          })
                      } else {
                        Text(item.uploadedAt.substring(5, 10))
                          .fontSize(11)
                          .fontColor('#9CA3AF')
                      }
                    }
                    .width('100%')
                    .height(44)
                    .padding({ left: 16, right: 16 })
                    .backgroundColor('#F6FFED')
                    .borderRadius(6)
                    .onClick(() => {
                      if (this.isEditing) {
                        return;
                      }
                      router.pushUrl({
                        url: 'pages/ResumeDetail',
                        params: { id: Number(item.id) }
                      });
                      this.cancel();
                    })
                  }, (item: Resume) => item.id.toString())
                }
                .width('100%')
              }

              if (this.resumeList.length > 10 && !this.showMore) {
                Text('展示更多 ▼')
                  .fontSize(13)
                  .fontColor('#0A59F7')
                  .width('100%')
                  .height(40)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.showMore = true;
                  })
              }
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .width('100%')

      Divider().color('#E5E7EB')

      Row({ space: 8 }) {
        Button('面试记录')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(36)
          .backgroundColor('#F0F7FF')
          .fontColor('#0A59F7')
          .borderRadius(6)
          .onClick(() => {
            this.cancel();
            router.pushUrl({ url: 'pages/InterviewList' });
          })

        Button('所有简历')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(36)
          .backgroundColor('#F0F7FF')
          .fontColor('#0A59F7')
          .borderRadius(6)
          .onClick(() => {
            this.cancel();
            router.pushUrl({ url: 'pages/ResumeList' });
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9FAFB')
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.08)' })
    .visibility(this.showFlag)
    .transition(TransitionEffect.OPACITY.animation({ duration: 300 }).combine(TransitionEffect.translate({ x: -100 })))
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      this.sideBarMenu()

      Stack() {
        Column() {
          Column() {
            Text('开始您的 AI 模拟面试')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
            Text('上传 PDF 或 Word 简历，AI 将为您定制专属面试方案')
              .fontSize(14)
              .fontColor(Color.Gray)
              .margin({ top: 8 })
            Column() {
              Text('点击此处上传文件')
              Text('支持 PDF, DOCX, TXT（最大 10MB）')
            }
            .border({ width: 1, color: Color.Black, radius: 20 })
            .margin(20)
            .padding({ top: 10, bottom: 10 })
            .onClick(() => this.handleUploadResume())
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            TextInput({ placeholder: '向 AI 提问或上传简历...' })
              .height(60)
              .backgroundColor(Color.Transparent)
              .border({ width: 0 })
              .fontSize(15)
              .padding({ left: 16, right: 16, top: 8, bottom: 4 })
              .focusOnTouch(true)
              .onChange((value: string) => {
                this.chatInput = value;
              })
              .onSubmit(() => this.handleSendChat())

            Divider().color('#E8E8E8').margin({ left: 16, right: 16 })

            Row({ space: 8 }) {
              Row({ space: 4 }) {
                Text(this.getSelectedKbText())
                  .fontSize(11)
                  .fontColor(this.selectedKbIds.length === 0 ? Color.Gray : '#0A59F7')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('▼')
                  .fontSize(9)
                  .fontColor(Color.Gray)
              }
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#EBEDF0')
              .borderRadius(12)
              .onClick(() => {
                this.showKbDropdown = !this.showKbDropdown;
              })

              Row({ space: 4 }) {
                Text('+')
                  .fontSize(13)
                  .fontColor('#0A59F7')
                Text('添加')
                  .fontSize(11)
                  .fontColor('#0A59F7')
              }
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#E6EEFF')
              .borderRadius(12)
              .onClick(() => this.handleAddKnowledgeBase())

              Text('管理')
                .fontSize(11)
                .fontColor('#0A59F7')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#E6EEFF')
                .borderRadius(12)
                .onClick(() => router.pushUrl({ url: 'pages/KnowledgeBase' }))
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 10 })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(24)
          .border({ width: 1, color: '#E0E0E0' })
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetY: -2 })
          .margin({ left: 16, right: 16, bottom: 16 })
        }
        .width('100%')
        .height('100%')
        .onClick(() => {
          if (this.showSideBar) {
            this.cancel();
          }
          this.showKbDropdown = false;
        })

        if (this.showKbDropdown) {
          Column() {
            List({ space: 0 }) {
              ForEach(this.kbList, (item: KbDoc) => {
                ListItem() {
                  Row({ space: 8 }) {
                    Checkbox()
                      .select(this.isKbSelected(Number(item.id)))
                      .width(18)
                      .height(18)
                      .onChange((value: boolean) => {
                        this.toggleKbSelection(Number(item.id));
                      })
                    Text(item.name)
                      .fontSize(13)
                      .fontColor('#333333')
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .height(34)
                  .padding({ left: 12, right: 12 })
                  .onClick(() => {
                    this.toggleKbSelection(Number(item.id));
                  })
                }
              }, (item: KbDoc) => item.id.toString())
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width(220)
          .height(Math.min(200, this.kbList.length * 38 + 16))
          .position({ x: 18, y: 530 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.12)', offsetY: -4 })
          .onClick(() => {
            // 阻止点击下拉框时关闭
          })
        }

        if (!this.showSideBar) {
          Button('☰')
            .fontSize(29)
            .backgroundColor(Color.White)
            .fontColor(Color.Black)
            .width(60)
            .height(30)
            .position({ x: 16, y: 10 })
            .onClick(() => {
              this.showFlag = Visibility.Visible;
              this.showSideBar = true;
            })
        }
      }
    }
    .sideBarWidth(this.sideBarWidth)
    .showControlButton(false)
    .showSideBar(this.showSideBar)
    .width('100%')
    .height('100%')
  }
}
