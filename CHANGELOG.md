# Changelog

## [0.5.0](https://github.com/TheAkshitS/skills/compare/v0.4.0...v0.5.0) (2026-07-09)


### Features

* multi-harness install (pi, Agent Skills spec) with drop-in mirrors ([a90b1f6](https://github.com/TheAkshitS/skills/commit/a90b1f68fad589d1786bbfeb09fd877009e4a0b8))
* **validate-skills:** bidirectional mirror check, dup-name detection, portability ([9f82805](https://github.com/TheAkshitS/skills/commit/9f82805da4a70678d5cd91ceb67ec3ba80a420bc))


### Bug Fixes

* add trap cleanup and jq error guidance in install-pi.sh ([b17b00b](https://github.com/TheAkshitS/skills/commit/b17b00bb4658dc19f44230cf11febe1c7a3a61db))
* **eval-triggers:** add missing trailing newline ([2386ee2](https://github.com/TheAkshitS/skills/commit/2386ee2ae17ffb5fd227fce12b6137ee17cfed3d))
* **eval-triggers:** guard for-loops against empty array crash under set -u ([dc38c0d](https://github.com/TheAkshitS/skills/commit/dc38c0d9b5abb83f123966f45b126f4d40607957))
* **external-model:** harden dispatcher signals, timeout, --context, config ([44e3c47](https://github.com/TheAkshitS/skills/commit/44e3c47a67eb33ae9c0f1e755dd0daea42982c57))
* **external-model:** reject directories and oversized files for --context ([b02c28c](https://github.com/TheAkshitS/skills/commit/b02c28c73d37f15b3fbaf483d4294148f03d6374))
* **link-skills:** reconcile symlink-guard test with skip-one design; guard empty SKILL_SRCS ([f9661fd](https://github.com/TheAkshitS/skills/commit/f9661fd322ee898e581a497f220563a5caa350a1))
* **validate-skills:** mirror check honors bucketed paths; count desc chars not bytes ([25d8b9f](https://github.com/TheAkshitS/skills/commit/25d8b9f50976c8ce0df79f9b694cc3b82a1a927a))

## [0.4.0](https://github.com/TheAkshitS/skills/compare/v0.3.0...v0.4.0) (2026-07-06)


### Features

* **external-model:** add external-model skill and security hardening ([7a0e862](https://github.com/TheAkshitS/skills/commit/7a0e8628ba8701dce9aa6ed84cb4a52c7f4d8401))


### Bug Fixes

* **external-model:** accept dash-prefixed prompts in dispatcher parser ([6e65ed4](https://github.com/TheAkshitS/skills/commit/6e65ed4b825dd90d131e52ba6b3363fd02e78acf))
* **external-model:** close signal-leak, version-gate, and warning gaps in dispatcher ([b04ea7b](https://github.com/TheAkshitS/skills/commit/b04ea7b6513e26465f744e0e60d4c047863c9f4b))
* **external-model:** harden dispatcher — signal handling, version gate, security posture ([b2ae755](https://github.com/TheAkshitS/skills/commit/b2ae755f56a0e8e48f842f74a8030f7fd74aace1))
* **external-model:** harden security posture for Socket and Snyk audits ([8e58742](https://github.com/TheAkshitS/skills/commit/8e587425d9ff31701316084599320a77f89dc550))
* **external-model:** install --all per-file cleanup trap before the fanout ([1cb3787](https://github.com/TheAkshitS/skills/commit/1cb378796b96f4c97b4a0e749cdd2040709253c0))
* **external-model:** portable mktemp and restore RUN_TMPDIR exit trap ([db3f127](https://github.com/TheAkshitS/skills/commit/db3f127e0eef9a17ee7402bb65e2aeb6cfbdf9eb))

## [0.3.0](https://github.com/TheAkshitS/skills/compare/v0.2.0...v0.3.0) (2026-06-23)


### Features

* **external-model:** add skill to consult and delegate to external agentic CLIs ([75e41d6](https://github.com/TheAkshitS/skills/commit/75e41d609748e06b95ee366f3c8e5b55ad24fd75))
* **external-model:** add skill to consult/delegate to external agentic CLIs ([813500c](https://github.com/TheAkshitS/skills/commit/813500c5c4296afb683ae79d1e3f121fb7c72fc8))
* **external-model:** add skill to consult/delegate to external agentic CLIs ([513ba9c](https://github.com/TheAkshitS/skills/commit/513ba9c589e31509b32ba64becce51e89218325b))


### Bug Fixes

* **external-model:** correct dispatcher bugs surfaced by evals ([845e8e8](https://github.com/TheAkshitS/skills/commit/845e8e86db21e8c57099a665eccb3fc552747c87))
* **external-model:** isolate eval tmp files under FAKE_HOME ([23546de](https://github.com/TheAkshitS/skills/commit/23546decb2568d96575c5946d565375d678d605a))
* restore .release-please-manifest.json and CHANGELOG.md from main ([338fee0](https://github.com/TheAkshitS/skills/commit/338fee0ebc662c03e0b04a988e990621e6406bdb))

## [0.2.0](https://github.com/TheAkshitS/skills/compare/v0.1.0...v0.2.0) (2026-06-19)


### Features

* add c4-views skill and authoring template ([38fb92f](https://github.com/TheAkshitS/skills/commit/38fb92fb9f184deabce5a28a764ff20fe62f1878))
* add skills validation and listing scripts ([097e5b5](https://github.com/TheAkshitS/skills/commit/097e5b566c8e672f7a3df243132ccf02e37fc19a))


### Bug Fixes

* trigger release-please only on push to main ([ab89f25](https://github.com/TheAkshitS/skills/commit/ab89f25f7b3eefc98d608f8c6bbfbeb591d81d46))
* use simple release-type (no package.json) ([6d0eecd](https://github.com/TheAkshitS/skills/commit/6d0eecdc6a4b4d55100574286e6d0fe60f158679))
* use simple release-type (no package.json) ([a7f4b5a](https://github.com/TheAkshitS/skills/commit/a7f4b5ae6786691cbcf52f2aa4774b5fa06860b6))
