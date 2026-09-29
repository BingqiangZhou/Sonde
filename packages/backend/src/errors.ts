/** Typed application errors; the api layer maps these to HTTP status codes. */

export class AppError extends Error {
  readonly statusCode: number;

  constructor(message: string, statusCode = 500) {
    super(message);
    this.name = new.target.name;
    this.statusCode = statusCode;
  }
}

export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 400);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string) {
    super(message, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = '未授权') {
    super(message, 401);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409);
  }
}

/** Upstream provider (LLM / transcription / feed) call failed after retries. */
export class ProviderError extends AppError {
  readonly service: string;

  constructor(service: string, message: string) {
    super(`${service}: ${message}`, 502);
    this.service = service;
  }
}
