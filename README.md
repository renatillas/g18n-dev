# g18n-dev

[![Package Version](https://img.shields.io/hexpm/v/g18n_dev)](https://hex.pm/packages/g18n_dev)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/g18n_dev/)

Development tools and CLI for the [g18n](https://github.com/renatillas/g18n) internationalization library for Gleam.

## Installation

```sh
gleam add g18n_dev@1
```

## Usage

The CLI provides commands to generate Gleam translation modules from various file formats:

### Generate from Flat JSON Files

```sh
gleam run -m g18n/dev generate
```

Place flat JSON files in `src/<project>/translations/` directory:

```json
{
  "ui.button.save": "Save",
  "ui.button.cancel": "Cancel", 
  "user.name": "Name",
  "user.email": "Email"
}
```

### Generate from Nested JSON Files

```sh
gleam run -m g18n/dev generate --nested
```

Place nested JSON files in `src/<project>/translations/` directory:

```json
{
  "ui": {
    "button": {
      "save": "Save",
      "cancel": "Cancel"
    }
  },
  "user": {
    "name": "Name",
    "email": "Email"
  }
}
```

This format is compatible with popular i18n libraries like react-i18next, Vue i18n, and Angular i18n.

### Generate from PO Files (gettext)

```sh
gleam run -m g18n/dev generate --po
```

Place PO files in `src/<project>/translations/` directory:

```po
msgid "ui.button.save"
msgstr "Save"

msgid "user.name"
msgstr "Name"
```

### Translation Coverage Report

```sh
gleam run -m g18n/dev report
```

Generate a comprehensive translation coverage report that automatically detects your file format (flat JSON, nested JSON, or PO files) and shows:

- Coverage percentages for each locale
- Missing translation keys
- Validation errors and warnings
- Primary locale comparison

```sh
gleam run -m g18n/dev report --primary es
```

Use a specific locale as the primary reference for comparison.

### Key Management

```sh
# List all translation keys
gleam run -m g18n/dev keys --list

# Find keys with specific prefix
gleam run -m g18n/dev keys --prefix ui.button

# Find unused keys (requires file with used keys, one per line)
gleam run -m g18n/dev keys --unused used-keys.txt
```

### Format Conversion

```sh
# Convert translations between formats
gleam run -m g18n/dev convert --to flat    # Convert to flat JSON
gleam run -m g18n/dev convert --to nested  # Convert to nested JSON  
gleam run -m g18n/dev convert --to po      # Convert to PO files
```

### Parameter Analysis

```sh
# Check for parameter issues across all locales
gleam run -m g18n/dev params --check

# Extract parameters from a specific translation key
gleam run -m g18n/dev params --extract user.greeting
```

### CI/CD Validation

```sh
# Validate translations with proper exit codes (perfect for CI/CD)
gleam run -m g18n/dev check                 # Exit 0 = success, 1 = errors
gleam run -m g18n/dev check --primary en    # Use specific primary locale
```

The `check` command is designed for automation and will:
- Exit with code **0** if all translations are valid
- Exit with code **1** if validation errors are found
- Perfect for pre-commit hooks, GitHub Actions, and build pipelines

### Help

```sh
gleam run -m g18n/dev help
```

## File Naming Convention

Translation files should be named using locale codes:

- `en.json` / `en.po` (English)
- `es.json` / `es.po` (Spanish)
- `pt.json` / `pt.po` (Portuguese)
- `en-US.json` / `en-US.po` (English - US)
- `pt-BR.json` / `pt-BR.po` (Portuguese - Brazil)

Locale codes must be 2 or 5 characters long.

## Generated Output

The tool generates a `translations.gleam` module with functions for each locale:

```gleam
import my_project/translations

pub fn main() {
  let translator = translations.en_translator()
  let message = g18n.translate(translator, "ui.button.save")
  // Returns: "Save"
}
```

## Supported Formats

- ✅ Flat JSON (g18n optimized)
- ✅ Nested JSON (react-i18next, Vue i18n, Angular i18n compatible)  
- ✅ PO files (gettext standard)

## Automation & CI/CD Integration

### GitHub Actions

```yaml
name: Check Translations
on: [push, pull_request]

jobs:
  translations:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          otp-version: "26.0"
          gleam-version: "1.0.0"
      - run: gleam deps download
      - run: gleam run -m g18n/dev check --primary en
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
gleam run -m g18n/dev check --primary en
if [ $? -ne 0 ]; then
    echo "❌ Translation validation failed. Fix issues before committing."
    exit 1
fi
```

### Build Scripts

```bash
# In your build script
echo "Validating translations..."
gleam run -m g18n/dev check --primary en || exit 1
echo "✅ Translations valid!"
```

## Development

```sh
gleam run -m g18n/dev help   # Show help
gleam test                   # Run the tests
gleam format                 # Format the code
```

## Documentation

Further documentation can be found at <https://hexdocs.pm/g18n_dev>.
