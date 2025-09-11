# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-01

### Added

- Initial release of g18n-dev CLI tool
- Support for generating Gleam translation modules from flat JSON files
- Support for generating Gleam translation modules from nested JSON files
- Support for generating Gleam translation modules from PO (gettext) files
- Automatic code formatting after module generation
- Comprehensive help system with usage examples
- Support for locale codes in 2 or 5 character format (e.g., `en`, `en-US`)
- Generated modules include translator, translations, and locale functions
- Compatible with popular i18n formats (react-i18next, Vue i18n, Angular i18n)
- CLI commands: `generate`, `generate --nested`, `generate --po`, `help`

[1.0.0]: https://github.com/renatillas/g18n-dev/releases/tag/v1.0.0

