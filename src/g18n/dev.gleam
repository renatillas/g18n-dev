import argv
import filepath
import g18n
import g18n/locale
import gleam/bool
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile
import snag.{type Result as SnagResult}
import tom
import trie

/// CLI entry point for g18n-dev tools
/// 
/// ## Commands
/// ```
/// gleam run generate          # Generate from flat JSON files  
/// gleam run generate --nested # Generate from nested JSON files
/// gleam run generate -- po    # Generate from PO files
/// gleam run report            # Show translation report
/// gleam run report --primary <locale> # Set primary locale for comparison
/// gleam run help              # Show help
/// gleam run                   # Show help (default)
/// ```
pub fn main() {
  case argv.load().arguments {
    ["generate"] -> generate_command()
    ["generate", "--nested"] -> generate_nested_command()
    ["generate", "--po"] -> generate_po_command()
    ["report"] -> report_command("")
    ["report", "--primary", locale] -> report_command(locale)
    ["keys", "--list"] -> keys_command("list", "")
    ["keys", "--prefix", prefix] -> keys_command("prefix", prefix)
    ["keys", "--unused", usage_file] -> keys_command("unused", usage_file)
    ["convert", "--to", format] -> convert_command(format)
    ["params", "--check"] -> params_command("check", "")
    ["params", "--extract", key] -> params_command("extract", key)
    ["check"] -> check_command("")
    ["check", "--primary", locale] -> check_command(locale)
    ["help"] -> help_command()
    [] -> help_command()
    _ -> {
      io.println("Unknown command. Use 'help' for available commands.")
    }
  }
}

