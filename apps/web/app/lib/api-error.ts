/** api 不可用类错误：loader 抛出后由 root ErrorBoundary 呈现"服务暂时不可用"。
 *  同构模块（无服务端专属导入），经 SSR 序列化后 instanceof 会失效——
 *  ErrorBoundary 按 error.status 鸭子判型，勿依赖 instanceof。 */
export class ApiUnavailableError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'ApiUnavailableError';
    this.status = status;
  }
}
