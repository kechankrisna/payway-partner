# Contributing

## Layout

| Folder | What | Tooling |
|---|---|---|
| `spec/test-vectors/` | Conformance vectors, generated from the Dart reference implementation | `cd dart && dart run tool/generate_test_vectors.dart` |
| `spec/fixtures/` | Throwaway RSA keys used by the vectors and unit tests | — |
| `dart/` | Dart SDK | Dart 3.9+ |
| `node/` | Node.js SDK | Node 22+ |
| `php/` + `composer.json` | PHP SDK | PHP 8.3+, Composer |

## Running the tests

Offline tests need nothing else. Sandbox tests need ABA sandbox credentials
in `.env` at the repository root (copy `.env.example`); they are skipped
without it. **Never commit `.env`**, and keep ABA's documentation out of the
repository: it is confidential to partners.

Each block starts from the repository root and has no comments, so it can
be pasted as is into zsh (which does not treat `#` as a comment
interactively by default).

Dart: format, offline tests (`-x integration`), then offline + sandbox.

```sh
cd dart
dart pub get
dart format lib test tool
dart test -x integration
dart test
```

Node: offline tests, offline + sandbox, ESLint (strict, type-checked), then
Prettier.

```sh
cd node
npm ci
npm run test:unit
npm test
npm run lint
npm run format
```

PHP: offline tests, offline + sandbox, PHPStan (level max), then the PER-CS
code style check (`composer cs:fix` applies it).

```sh
composer install
composer test:unit
composer test
composer analyse
composer cs
```

## CI

Each SDK has its own workflow (`dart.yml`, `node.yml`, `php.yml`) that runs on
pushes and pull requests touching its folder or `spec/`. `all.yml` runs the
three together: start it from the Actions tab (**all → Run workflow**), and
it also runs every Monday to catch breakage no commit triggers, such as new
SDK or dependency releases or changes on the PayWay sandbox. GitHub pauses
scheduled workflows after 60 days without repository activity; re-enable
them from the Actions tab.

## Changing behaviour

1. If the change is observable (a field, a header, an error), add or update a
   vector in `dart/tool/generate_test_vectors.dart` and regenerate
   `spec/test-vectors/`. RSA ciphertexts are randomized, so only regenerate
   when a vector changes, and commit the result.
2. Implement the change in **every** SDK until each passes the vectors.
3. Add a CHANGELOG entry in each SDK you changed.

## Releasing

Each SDK has its own version and is released by pushing a tag. CI checks that
the tag matches the version in the code before publishing.

| SDK | Bump the version in | Tag | Published by |
|---|---|---|---|
| Dart | `dart/pubspec.yaml`, `dart/lib/src/version.dart` | `dart-v2.0.1` | `.github/workflows/release-dart.yml` (pub.dev automated publishing) |
| Node | `node/package.json`, `node/src/version.ts` | `node-v1.0.1` | `.github/workflows/release-node.yml` (npm) |
| PHP | `php/src/Version.php` | `v1.0.1` | Packagist reads the tag via its GitHub webhook |

Plain `v*` tags are reserved for PHP: Packagist ignores `dart-v*` and
`node-v*` tags because they do not parse as versions.

### One-time setup

- **pub.dev**: on the package admin page, enable automated publishing from
  GitHub Actions for `kechankrisna/payway-partner` with tag pattern
  `dart-v{{version}}`.
- **npm**: publish from the npm account `kechankrisna` (it owns the
  `@kechankrisna` scope), then either configure trusted publishing for `.github/workflows/release-node.yml`, or add an `NPM_TOKEN`
  repository secret.
- **Packagist**: submit `https://github.com/kechankrisna/payway-partner` and
  enable the GitHub webhook so new tags are picked up.
- **Sandbox tests in CI (optional)**: add the content of your sandbox `.env`
  as the `ABA_SANDBOX_ENV` repository secret.
