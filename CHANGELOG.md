# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-12-01

### Added

- **New `report` command**: Generate comprehensive translation coverage reports
  - `gleam run -m g18n/dev report` - Show translation coverage report
  - `gleam run -m g18n/dev report --primary <locale>` - Set primary locale for comparison
- **Automatic format detection**: Report command automatically detects and handles flat JSON, nested JSON, and PO file formats
- **Detailed coverage analysis**: Shows coverage percentages, missing translation keys, and validation errors for each locale
- **Built-in validation**: Uses g18n's `validate_translations()` and `export_validation_report()` functions for accurate reporting

### Fixed

- Improved error handling for invalid locale codes and missing translation files
- Better user feedback when no translation files are found

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

