export class OperationResult {
  success: boolean = false;
  errorCode: string = '';

  static ok(): OperationResult {
    const result: OperationResult = new OperationResult();
    result.success = true;
    return result;
  }

  static fail(errorCode: string): OperationResult {
    const result: OperationResult = new OperationResult();
    result.errorCode = errorCode;
    return result;
  }
}