fn generate_command() {
  case generate_translations() {
    Ok(path) -> {
      io.println("🌏Generated translation modules from flat JSON")
      io.println("  " <> path)
    }
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn generate_nested_command() {
  case generate_nested_translations() {
    Ok(path) -> {
      io.println("🌏Generated translation modules from nested JSON")
      io.println("  " <> path)
    }
    Error(msg) -> io.println(snag.pretty_print(msg))
  }
}

fn generate_po_command() {
  case generate_po_translations() {
    Ok(path) -> {
      io.println("🌏Generated translation modules from PO files")
      io.println("  " <> path)
    }
    Error(msg) -> io.println(snag.pretty_print(msg))
  }
}

fn report_command(primary_locale: String) {
  case generate_translation_report(primary_locale) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn keys_command(operation: String, arg: String) {
  case execute_keys_operation(operation, arg) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn convert_command(format: String) {
  case execute_convert_operation(format) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn params_command(operation: String, arg: String) {
  case execute_params_operation(operation, arg) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn check_command(primary_locale: String) {
  case execute_check_operation(primary_locale) {
    Ok(_) -> {
      // Exit with 0 to indicate success - only for check command
      exit(0)
    }
    Error(msg) -> {
      io.println_error(snag.pretty_print(msg))
      // Exit with 1 to indicate failure - only for check command
      exit(1)
    }
  }
}

fn help_command() {
  io.println("g18n CLI - Internationalization for Gleam")
  io.println("")
  io.println("Commands:")
  io.println("  generate           Generate Gleam module from flat JSON files")
  io.println(
    "  generate --nested  Generate Gleam module from nested JSON files (industry standard)",
  )
  io.println(
    "  generate --po      Generate Gleam module from PO files (gettext)",
  )
  io.println("  report             Show translation coverage report")
  io.println("  report --primary <locale> Set primary locale for comparison")
  io.println("  keys --list        List all translation keys")
  io.println("  keys --prefix <prefix> Find keys with specific prefix")
  io.println(
    "  keys --unused <file>   Find unused keys (provide file with used keys)",
  )
  io.println("  convert --to <format>  Convert translations (flat, nested, po)")
  io.println("  params --check     Check for parameter issues across locales")
  io.println("  params --extract <key> Extract parameters from specific key")
  io.println(
    "  check              Validate translations and exit with error if issues found",
  )
  io.println("  check --primary <locale> Validate with specific primary locale")
  io.println("  help               Show this help message")
  io.println("")
  io.println("Flat JSON usage:")
  io.println("  Place flat JSON files in src/<project>/translations/")
  io.println(
    "  Example: {\"ui.button.save\": \"Save\", \"user.name\": \"Name\"}",
  )
  io.println("  Run 'gleam run generate' to create the translations module")
  io.println("")
  io.println("Nested JSON usage:")
  io.println("  Place nested JSON files in src/<project>/translations/")
  io.println(
    "  Example: {\"ui\": {\"button\": {\"save\": \"Save\"}}, \"user\": {\"name\": \"Name\"}}",
  )
  io.println(
    "  Run 'gleam run generate_nested' to create the translations module",
  )
  io.println("")
  io.println("PO files usage:")
  io.println("  Place PO files in src/<project>/translations/")
  io.println("  Example: msgid \"ui.button.save\" / msgstr \"Save\"")
  io.println("  Run 'gleam run generate_po' to create the translations module")
  io.println("")
  io.println("Supported formats:")
  io.println("  ✅ Flat JSON (g18n optimized)")
  io.println(
    "  ✅ Nested JSON (react-i18next, Vue i18n, Angular i18n compatible)",
  )
  io.println("  ✅ PO files (gettext standard) - msgid/msgstr pairs")
  io.println("")
}

fn generate_translations() -> SnagResult(String) {
  use project_name <- result.try(get_project_name())
  use locale_files <- result.try(find_locale_files(project_name))
  use output_path <- result.try(write_module(project_name, locale_files))
  use _ <- result.try(format())
  Ok(output_path)
}

fn generate_nested_translations() -> SnagResult(String) {
  use project_name <- result.try(get_project_name())
  use locale_files <- result.try(find_locale_files(project_name))
  use output_path <- result.try(write_module_from_nested(
    project_name,
    locale_files,
  ))
  use _ <- result.try(format())
  Ok(output_path)
}

fn generate_po_translations() -> SnagResult(String) {
  use project_name <- result.try(get_project_name())
  use locale_files <- result.try(find_po_files(project_name))
  use output_path <- result.try(write_module_from_po(project_name, locale_files))
  use _ <- result.try(format())
  Ok(output_path)
}

fn generate_translation_report(primary_locale: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))

  // Determine primary locale
  let primary = case primary_locale {
    "" -> {
      case locale_data {
        [first, ..] -> first.0
        [] -> "en"
      }
    }
    locale -> locale
  }

  // Find primary locale data
  case list.find(locale_data, fn(pair) { pair.0 == primary }) {
    Ok(#(_, primary_translations)) -> {
      io.println("📊 Translation Validation Report")
      io.println("Primary locale: " <> primary)
      io.println("")

      // Generate reports for each locale compared to primary
      list.each(locale_data, fn(pair) {
        let #(locale_code, translations) = pair

        // Create locale for validation
        case locale.new(string.replace(locale_code, each: "_", with: "-")) {
          Ok(target_locale) -> {
            let report =
              g18n.validate_translations(
                primary_translations,
                translations,
                target_locale,
              )
            io.println("🌍 " <> locale_code <> ":")
            io.println(g18n.export_validation_report(report))
            io.println("")
          }
          Error(_) -> {
            io.println("❌ Invalid locale code: " <> locale_code)
            io.println("")
          }
        }
      })

      Ok(Nil)
    }
    Error(_) -> {
      io.println("❌ Primary locale '" <> primary <> "' not found!")
      io.println(
        "Available locales: "
        <> string.join(list.map(locale_data, fn(pair) { pair.0 }), ", "),
      )
      snag.error("Primary locale not found")
    }
  }
}

fn try_load_translations(
  project_name: String,
) -> SnagResult(List(#(String, g18n.Translations))) {
  // Try to find JSON files first
  case find_locale_files(project_name) {
    Ok(files) -> {
      // Try flat JSON first
      case load_all_locales(files) {
        Ok(data) -> {
          io.println("📁 Detected format: Flat JSON")
          Ok(data)
        }
        Error(_flat_error) -> {
          // Try nested JSON
          let nested_result = load_all_locales_from_nested(files)
          case nested_result {
            Ok(data) -> {
              io.println("📁 Detected format: Nested JSON")
              Ok(data)
            }
            Error(_nested_error) -> {
              // Both JSON formats failed, try PO files
              case find_po_files(project_name) {
                Ok(po_files) -> {
                  case load_all_locales_from_po(po_files) {
                    Ok(data) -> {
                      io.println("📁 Detected format: PO files")
                      Ok(data)
                    }
                    Error(po_error) -> Error(po_error)
                  }
                }
                Error(_) -> {
                  // No PO files found, return the nested JSON error as it's more likely to be helpful
                  nested_result
                }
              }
            }
          }
        }
      }
    }
    Error(_) -> {
      // No JSON files found, try PO files directly
      case find_po_files(project_name) {
        Ok(po_files) -> {
          case load_all_locales_from_po(po_files) {
            Ok(data) -> {
              io.println("📁 Detected format: PO files")
              Ok(data)
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) ->
          snag.error(
            "No translation files found in src/"
            <> project_name
            <> "/translations/",
          )
      }
    }
  }
}

fn execute_keys_operation(operation: String, arg: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))

  case operation {
    "list" -> {
      io.println("🔑 Translation Keys")
      io.println("=" |> string.repeat(50))
      io.println("")

      case locale_data {
        [] -> {
          io.println("No translations found.")
          Ok(Nil)
        }
        [#(_locale, translations), ..] -> {
          let keys = get_all_translation_keys(translations)
          list.each(keys, io.println)
          io.println("")
          io.println("Total keys: " <> string.inspect(list.length(keys)))
          Ok(Nil)
        }
      }
    }
    "prefix" -> {
      io.println("🔍 Keys with prefix: " <> arg)
      io.println("=" |> string.repeat(50))
      io.println("")

      case locale_data {
        [] -> {
          io.println("No translations found.")
          Ok(Nil)
        }
        [#(_locale, translations), ..] -> {
          let keys = g18n.get_keys_with_prefix(translations, arg)
          list.each(keys, io.println)
          io.println("")
          io.println("Found " <> string.inspect(list.length(keys)) <> " keys")
          Ok(Nil)
        }
      }
    }
    "unused" -> {
      case simplifile.read(arg) {
        Ok(content) -> {
          // Simple implementation: split by lines and filter non-empty
          let used_keys =
            content
            |> string.split("\n")
            |> list.map(string.trim)
            |> list.filter(fn(line) { line != "" })

          io.println("🚫 Unused Translation Keys")
          io.println("=" |> string.repeat(50))
          io.println("")

          case locale_data {
            [] -> {
              io.println("No translations found.")
              Ok(Nil)
            }
            [#(_locale, translations), ..] -> {
              let unused_keys =
                g18n.find_unused_translations(translations, used_keys)
              case unused_keys {
                [] -> {
                  io.println("✅ All translation keys are being used!")
                  Ok(Nil)
                }
                _ -> {
                  list.each(unused_keys, io.println)
                  io.println("")
                  io.println(
                    "Found "
                    <> string.inspect(list.length(unused_keys))
                    <> " unused keys",
                  )
                  Ok(Nil)
                }
              }
            }
          }
        }
        Error(_) -> snag.error("Could not read usage file: " <> arg)
      }
    }
    _ -> snag.error("Unknown keys operation: " <> operation)
  }
}

fn execute_convert_operation(format: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))

  io.println("🔄 Converting translations to: " <> format)
  io.println("")

  case format {
    "flat" | "nested" | "po" -> {
      list.each(locale_data, fn(pair) {
        let #(locale_code, translations) = pair
        let file_extension = case format {
          "po" -> ".po"
          _ -> ".json"
        }
        let output_file = locale_code <> "_converted" <> file_extension

        let content = case format {
          "flat" -> g18n.translations_to_json(translations)
          "nested" -> g18n.translations_to_nested_json(translations)
          "po" -> g18n.translations_to_po(translations)
          _ -> ""
        }

        case simplifile.write(output_file, content) {
          Ok(_) -> io.println("✅ " <> locale_code <> " → " <> output_file)
          Error(_) -> io.println("❌ Failed to write " <> output_file)
        }
      })
      Ok(Nil)
    }
    _ ->
      snag.error("Unknown format: " <> format <> ". Use: flat, nested, or po")
  }
}

fn execute_params_operation(operation: String, arg: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))

  case operation {
    "check" -> {
      io.println("🔧 Parameter Validation")
      io.println("=" |> string.repeat(50))
      io.println("")

      // Use first locale as primary for parameter checking
      case locale_data {
        [] -> {
          io.println("No translations found.")
          Ok(Nil)
        }
        [primary_pair, ..rest] -> {
          let #(_primary_locale, primary_translations) = primary_pair

          list.each(rest, fn(pair) {
            let #(target_locale_code, target_translations) = pair
            case
              locale.new(string.replace(
                target_locale_code,
                each: "_",
                with: "-",
              ))
            {
              Ok(target_locale) -> {
                let report =
                  g18n.validate_translations(
                    primary_translations,
                    target_translations,
                    target_locale,
                  )
                let param_errors =
                  list.filter(report.errors, fn(error) {
                    case error {
                      g18n.MissingParameter(_, _, _) -> True
                      g18n.UnusedParameter(_, _, _) -> True
                      _ -> False
                    }
                  })

                case param_errors {
                  [] ->
                    io.println(
                      "✅ " <> target_locale_code <> ": No parameter issues",
                    )
                  _ -> {
                    io.println(
                      "❌ "
                      <> target_locale_code
                      <> ": "
                      <> string.inspect(list.length(param_errors))
                      <> " parameter issues",
                    )
                  }
                }
              }
              Error(_) ->
                io.println("❌ Invalid locale code: " <> target_locale_code)
            }
          })
          Ok(Nil)
        }
      }
    }
    "extract" -> {
      io.println("📝 Parameters in key: " <> arg)
      io.println("=" |> string.repeat(50))
      io.println("")

      case locale_data {
        [] -> {
          io.println("No translations found.")
          Ok(Nil)
        }
        [#(_locale, translations), ..] -> {
          let key_parts = string.split(arg, ".")
          case trie.get(g18n.extract_trie(translations), key_parts) {
            Ok(template) -> {
              let params = g18n.extract_placeholders(template)
              case params {
                [] -> io.println("No parameters found in this template")
                _ -> {
                  io.println("Template: " <> template)
                  io.println("Parameters:")
                  list.each(params, fn(param) {
                    io.println("  - {" <> param <> "}")
                  })
                }
              }
              Ok(Nil)
            }
            Error(_) -> {
              io.println("Key '" <> arg <> "' not found in translations")
              Ok(Nil)
            }
          }
        }
      }
    }
    _ -> snag.error("Unknown params operation: " <> operation)
  }
}

fn execute_check_operation(primary_locale: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))

  // Determine primary locale
  let primary = case primary_locale {
    "" -> {
      case locale_data {
        [first, ..] -> first.0
        [] -> "en"
      }
    }
    locale -> locale
  }

  // Find primary locale data
  case list.find(locale_data, fn(pair) { pair.0 == primary }) {
    Ok(#(_, primary_translations)) -> {
      let has_errors =
        list.fold(locale_data, False, fn(has_error_acc, pair) {
          let #(locale_code, translations) = pair

          case locale.new(string.replace(locale_code, each: "_", with: "-")) {
            Ok(target_locale) -> {
              let report =
                g18n.validate_translations(
                  primary_translations,
                  translations,
                  target_locale,
                )
              case report.errors {
                [] -> has_error_acc
                errors -> {
                  io.println(
                    "❌ "
                    <> locale_code
                    <> " has "
                    <> string.inspect(list.length(errors))
                    <> " issues:",
                  )
                  list.each(errors, fn(error) {
                    case error {
                      g18n.MissingTranslation(key, _) ->
                        io.println("  Missing key: " <> key)
                      g18n.MissingParameter(key, param, _) ->
                        io.println(
                          "  Missing parameter '"
                          <> param
                          <> "' in key: "
                          <> key,
                        )
                      g18n.UnusedParameter(key, param, _) ->
                        io.println(
                          "  Unused parameter '" <> param <> "' in key: " <> key,
                        )
                      g18n.EmptyTranslation(key, _) ->
                        io.println("  Empty translation for key: " <> key)
                      g18n.InvalidPluralForm(key, missing_forms, _) ->
                        io.println(
                          "  Invalid plural form for key '"
                          <> key
                          <> "', missing: "
                          <> string.join(missing_forms, ", "),
                        )
                    }
                  })
                  io.println("")
                  True
                }
              }
            }
            Error(_) -> {
              io.println("❌ Invalid locale code: " <> locale_code)
              True
            }
          }
        })

      case has_errors {
        True ->
          snag.error("Translation validation failed - fix the issues above")
        False -> {
          io.println("✅ All translations are valid!")
          Ok(Nil)
        }
      }
    }
    Error(_) -> {
      io.println("❌ Primary locale '" <> primary <> "' not found!")
      io.println(
        "Available locales: "
        <> string.join(list.map(locale_data, fn(pair) { pair.0 }), ", "),
      )
      snag.error("Primary locale not found")
    }
  }
}

