# CLAUDE.md

ABA PayWay partner API SDKs for Dart (`dart/`), Node.js (`node/`) and PHP
(`php/` + root `composer.json`), sharing one conformance suite in `spec/`.
Commands, CI and releases are in [CONTRIBUTING.md](CONTRIBUTING.md); this file
only lists the rules that are easy to get wrong.

## Never commit or expose

- `.aba-docs/` holds ABA's partner documentation, which is confidential to
  partners. Read it for reference; never commit it, `git add -f` it, or copy
  its text into code, comments, docs or issues. This repository is public.
- `.env` holds sandbox partner credentials. Never commit, print or log its
  values. `spec/fixtures/*.pem` are throwaway test keys, not ABA keys.

## Changing behaviour

1. Anything observable (payload fields, headers, parsing, error types, status
   codes) starts in `dart/tool/generate_test_vectors.dart`; regenerate with
   `cd dart && dart run tool/generate_test_vectors.dart` and commit
   `spec/test-vectors/`. Never hand-edit the vector JSON: RSA ciphertexts are
   randomized and must come from the generator.
2. Implement the change in all three SDKs until each passes the vectors.
   Keep them aligned: same behaviour, error types and status codes, each in
   its language's idioms (camelCase in Dart/Node, PSR interfaces in PHP).
3. PayWay business errors (`PTL02`, `PTL46`, ...) are returned in `status`;
   only transport, unexpected-response and decryption failures throw.

## Gotchas

- Dart: after editing an annotated model, run
  `dart run build_runner build --delete-conflicting-outputs` and commit the
  `*.g.dart` files (CI fails on stale ones). The Dart-only CI job uses
  `dart pub get --no-example` because `example/` is a Flutter app.
- Node: TypeScript stays on 6.x until `typescript-eslint` supports 7.
  No runtime dependencies: use the built-in `fetch` and `node:crypto`.
- PHP: `composer.json` must stay at the repository root so Packagist can read
  it; `.gitattributes` keeps everything but `php/src` out of the Composer
  archive. Plain `v*` tags are PHP releases; Dart and Node use `dart-v*` and
  `node-v*`.
- Sandbox tests reuse `registerRef: 'mylekha003'` on purpose: the sandbox
  accepts it again, and new refs would create new sandbox registrations.
- `www.mylekha.org` / `stage.mylekha.app` in tests are the whitelisted
  partner domains; keep them.

## Before finishing

Run the same checks CI runs for every SDK you touched (see CONTRIBUTING.md):
formatting, linting/static analysis, and the offline tests plus shared
vectors. Run the sandbox tests too when `.env` exists.
