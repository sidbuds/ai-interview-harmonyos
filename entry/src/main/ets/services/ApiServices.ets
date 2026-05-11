import { apiClient, Result } from '../common/HttpClient';
import http from '@ohos.net.http';

// ================= 1. 基础数据模型 =================

export interface Resume {
  id: number;
  filename: string;
  fileSize: number;
  uploadedAt: string;
  accessCount: number;
  latestScore: number;
  lastAnalyzedAt: string;
  interviewCount: number;
}

export interface KbDoc {
  id: string;
  name: string;
  category: string;
  status: string;
  vectorStatus: string;
  originalFilename: string;
  fileSize: number;
  contentType: string;
  uploadedAt: string;
  lastAccessedAt: string;
  accessCount: number;
  questionCount: number;
  vectorError: string;
  chunkCount: number;
}

export interface ResumeListItem {
  id: number;
  filename: string;
  fileSize: number;
  uploadedAt: string;
  accessCount: number;
  latestScore: number;
  lastAnalyzedAt: string;
  interviewCount: number;
  analyzeStatus: string;
}

export interface AnalysisHistory {
  id: number;
  overallScore: number;
  contentScore: number;
  structureScore: number;
  skillMatchScore: number;
  expressionScore: number;
  projectScore: number;
  summary: string;
  analyzedAt: string;
  strengths: string[];
  suggestions: object[];
}

export interface ResumeDetail {
  id: number;
  filename: string;
  fileSize: number;
  contentType: string;
  storageUrl: string;
  uploadedAt: string;
  accessCount: number;
  resumeText: string;
  analyzeStatus: string;
  analyzeError: string;
  analyses: AnalysisHistory[];
  interviews: object[];
}

export interface InterviewQuestion {
  questionIndex: number;
  question: string;
  type: string;
  category: string;
  userAnswer: string;
  score: number;
  feedback: string;
  isFollowUp: boolean;
  parentQuestionIndex: number;
}

export interface InterviewSession {
  sessionId: string;
  resumeText: string;
  totalQuestions: number;
  currentQuestionIndex: number;
  questions: InterviewQuestion[];
  status: string;
}

export interface CategoryScore {
  category: string;
  score: number;
  questionCount: number;
}

export interface QuestionEvaluation {
  questionIndex: number;
  question: string;
  category: string;
  userAnswer: string;
  score: number;
  feedback: string;
}

export interface ReferenceAnswer {
  questionIndex: number;
  question: string;
  referenceAnswer: string;
  keyPoints: string[];
}

export interface InterviewReport {
  sessionId: string;
  totalQuestions: number;
  overallScore: number;
  categoryScores: CategoryScore[];
  questionDetails: QuestionEvaluation[];
  overallFeedback: string;
  strengths: string[];
  improvements: string[];
  referenceAnswers: ReferenceAnswer[];
}

export interface AnswerDetail {
  questionIndex: number;
  question: string;
  category: string;
  userAnswer: string;
  score: number;
  feedback: string;
  referenceAnswer: string;
  keyPoints: string[];
  answeredAt: string;
}

export interface InterviewDetail {
  id: number;
  sessionId: string;
  totalQuestions: number;
  status: string;
  evaluateStatus: string;
  evaluateError: string;
  overallScore: number;
  overallFeedback: string;
  createdAt: string;
  completedAt: string;
  questions: object[];
  strengths: string[];
  improvements: string[];
  referenceAnswers: object[];
  answers: AnswerDetail[];
}

export interface KnowledgeBaseItem {
  id: number;
  name: string;
  category: string;
  originalFilename: string;
  fileSize: number;
  contentType: string;
  uploadedAt: string;
  lastAccessedAt: string;
  accessCount: number;
  questionCount: number;
  vectorStatus: string;
  vectorError: string;
  chunkCount: number;
}

export interface KnowledgeBaseStats {
  totalCount: number;
  totalQuestionCount: number;
  totalAccessCount: number;
  completedCount: number;
  processingCount: number;
}

export interface RagSession {
  id: number;
  title: string;
  messageCount: number;
  knowledgeBaseNames: string[];
  updatedAt: string;
  isPinned: boolean;
}

