import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import type { PaywayPartner, PaywayStatus } from '../src/index.js';

const spec = (path: string) =>
  fileURLToPath(new URL(`../../spec/${path}`, import.meta.url));

/** a file of spec/test-vectors, typed by the caller */
// eslint-disable-next-line @typescript-eslint/no-unnecessary-type-parameters -- JSON fixtures are typed at the call site
export function vectors<T = Record<string, unknown>>(name: string): T {
  return JSON.parse(readFileSync(spec(`test-vectors/${name}`), 'utf8')) as T;
}

/** a key of spec/fixtures */
export function fixture(name: string): string {
  return readFileSync(spec(`fixtures/${name}`), 'utf8');
}

interface PartnerVector {
  partner_id: string;
  partner_key: string;
  public_key: string;
  private_key: string;
  referer: string;
  base_url: string;
}

/** the partner every vector uses */
export function testPartner(): PaywayPartner {
  const p = vectors<PartnerVector>('partner.json');
  return {
    partnerName: 'Test Partner',
    partnerId: p.partner_id,
    partnerKey: p.partner_key,
    partnerPrivateKey: fixture(p.private_key),
    partnerPublicKey: fixture(p.public_key),
    partnerReferer: p.referer,
    baseApiUrl: p.base_url,
  };
}

/** a status with PayWay's field names, as the vectors spell it */
export function statusToJson(status: PaywayStatus): Record<string, string> {
  return {
    code: status.code,
    message: status.message,
    ...(status.tranId !== undefined && { tran_id: status.tranId }),
    ...(status.traceId !== undefined && { trace_id: status.traceId }),
    ...(status.correlationId !== undefined && {
      correlation_id: status.correlationId,
    }),
  };
}

/** a `fetch` that records requests and answers with `reply` */
export function fakeFetch(
  reply: (request: Request) => Response | Promise<Response>,
): typeof fetch & { requests: Request[]; bodies: Record<string, string>[] } {
  const requests: Request[] = [];
  const bodies: Record<string, string>[] = [];
  const fn = async (input: string | URL | Request, init?: RequestInit) => {
    const request = new Request(input, init);
    requests.push(request);
    bodies.push(
      JSON.parse(await request.clone().text()) as Record<string, string>,
    );
    init?.signal?.throwIfAborted();
    return reply(request);
  };
  return Object.assign(fn, { requests, bodies });
}
