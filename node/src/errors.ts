/** What went wrong in a {@link PaywayPartnerError}. */
export type PaywayPartnerErrorType =
  /** PayWay could not be reached (DNS, refused connection, offline, ...) */
  | 'connection'
  /** the request took longer than the configured timeout */
  | 'timeout'
  /** the call was aborted with its `AbortSignal` */
  | 'cancelled'
  /** PayWay's TLS certificate was rejected */
  | 'badCertificate'
  /** PayWay answered without a PayWay `status` (e.g. an HTML error page) */
  | 'unexpectedResponse'
  /** PayWay data could not be decrypted with the partner private key */
  | 'decryption'
  /** a pushback body is not `{"return_params": "..."}` */
  | 'invalidPushback'
  /** any other failure; see `cause` */
  | 'unknown';

/**
 * Thrown when PayWay could not be reached, did not answer with a PayWay
 * status, or its data could not be decrypted. Branch on {@link type}.
 *
 * Business errors such as `PTL02 Wrong Hash` or `PTL46 Merchant not found`
 * are not thrown: they are returned in the response `status`.
 */
export class PaywayPartnerError extends Error {
  override readonly name = 'PaywayPartnerError';

  constructor(
    /** what went wrong */
    readonly type: PaywayPartnerErrorType,
    message: string,
    options: {
      /** HTTP status code, when a response was received */
      statusCode?: number;
      /** the underlying error */
      cause?: unknown;
    } = {},
  ) {
    super(message, { cause: options.cause });
    this.statusCode = options.statusCode;
  }

  /** HTTP status code, when a response was received */
  readonly statusCode: number | undefined;

  /** whether retrying the same call later may succeed */
  get isRetryable(): boolean {
    return (
      this.type === 'connection' ||
      this.type === 'timeout' ||
      (this.type === 'unexpectedResponse' && (this.statusCode ?? 0) >= 500)
    );
  }
}