export interface RagMessage {
  id: number;
  type: string;
  content: string;
  createdAt: string;
}

export interface RagSessionDetail {
  id: number;
  title: string;
  knowledgeBases: KnowledgeBaseItem[];
  messages: RagMessage[];
  createdAt: string;
  updatedAt: string;
}

// 请求参数接口
interface CreateInterviewParams {
  resumeId: number;
  questionCount: number;
  resumeText: string;
}

interface SubmitAnswerParams {
  questionIndex: number;
  answer: string;
}

interface QueryParams {
  question: string;
  knowledgeBaseIds?: number[];
}

interface CreateRagSessionParams {
  knowledgeBaseIds: number[];
  title?: string;
}

interface UpdateTitleParams {
  title: string;
}

interface UpdateKnowledgeBasesParams {
  knowledgeBaseIds: number[];
}

interface UpdateCategoryParams {
  category: string;
}

interface SendMessageParams {
  question: string;
}

// ================= 2. 服务接口定义 =================

interface ResumeServiceType {
  upload: (fileUri: string) => Promise<Result<object>>;
  getList: () => Promise<Result<Resume[]>>;
  getDetail: (id: number) => Promise<Result<ResumeDetail>>;
  exportPdf: (id: number) => Promise<Result<void>>;
  delete: (id: number) => Promise<Result<void>>;
  reanalyze: (id: number) => Promise<Result<void>>;
}

interface InterviewServiceType {
  create: (resumeId: number, questionCount: number, resumeText: string) => Promise<Result<InterviewSession>>;
  getSession: (sessionId: string) => Promise<Result<InterviewSession>>;
  getCurrentQuestion: (sessionId: string) => Promise<Result<object>>;
  submitAnswer: (sessionId: string, questionIndex: number, answer: string) => Promise<Result<object>>;
  saveAnswer: (sessionId: string, questionIndex: number, answer: string) => Promise<Result<void>>;
  complete: (sessionId: string) => Promise<Result<void>>;
  getReport: (sessionId: string) => Promise<Result<InterviewReport>>;
  getDetail: (sessionId: string) => Promise<Result<InterviewDetail>>;
  exportReport: (sessionId: string) => Promise<Result<void>>;
  downloadReport: (sessionId: string, savePath: string) => Promise<void>;
  findUnfinished: (resumeId: number) => Promise<Result<InterviewSession>>;
  delete: (sessionId: string) => Promise<Result<void>>;
}

interface KbServiceType {
  upload: (fileUri: string, name?: string, category?: string) => Promise<Result<object>>;
  list: (sortBy?: string, vectorStatus?: string) => Promise<Result<KbDoc[]>>;
  getDetail: (id: number) => Promise<Result<KnowledgeBaseItem>>;
  delete: (id: number) => Promise<Result<void>>;
  query: (question: string, knowledgeBaseIds?: number[]) => Promise<Result<object>>;
  download: (id: number) => Promise<Result<void>>;
  stats: () => Promise<Result<KnowledgeBaseStats>>;
  search: (keyword: string) => Promise<Result<KbDoc[]>>;
  getCategories: () => Promise<Result<string[]>>;
  getByCategory: (category: string) => Promise<Result<KbDoc[]>>;
  updateCategory: (id: number, category: string) => Promise<Result<void>>;
  revectorize: (id: number) => Promise<Result<void>>;
}

interface RagChatServiceType {
  create: (knowledgeBaseIds: number[], title?: string) => Promise<Result<RagSession>>;
  list: () => Promise<Result<RagSession[]>>;
  getDetail: (sessionId: number) => Promise<Result<RagSessionDetail>>;
  updateTitle: (sessionId: number, title: string) => Promise<Result<void>>;
  togglePin: (sessionId: number) => Promise<Result<void>>;
  updateKnowledgeBases: (sessionId: number, knowledgeBaseIds: number[]) => Promise<Result<void>>;
  delete: (sessionId: number) => Promise<Result<void>>;
  sendMessage: (sessionId: number, question: string) => Promise<void>;
}

// ================= 3. 服务实现 =================

