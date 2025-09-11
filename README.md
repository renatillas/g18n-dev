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

## Development

```sh
gleam run -m g18n/dev help   # Show help
gleam test                   # Run the tests
gleam format                 # Format the code
```

## Documentation

Further documentation can be found at <https://hexdocs.pm/g18n_dev>.
