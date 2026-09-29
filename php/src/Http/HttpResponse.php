<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Http;

/** An HTTP reply: status code and body. */
final readonly class HttpResponse
{
    public function __construct(
        public int $statusCode,
        public string $body,
    ) {
    }
}
