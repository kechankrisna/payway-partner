<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

use Psr\Clock\ClockInterface;

/** Default PSR-20 clock: the current time. */
final class SystemClock implements ClockInterface
{
    public function now(): \DateTimeImmutable
    {
        return new \DateTimeImmutable();
    }
}