export const ResumeService: ResumeServiceType = {
  upload: (fileUri: string): Promise<Result<object>> => {
    return apiClient.uploadFile<object>('/api/resumes/upload', fileUri, 'file');
  },
  getList: (): Promise<Result<Resume[]>> => {
    return apiClient.request<Resume[]>(http.RequestMethod.GET, '/api/resumes');
  },
  getDetail: (id: number): Promise<Result<ResumeDetail>> => {
    return apiClient.request<ResumeDetail>(http.RequestMethod.GET, `/api/resumes/${id}/detail`);
  },
  exportPdf: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.GET, `/api/resumes/${id}/export`);
  },
  delete: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.DELETE, `/api/resumes/${id}`);
  },
  reanalyze: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.POST, `/api/resumes/${id}/reanalyze`);
  }
};

export const InterviewService: InterviewServiceType = {
  create: (resumeId: number, questionCount: number, resumeText: string): Promise<Result<InterviewSession>> => {
    const req: CreateInterviewParams = { resumeId: resumeId, questionCount: questionCount, resumeText: resumeText };
    return apiClient.request<InterviewSession>(http.RequestMethod.POST, '/api/interview/sessions', req);
  },
  getSession: (sessionId: string): Promise<Result<InterviewSession>> => {
    return apiClient.request<InterviewSession>(http.RequestMethod.GET, `/api/interview/sessions/${sessionId}`);
  },
  getCurrentQuestion: (sessionId: string): Promise<Result<object>> => {
    return apiClient.request<object>(http.RequestMethod.GET, `/api/interview/sessions/${sessionId}/question`);
  },
  submitAnswer: (sessionId: string, questionIndex: number, answer: string): Promise<Result<object>> => {
    const req: SubmitAnswerParams = { questionIndex: questionIndex, answer: answer };
    return apiClient.request<object>(http.RequestMethod.POST, `/api/interview/sessions/${sessionId}/answers`, req);
  },
  saveAnswer: (sessionId: string, questionIndex: number, answer: string): Promise<Result<void>> => {
    const req: SubmitAnswerParams = { questionIndex: questionIndex, answer: answer };
    return apiClient.request<void>(http.RequestMethod.PUT, `/api/interview/sessions/${sessionId}/answers`, req);
  },
  complete: (sessionId: string): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.POST, `/api/interview/sessions/${sessionId}/complete`);
  },
  getReport: (sessionId: string): Promise<Result<InterviewReport>> => {
    return apiClient.request<InterviewReport>(http.RequestMethod.GET, `/api/interview/sessions/${sessionId}/report`, undefined, undefined, 180000);
  },
  getDetail: (sessionId: string): Promise<Result<InterviewDetail>> => {
    return apiClient.request<InterviewDetail>(http.RequestMethod.GET, `/api/interview/sessions/${sessionId}/details`);
  },
  exportReport: (sessionId: string): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.GET, `/api/interview/sessions/${sessionId}/export`);
  },
  downloadReport: (sessionId: string, savePath: string): Promise<void> => {
    return apiClient.downloadFile(`/api/interview/sessions/${sessionId}/export`, savePath);
  },
  findUnfinished: (resumeId: number): Promise<Result<InterviewSession>> => {
    return apiClient.request<InterviewSession>(http.RequestMethod.GET, `/api/interview/sessions/unfinished/${resumeId}`);
  },
  delete: (sessionId: string): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.DELETE, `/api/interview/sessions/${sessionId}`);
  }
};

