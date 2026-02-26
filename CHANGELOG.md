# Changelog

## [0.4.1](https://github.com/oscarlehuu/macmonitor/compare/v0.4.0...v0.4.1) (2026-02-20)


### Bug Fixes

* **release:** enable hardened runtime for notarization ([#21](https://github.com/oscarlehuu/macmonitor/issues/21)) ([5eac369](https://github.com/oscarlehuu/macmonitor/commit/5eac36947520384b0bdc67d8bb80ea9336e93e13))

## [0.4.0](https://github.com/oscarlehuu/macmonitor/compare/v0.3.3...v0.4.0) (2026-02-20)


### Features

* implement next-wave roadmap and mock-aligned UI updates ([#19](https://github.com/oscarlehuu/macmonitor/issues/19)) ([51c0891](https://github.com/oscarlehuu/macmonitor/commit/51c089161e099975a56561cdc8b1cd95cf7b08bb))

## [0.3.3](https://github.com/oscarlehuu/macmonitor/compare/v0.3.2...v0.3.3) (2026-02-18)


### Bug Fixes

* enforce signed sparkle releases and real updater notes ([#17](https://github.com/oscarlehuu/macmonitor/issues/17)) ([a3dc19a](https://github.com/oscarlehuu/macmonitor/commit/a3dc19a83016b9a6fbc85391754ecda47bc1f5b1))

## [0.3.2](https://github.com/oscarlehuu/macmonitor/compare/v0.3.1...v0.3.2) (2026-02-16)


### Bug Fixes

* **ci:** publish Sparkle release notes and reduce duplicate CI runs ([54c6f60](https://github.com/oscarlehuu/macmonitor/commit/54c6f60cf19beb24da646d974a158b89af355ba1))
* **ci:** publish Sparkle release notes file and reduce duplicate runs ([05bbcf6](https://github.com/oscarlehuu/macmonitor/commit/05bbcf6bc8e9c182ecb20cc45951e3ce3ba47ed6))
* detect untracked release notes changes ([90f4c80](https://github.com/oscarlehuu/macmonitor/commit/90f4c80e6fd682d2571f27e7e34078cd08e10c82))

## [0.3.1](https://github.com/oscarlehuu/macmonitor/compare/v0.3.0...v0.3.1) (2026-02-16)


### Bug Fixes

* **release:** correct Sparkle download prefix in appcast generation ([49008c7](https://github.com/oscarlehuu/macmonitor/commit/49008c7abe08893479986006a687d5ac995201d5))
* **release:** correct Sparkle download prefix in appcast generation ([00ce6fb](https://github.com/oscarlehuu/macmonitor/commit/00ce6fbc06404e94e0d990e562292d3f9bc4d612))

## [0.3.0](https://github.com/oscarlehuu/macmonitor/compare/v0.2.0...v0.3.0) (2026-02-13)


### Features

* add storage manager cleanup workflow ([6d64f25](https://github.com/oscarlehuu/macmonitor/commit/6d64f250bde4eb665748fd6a83077283d3b8b0f1))
* add storage manager cleanup workflow ([7eb7baa](https://github.com/oscarlehuu/macmonitor/commit/7eb7baaf2d1e68eccdcec8c2c8526ac2d2affb57))


### Bug Fixes

* address scan cache staleness, /private protection gap, and relaunch guard ([69fc09a](https://github.com/oscarlehuu/macmonitor/commit/69fc09a76676605754fe744789d9119bd289fdc0))
* normalize ring chart slices to prevent exceeding 360 degrees ([faaaa56](https://github.com/oscarlehuu/macmonitor/commit/faaaa56369a52c1864b18fc4f15295ffb8cbf1b4))
* remove .skipsPackageDescendants from directorySize enumerator so app bundle sizes are computed correctly ([a41b82c](https://github.com/oscarlehuu/macmonitor/commit/a41b82cd45f4be5175a39d14e83e35a4e875e444))

## [0.2.0](https://github.com/oscarlehuu/macmonitor/compare/v0.1.0...v0.2.0) (2026-02-09)


### Features

* add helper-backed battery management and battery UI ([4c69c5b](https://github.com/oscarlehuu/macmonitor/commit/4c69c5b3d148df6853201c9325140efcce9b54fa))
* add RAM details process management and compact settings UI ([81e6b73](https://github.com/oscarlehuu/macmonitor/commit/81e6b73e44bbc858777ad8c39645821fcaa2a911))
* add RAM policy management and redesign popover UI ([2937e38](https://github.com/oscarlehuu/macmonitor/commit/2937e38c4f5a9b01987ad6c7e5ae9ec8182a380e))
* add Sparkle updater and automated release pipeline ([f84bb69](https://github.com/oscarlehuu/macmonitor/commit/f84bb69d126a477e817e2d5994193b4b9cbd2e09))
* **battery:** implement helper-backed battery management ([d66e840](https://github.com/oscarlehuu/macmonitor/commit/d66e8407cb812897d9b89f9904c82e2912de0602))
* menu bar icon metrics + settings redesign ([9cc7682](https://github.com/oscarlehuu/macmonitor/commit/9cc76821f7834dafdeda942d3c31418f4dafac54))
* **menu-bar:** add icon-based metric display and settings redesign ([b3edb30](https://github.com/oscarlehuu/macmonitor/commit/b3edb30fc2cb0e2e5037c8776d6c1c6d41f05052))
* **ram:** add process management view and compact settings ([10cd015](https://github.com/oscarlehuu/macmonitor/commit/10cd01565f1e1706eb82d2565f092995a27f811a))
* ship menubar thermal monitor v1 with tests and CI ([7ddb0e4](https://github.com/oscarlehuu/macmonitor/commit/7ddb0e422f5b1d8a34254cd2b8cf4d05c2c00d64))
* **updates:** add Sparkle updater and automated releases ([07c89f5](https://github.com/oscarlehuu/macmonitor/commit/07c89f5986ef1ecd07841fa36387c4df34a00626))


### Bug Fixes

* address 4 bugs in battery control subsystem ([c94538e](https://github.com/oscarlehuu/macmonitor/commit/c94538ecc1060513c04b99146bc276a7a1838575))
* address 6 bugs in battery control subsystem ([e72e2eb](https://github.com/oscarlehuu/macmonitor/commit/e72e2eb7890e58b36c62a19bba2e3ea92de0783d))
* **ram:** match redesign mock and correct usage formula ([0d90899](https://github.com/oscarlehuu/macmonitor/commit/0d90899a50a7a67e1360e51fe296104f6fd5c7db))
* remove fabricated storage breakdown and use per-trigger-kind cooldown tracking ([e80ce25](https://github.com/oscarlehuu/macmonitor/commit/e80ce254f2f6e8e1b6d929afaa4d5ca229c03201))
* **ui:** replace settings modal with in-popover screen ([8a05606](https://github.com/oscarlehuu/macmonitor/commit/8a056068ab0ebcdd438c779010ba9ab1ac273db7))
