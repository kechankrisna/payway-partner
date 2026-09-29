<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Exception;

/** What went wrong in a {@see PaywayPartnerException}. */
enum ErrorType: string
{
    /** PayWay could not be reached (DNS, refused connection, offline, ...) */
    case Connection = 'connection';

    /** the request took longer than the configured timeout */
    case Timeout = 'timeout';

    /** the call was cancelled */
    case Cancelled = 'cancelled';

    /** PayWay's TLS certificate was rejected */
    case BadCertificate = 'badCertificate';

    /** PayWay answered without a PayWay `status` (e.g. an HTML error page) */
    case UnexpectedResponse = 'unexpectedResponse';

    /** PayWay data could not be decrypted with the partner private key */
    case Decryption = 'decryption';

    /** a pushback body is not `{"return_params": "..."}` */
    case InvalidPushback = 'invalidPushback';

    /** any other failure; see the previous exception */
    case Unknown = 'unknown';
}