export const KbService: KbServiceType = {
  upload: (fileUri: string, name?: string, category?: string): Promise<Result<object>> => {
    const extraFields: Record<string, string> = {};
    if (name) {
      extraFields['name'] = name;
    }
    if (category) {
      extraFields['category'] = category;
    }
    return apiClient.uploadFile<object>('/api/knowledgebase/upload', fileUri, 'file', extraFields);
  },
  list: (sortBy?: string, vectorStatus?: string): Promise<Result<KbDoc[]>> => {
    let qs = '';
    if (sortBy) {
      qs += `sortBy=${encodeURIComponent(sortBy)}&`;
    }
    if (vectorStatus) {
      qs += `vectorStatus=${encodeURIComponent(vectorStatus)}&`;
    }
    if (qs.length > 0) {
      qs = qs.slice(0, -1);
    }
    return apiClient.request<KbDoc[]>(http.RequestMethod.GET, '/api/knowledgebase/list', undefined, qs || undefined);
  },
  getDetail: (id: number): Promise<Result<KnowledgeBaseItem>> => {
    return apiClient.request<KnowledgeBaseItem>(http.RequestMethod.GET, `/api/knowledgebase/${id}`);
  },
  delete: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.DELETE, `/api/knowledgebase/${id}`);
  },
  query: (question: string, knowledgeBaseIds?: number[]): Promise<Result<object>> => {
    const req: QueryParams = { question: question, knowledgeBaseIds: knowledgeBaseIds };
    return apiClient.request<object>(http.RequestMethod.POST, '/api/knowledgebase/query', req);
  },
  download: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.GET, `/api/knowledgebase/${id}/download`);
  },
  stats: (): Promise<Result<KnowledgeBaseStats>> => {
    return apiClient.request<KnowledgeBaseStats>(http.RequestMethod.GET, '/api/knowledgebase/stats');
  },
  search: (keyword: string): Promise<Result<KbDoc[]>> => {
    return apiClient.request<KbDoc[]>(http.RequestMethod.GET, '/api/knowledgebase/search', undefined, `keyword=${encodeURIComponent(keyword)}`);
  },
  getCategories: (): Promise<Result<string[]>> => {
    return apiClient.request<string[]>(http.RequestMethod.GET, '/api/knowledgebase/categories');
  },
  getByCategory: (category: string): Promise<Result<KbDoc[]>> => {
    return apiClient.request<KbDoc[]>(http.RequestMethod.GET, `/api/knowledgebase/category/${encodeURIComponent(category)}`);
  },
  updateCategory: (id: number, category: string): Promise<Result<void>> => {
    const req: UpdateCategoryParams = { category: category };
    return apiClient.request<void>(http.RequestMethod.PUT, `/api/knowledgebase/${id}/category`, req);
  },
  revectorize: (id: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.POST, `/api/knowledgebase/${id}/revectorize`);
  }
};

export const RagChatService: RagChatServiceType = {
  create: (knowledgeBaseIds: number[], title?: string): Promise<Result<RagSession>> => {
    const req: CreateRagSessionParams = { knowledgeBaseIds: knowledgeBaseIds, title: title };
    return apiClient.request<RagSession>(http.RequestMethod.POST, '/api/rag-chat/sessions', req);
  },
  list: (): Promise<Result<RagSession[]>> => {
    return apiClient.request<RagSession[]>(http.RequestMethod.GET, '/api/rag-chat/sessions');
  },
  getDetail: (sessionId: number): Promise<Result<RagSessionDetail>> => {
    return apiClient.request<RagSessionDetail>(http.RequestMethod.GET, `/api/rag-chat/sessions/${sessionId}`);
  },
  updateTitle: (sessionId: number, title: string): Promise<Result<void>> => {
    const req: UpdateTitleParams = { title: title };
    return apiClient.request<void>(http.RequestMethod.PUT, `/api/rag-chat/sessions/${sessionId}/title`, req);
  },
  togglePin: (sessionId: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.PUT, `/api/rag-chat/sessions/${sessionId}/pin`);
  },
  updateKnowledgeBases: (sessionId: number, knowledgeBaseIds: number[]): Promise<Result<void>> => {
    const req: UpdateKnowledgeBasesParams = { knowledgeBaseIds: knowledgeBaseIds };
    return apiClient.request<void>(http.RequestMethod.PUT, `/api/rag-chat/sessions/${sessionId}/knowledge-bases`, req);
  },
  delete: (sessionId: number): Promise<Result<void>> => {
    return apiClient.request<void>(http.RequestMethod.DELETE, `/api/rag-chat/sessions/${sessionId}`);
  },
  sendMessage: (sessionId: number, question: string): Promise<void> => {
    const req: SendMessageParams = { question: question };
    return apiClient.requestStream(`/api/rag-chat/sessions/${sessionId}/messages/stream`, req, 180000);
  }
};
