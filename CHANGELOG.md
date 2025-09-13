# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2024-09-13

### Added

- **New `scan` command**: Source code analysis for untranslated translation keys
  - `gleam run -m g18n/dev scan` - Scan current project source directory for missing translation keys
  - `gleam run -m g18n/dev scan --dir <path>` - Scan specific directory for untranslated keys
  - **AST-based key detection**: Uses Glance v5.0.1 for accurate parsing of Gleam source code
  - **Comprehensive function support**: Detects keys from all g18n translation functions (`translate`, `translate_with_params`, `translate_with_context`, `translate_plural`, etc.)
  - **Recursive directory scanning**: Automatically scans all `.gleam` files in subdirectories
  - **CI/CD compatible**: Exits with code 0 on success, code 1 when untranslated keys found
  - **Detailed reporting**: Shows missing keys with exact file locations for easy debugging
  - **Smart file filtering**: Skips build directories (`build/`, `target/`, `.git/`, `node_modules/`)

- **New `sync` command**: Synchronize missing keys between locales
  - `gleam run -m g18n/dev sync --from <locale> --to <locales>` - Sync missing keys from source locale to target locales
  - **Multi-target support**: Sync to multiple target locales at once (comma-separated)
  - **Missing key detection**: Identifies keys present in source locale but missing in targets
  - **Batch operations**: Efficiently handles large translation sets

- **New `stats` command**: Comprehensive translation statistics and analytics
  - `gleam run -m g18n/dev stats` - Show overall project translation statistics
  - `gleam run -m g18n/dev stats --locale <locale>` - Show statistics for specific locale
  - **Coverage analysis**: Displays translation coverage percentages for each locale
  - **Namespace breakdown**: Shows key distribution across different namespaces
  - **Visual indicators**: Color-coded status indicators (✅ complete, 🟡 partial, ❌ incomplete)

- **New `lint` command**: Code quality checks for translation files
  - `gleam run -m g18n/dev lint` - Check translations for common issues with default rules
  - `gleam run -m g18n/dev lint --rules <rules>` - Use specific lint rules (comma-separated)
  - **Built-in rules**: Detects empty translations, overly long translations, duplicate content
  - **Customizable**: Configure which rules to apply for different project needs

- **New `diff` command**: Compare translations between locales
  - `gleam run -m g18n/dev diff <locale1> <locale2>` - Compare two locales side by side
  - **Missing key detection**: Shows keys present in one locale but missing in another
  - **Extra key detection**: Identifies keys that exist only in target locale
  - **Common key summary**: Displays count of shared translation keys

### Technical Enhancements

- **Dependency**: Added Glance v5.0.1 for robust Gleam AST parsing in scan functionality
- **Enhanced g18n integration**: Leverages core g18n functions like `get_translation_stats()`, `lint_translations()`, `diff_translations()`, `get_missing_keys()`
- **Improved error handling**: Better validation and user feedback across all commands
- **Performance optimizations**: Efficient handling of large translation sets and deep directory structures

## [1.2.0] - 2024-12-01

### Added

- **New `keys` command**: Comprehensive key management utilities
  - `gleam run -m g18n/dev keys --list` - List all translation keys  
  - `gleam run -m g18n/dev keys --prefix <prefix>` - Find keys with specific prefix
  - `gleam run -m g18n/dev keys --unused <file>` - Find unused translation keys
- **New `convert` command**: Convert between translation formats
  - `gleam run -m g18n/dev convert --to flat` - Convert to flat JSON format
  - `gleam run -m g18n/dev convert --to nested` - Convert to nested JSON format  
  - `gleam run -m g18n/dev convert --to po` - Convert to PO file format
- **New `params` command**: Parameter analysis and validation
  - `gleam run -m g18n/dev params --check` - Check for parameter issues across locales
  - `gleam run -m g18n/dev params --extract <key>` - Extract parameters from specific key
- **New `check` command**: CI/CD-ready validation with proper exit codes
  - `gleam run -m g18n/dev check` - Validate translations and exit with status code
  - `gleam run -m g18n/dev check --primary <locale>` - Validate with specific primary locale
  - Exits with code 0 for success, 1 for validation errors
- **Cross-platform FFI exit handling**: Proper process exit codes for automation
  - JavaScript support (Node.js, Deno)
  - Erlang support using `halt/1`
  - Perfect for CI/CD pipelines, pre-commit hooks, and build automation

### Enhanced

- **All commands now support automatic format detection**: Works seamlessly with flat JSON, nested JSON, and PO files
- **Comprehensive validation**: Detects missing keys, parameter issues, empty translations, and plural form problems
- **Built-in g18n integration**: Uses core g18n functions like `get_keys_with_prefix()`, `find_unused_translations()`, `extract_placeholders()`

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