fn get_all_translation_keys(translations: g18n.Translations) -> List(String) {
  trie.fold(translations |> g18n.extract_trie, [], fn(acc, key_parts, _value) {
    let key = string.join(key_parts, ".")
    [key, ..acc]
  })
  |> list.reverse
}

fn format() {
  shellout.command("gleam", ["format"], in: find_root("."), opt: [])
  |> snag.map_error(fn(_) { "Could not format generated file" })
}

fn get_project_name() -> SnagResult(String) {
  let root = find_root(".")
  let toml_path = filepath.join(root, "gleam.toml")

  use content <- result.try(
    simplifile.read(toml_path)
    |> snag.map_error(fn(_) { "Could not read gleam.toml" }),
  )

  use toml <- result.try(
    tom.parse(content)
    |> snag.map_error(fn(_) { "Could not parse gleam.toml" }),
  )

  use name <- result.try(
    tom.get_string(toml, ["name"])
    |> snag.map_error(fn(_) { "Could not find project name in gleam.toml" }),
  )

  Ok(name)
}

fn escape_string(str: String) -> String {
  str
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join(path, ".."))
    Ok(True) -> path
  }
}

fn find_locale_files(
  project_name: String,
) -> SnagResult(List(#(String, String))) {
  let root = find_root(".")
  let translations_dir =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations")

  case simplifile.read_directory(translations_dir) {
    Ok(files) -> {
      let locale_files =
        files
        |> list.filter(fn(file) {
          string.ends_with(file, ".json") && file != "translations.json"
        })
        |> list.try_map(fn(file) {
          let locale_code = string.drop_end(file, 5)
          let file_path = filepath.join(translations_dir, file)
          let locale_code = string.replace(locale_code, each: "-", with: "_")
          use <- bool.guard(
            string.length(locale_code) != 2 && string.length(locale_code) != 5,
            snag.error(
              "Locale code must be 2 or 5 characters (e.g., 'en' or 'en-US'): "
              <> locale_code,
            ),
          )
          Ok(#(locale_code, file_path))
        })
        |> snag.context("Error processing locale files")

      case locale_files {
        Ok([]) ->
          snag.error(
            "No locale JSON files found in "
            <> translations_dir
            <> "\nLooking for files like en.json, es.json, pt.json, etc.",
          )
        Ok(files) -> Ok(files)
        Error(msg) -> Error(msg)
      }
    }
    Error(_) ->
      snag.error("Could not read translations directory: " <> translations_dir)
  }
}

fn find_po_files(project_name: String) -> SnagResult(List(#(String, String))) {
  let root = find_root(".")
  let translations_dir =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations")

  case simplifile.read_directory(translations_dir) {
    Ok(files) -> {
      let locale_files =
        files
        |> list.filter(fn(file) { string.ends_with(file, ".po") })
        |> list.try_map(fn(file) {
          let locale_code = string.drop_end(file, 3)
          let file_path = filepath.join(translations_dir, file)
          let locale_code = string.replace(locale_code, each: "-", with: "_")
          use <- bool.guard(
            string.length(locale_code) != 2 && string.length(locale_code) != 5,
            snag.error(
              "Locale code must be 2 or 5 characters (e.g., 'en' or 'en-US'): "
              <> locale_code,
            ),
          )
          Ok(#(locale_code, file_path))
        })
        |> snag.context("Error processing PO files")

      case locale_files {
        Ok([]) ->
          snag.error(
            "No PO files found in "
            <> translations_dir
            <> "\nLooking for files like en.po, es.po, pt.po, etc.",
          )
        Ok(files) -> Ok(files)
        Error(msg) -> Error(msg)
      }
    }
    Error(_) ->
      snag.error("Could not read translations directory: " <> translations_dir)
  }
}

fn write_module(
  project_name: String,
  locale_files: List(#(String, String)),
) -> SnagResult(String) {
  use locale_data <- result.try(load_all_locales(locale_files))
  let root = find_root(".")
  let output_path =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations.gleam")

  let module_content = generate_module_content(locale_data)

  simplifile.write(output_path, module_content)
  |> snag.map_error(fn(_) {
    "Could not write translations module at: " <> output_path
  })
  |> result.map(fn(_) { output_path })
}

fn write_module_from_nested(
  project_name: String,
  locale_files: List(#(String, String)),
) -> SnagResult(String) {
  use locale_data <- result.try(load_all_locales_from_nested(locale_files))
  let root = find_root(".")
  let output_path =
    filepath.join(root, "src")
    |> filepath.join(project_name)
    |> filepath.join("translations.gleam")

  let module_content = generate_module_content(locale_data)

  simplifile.write(output_path, module_content)
  |> snag.map_error(fn(_) {
    "Could not write translations module from nested JSON at: " <> output_path
  })
  |> result.map(fn(_) { output_path })
}

fn load_all_locales(
  locale_files: List(#(String, String)),
) -> SnagResult(List(#(String, g18n.Translations))) {
  list.try_fold(locale_files, [], fn(acc, locale_file) {
    let #(locale_code, file_path) = locale_file
    use content <- result.try(
      simplifile.read(file_path)
      |> snag.map_error(fn(_) { "Could not read " <> file_path }),
    )
    use translations <- result.try(
      g18n.translations_from_json(content)
      |> snag.map_error(fn(_) { "Could not parse JSON in " <> file_path }),
    )
    Ok([#(locale_code, translations), ..acc])
  })
  |> result.map(list.reverse)
}

fn load_all_locales_from_nested(
  locale_files: List(#(String, String)),
) -> SnagResult(List(#(String, g18n.Translations))) {
  list.try_fold(locale_files, [], fn(acc, locale_file) {
    let #(locale_code, file_path) = locale_file
    use content <- result.try(
      simplifile.read(file_path)
      |> snag.map_error(fn(_) { "Could not read " <> file_path }),
    )
    use translations <- result.try(
      g18n.translations_from_nested_json(content)
      |> snag.map_error(fn(e) {
        "Could not parse nested JSON in " <> file_path <> ": " <> e
      }),
    )
    Ok([#(locale_code, translations), ..acc])
  })
  |> result.map(list.reverse)
  |> snag.context("Error loading nested JSON locale files")
}

fn load_all_locales_from_po(
  locale_files: List(#(String, String)),
) -> SnagResult(List(#(String, g18n.Translations))) {
  list.try_fold(locale_files, [], fn(acc, locale_file) {
    let #(locale_code, file_path) = locale_file
    use content <- result.try(
      simplifile.read(file_path)
      |> snag.map_error(fn(_) { "Could not read " <> file_path }),
    )
    use translations <- result.try(
      g18n.translations_from_po(content)
      |> snag.map_error(fn(e) {
        "Could not parse PO file in " <> file_path <> ": " <> e
      }),
    )
    Ok([#(locale_code, translations), ..acc])
  })
  |> result.map(list.reverse)
  |> snag.context("Error loading PO locale files")
}

fn write_module_from_po(
  project_name: String,
  locale_files: List(#(String, String)),
) -> SnagResult(String) {
  use locale_data <- result.try(load_all_locales_from_po(locale_files))
  let output_path =
    filepath.join("src", project_name)
    |> filepath.join("translations.gleam")

  let module_content = generate_module_content(locale_data)

  simplifile.write(output_path, module_content)
  |> snag.map_error(fn(_) {
    "Could not write translations module from PO files at: " <> output_path
  })
  |> result.map(fn(_) { output_path })
}

fn generate_module_content(
  locale_data: List(#(String, g18n.Translations)),
) -> String {
  let imports = "import g18n\nimport g18n/locale\n\n"

  let locale_functions =
    locale_data
    |> list.map(fn(locale_pair) {
      let #(locale_code, translations) = locale_pair
      generate_single_locale_functions(locale_code, translations)
    })
    |> string.join("\n\n")

  let all_locales_function = generate_all_locales_function(locale_data)

  imports <> locale_functions <> "\n\n" <> all_locales_function
}

fn generate_single_locale_functions(
  locale_code: String,
  translations: g18n.Translations,
) -> String {
  // Convert trie to dict for generation
  let dict_translations =
    trie.fold(
      translations |> g18n.extract_trie,
      dict.new(),
      fn(dict_acc, key_parts, value) {
        let key = string.join(key_parts, ".")
        dict.insert(dict_acc, key, value)
      },
    )

  let translations_list =
    dict_translations
    |> dict.to_list
    |> list.map(fn(pair) {
      "  |> g18n.add_translation(\""
      <> pair.0
      <> "\", \""
      <> escape_string(pair.1)
      <> "\")"
    })
    |> string.join("\n")

  let translations_func =
    "pub fn "
    <> locale_code
    <> "_translations() -> g18n.Translations {\n  g18n.new_translations()\n"
    <> translations_list
    <> "\n}"

  let locale_func =
    "pub fn "
    <> locale_code
    <> "_locale() -> locale.Locale {\n  let assert Ok(locale) = locale.new(\""
    <> string.replace(locale_code, each: "_", with: "-")
    <> "\")"
    <> "\nlocale"
    <> "\n}"

  let translator_func =
    "pub fn "
    <> locale_code
    <> "_translator() -> g18n.Translator {\n  "
    <> "g18n.new_translator("
    <> locale_code
    <> "_locale(), "
    <> locale_code
    <> "_translations())\n\n}"

  translations_func <> "\n\n" <> locale_func <> "\n\n" <> translator_func
}

fn generate_all_locales_function(
  locale_data: List(#(String, g18n.Translations)),
) -> String {
  let locale_list =
    locale_data
    |> list.map(fn(pair) { "\"" <> pair.0 <> "\"" })
    |> string.join(", ")

  "pub fn available_locales() -> List(String) {\n  [" <> locale_list <> "]\n}"
}

@external(erlang, "g18n_dev_ffi", "exit")
@external(javascript, "g18n_dev_ffi.mjs", "exit")
fn exit(code: Int) -> Nil
