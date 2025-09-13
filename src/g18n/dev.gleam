import argv
import filepath
import g18n
import g18n/locale
import glance
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
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
    ["sync", "--from", from_locale, "--to", to_locales] -> sync_command(from_locale, to_locales)
    ["stats"] -> stats_command("")
    ["stats", "--locale", locale] -> stats_command(locale)
    ["lint"] -> lint_command([])
    ["lint", "--rules", rules] -> lint_command(string.split(rules, ","))
    ["diff", from_locale, to_locale] -> diff_command(from_locale, to_locale)
    ["scan"] -> scan_command("")
    ["scan", "--dir", directory] -> scan_command(directory)
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

fn sync_command(from_locale: String, to_locales: String) {
  case execute_sync_operation(from_locale, to_locales) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn stats_command(locale: String) {
  case execute_stats_operation(locale) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn lint_command(rules: List(String)) {
  case execute_lint_operation(rules) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn diff_command(from_locale: String, to_locale: String) {
  case execute_diff_operation(from_locale, to_locale) {
    Ok(_) -> Nil
    Error(msg) -> io.println_error(snag.pretty_print(msg))
  }
}

fn scan_command(directory: String) {
  case execute_scan_operation(directory) {
    Ok(_) -> {
      // Exit with 0 to indicate success - only for scan command
      exit(0)
    }
    Error(msg) -> {
      io.println_error(snag.pretty_print(msg))
      // Exit with 1 to indicate failure - only for scan command
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
  io.println("  sync --from <locale> --to <locales> Sync missing keys between locales")
  io.println("  stats              Show project translation statistics")
  io.println("  stats --locale <locale> Show statistics for specific locale")
  io.println("  lint               Check translations for common issues")
  io.println("  lint --rules <rules>   Use specific lint rules (comma-separated)")
  io.println("  diff <locale1> <locale2> Compare two locales side by side")
  io.println("  scan               Detect untranslated keys used in source code")
  io.println("  scan --dir <path>  Scan specific directory for untranslated keys")
  io.println("                     (exits with error code 1 if untranslated keys found)")
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
          let keys = trie.fold(translations |> g18n.extract_trie, [], fn(acc, key_parts, _value) {
            let key = string.join(key_parts, ".")
            [key, ..acc]
          })
          |> list.reverse
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

fn execute_sync_operation(from_locale: String, to_locales: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))
  
  // Parse target locales
  let target_locales = string.split(to_locales, ",") |> list.map(string.trim)
  
  io.println("🔄 Syncing missing keys from " <> from_locale)
  io.println("Target locales: " <> string.join(target_locales, ", "))
  io.println("")
  
  // Check if source locale exists
  case list.find(locale_data, fn(pair) { pair.0 == from_locale }) {
    Ok(_) -> {
      list.each(target_locales, fn(target_locale) {
        case list.find(locale_data, fn(pair) { pair.0 == target_locale }) {
          Ok(#(_, target_translations)) -> {
            let #(_, source_translations) = case list.find(locale_data, fn(pair) { pair.0 == from_locale }) {
              Ok(found) -> found
              Error(_) -> #("", g18n.new_translations())
            }
            let missing_keys = g18n.get_missing_keys(source_translations, target_translations)
            
            case missing_keys {
              [] -> {
                io.println("✅ " <> target_locale <> ": No missing keys")
              }
              _ -> {
                io.println("📝 " <> target_locale <> ": Adding " <> int.to_string(list.length(missing_keys)) <> " missing keys")
                list.each(missing_keys, fn(key) {
                  io.println("  + " <> key)
                })
                
                // In a real implementation, we would write the updated files here
                io.println("  (Note: Actual file writing not implemented in this demo)")
              }
            }
          }
          Error(_) -> {
            io.println("❌ Target locale '" <> target_locale <> "' not found")
          }
        }
      })
      
      Ok(Nil)
    }
    Error(_) -> {
      snag.error("Source locale '" <> from_locale <> "' not found")
    }
  }
}

fn execute_stats_operation(locale: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))
  
  case locale {
    "" -> {
      // Overall project statistics using g18n core function
      case locale_data {
        [] -> {
          io.println("No translations found.")
          Ok(Nil)
        }
        [first, ..] -> {
          let #(primary_locale, _) = first
          
          case g18n.get_translation_stats(locale_data, primary_locale) {
            Ok(stats) -> {
              io.println("📊 Project Translation Statistics")
              io.println("=" |> string.repeat(50))
              io.println("")
              io.println("🌍 Total locales: " <> int.to_string(stats.total_locales))
              io.println("🔑 Total keys: " <> int.to_string(stats.total_keys))
              // Calculate average coverage
              let avg_coverage = case list.length(stats.locale_stats) {
                0 -> 0.0
                count -> list.fold(stats.locale_stats, 0.0, fn(acc, ls) { acc +. ls.coverage }) /. int.to_float(count)
              }
              io.println("📊 Average coverage: " <> float.to_string(avg_coverage) <> "%")
              io.println("")
              
              io.println("Locale Coverage:")
              list.each(stats.locale_stats, fn(locale_stat) {
                let status_icon = case locale_stat.coverage >=. 100.0, locale_stat.coverage >=. 80.0 {
                  True, _ -> "✅"
                  False, True -> "🟡"
                  False, False -> "❌"
                }
                io.println("  " <> status_icon <> " " <> locale_stat.locale <> ": " <> int.to_string(locale_stat.translated_keys) <> "/" <> int.to_string(stats.total_keys) <> " (" <> float.to_string(locale_stat.coverage) <> "%)")
              })
              
              Ok(Nil)
            }
            Error(msg) -> snag.error(msg)
          }
        }
      }
    }
    specific_locale -> {
      // Statistics for specific locale using g18n core function
      case list.find(locale_data, fn(pair) { pair.0 == specific_locale }) {
        Ok(_) -> {
          case g18n.get_translation_stats(locale_data, specific_locale) {
            Ok(stats) -> {
              io.println("📊 Statistics for locale: " <> specific_locale)
              io.println("=" |> string.repeat(50))
              io.println("")
              io.println("🔑 Total keys: " <> int.to_string(stats.total_keys))
              
              case list.find(stats.locale_stats, fn(s) { s.locale == specific_locale }) {
                Ok(locale_stat) -> {
                  io.println("📂 Keys by namespace:")
                  locale_stat.namespace_counts
                  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
                  |> list.each(fn(pair) {
                    io.println("  " <> pair.0 <> ": " <> int.to_string(pair.1) <> " keys")
                  })
                }
                Error(_) -> Nil
              }
              
              Ok(Nil)
            }
            Error(msg) -> snag.error(msg)
          }
        }
        Error(_) -> {
          snag.error("Locale '" <> specific_locale <> "' not found")
        }
      }
    }
  }
}

fn execute_lint_operation(rules: List(String)) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))
  
  let active_rules = case rules {
    [] -> ["empty", "long"]
    _ -> rules
  }
  
  io.println("🔍 Linting translations")
  io.println("Active rules: " <> string.join(active_rules, ", "))
  io.println("=" |> string.repeat(50))
  io.println("")
  
  let lint_results = g18n.lint_translations(locale_data, active_rules)
  
  case lint_results.locale_issues {
    [] -> {
      io.println("✅ No linting issues found!")
      Ok(Nil)
    }
    locale_issues -> {
      list.each(locale_issues, fn(locale_issue) {
        io.println("❌ " <> locale_issue.locale <> " (" <> int.to_string(list.length(locale_issue.issues)) <> " issues):")
        list.each(locale_issue.issues, fn(issue) {
          case issue {
            g18n.EmptyTranslationLint(key) -> io.println("  Empty translation: " <> key)
            g18n.LongTranslation(key, length) -> io.println("  Long translation (" <> int.to_string(length) <> " chars): " <> key)
            g18n.DuplicateTranslation(key, duplicate_of) -> io.println("  Duplicate translation: " <> key <> " (duplicate of " <> duplicate_of <> ")")
          }
        })
        io.println("")
      })
      Ok(Nil)
    }
  }
}

fn execute_diff_operation(from_locale: String, to_locale: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))
  
  io.println("🔍 Comparing " <> from_locale <> " → " <> to_locale)
  io.println("=" |> string.repeat(50))
  io.println("")
  
  case list.find(locale_data, fn(pair) { pair.0 == from_locale }),
       list.find(locale_data, fn(pair) { pair.0 == to_locale }) {
    Ok(#(_, from_translations)), Ok(#(_, to_translations)) -> {
      let diff = g18n.diff_translations(from_translations, to_translations, from_locale, to_locale)
      
      case diff.missing_in_target {
        [] -> io.println("✅ No missing keys in " <> to_locale)
        missing -> {
          io.println("❌ Missing in " <> to_locale <> " (" <> int.to_string(list.length(missing)) <> " keys):")
          list.each(missing, fn(key) {
            io.println("  - " <> key)
          })
          io.println("")
        }
      }
      
      case diff.extra_in_target {
        [] -> io.println("✅ No extra keys in " <> to_locale)
        extra -> {
          io.println("ℹ️ Extra in " <> to_locale <> " (" <> int.to_string(list.length(extra)) <> " keys):")
          list.each(extra, fn(key) {
            io.println("  + " <> key)
          })
          io.println("")
        }
      }
      
      io.println("✅ Common keys: " <> int.to_string(list.length(diff.common_keys)))
      
      Ok(Nil)
    }
    Error(_), _ -> snag.error("Source locale '" <> from_locale <> "' not found")
    _, Error(_) -> snag.error("Target locale '" <> to_locale <> "' not found")
  }
}

fn execute_scan_operation(directory: String) -> SnagResult(Nil) {
  use project_name <- result.try(get_project_name())
  use locale_data <- result.try(try_load_translations(project_name))
  
  let scan_dir = case directory {
    "" -> filepath.join(find_root("."), "src")
    _ -> directory
  }
  
  io.println("🔍 Scanning for untranslated keys in source code")
  io.println("Directory: " <> scan_dir)
  io.println("=" |> string.repeat(50))
  io.println("")
  
  // Get all existing translation keys from all locales
  case locale_data {
    [] -> {
      io.println("❌ No translation files found.")
      Ok(Nil)
    }
    _ -> {
      let all_translation_keys = get_all_translation_keys(locale_data)
      io.println("📚 Found " <> int.to_string(list.length(all_translation_keys)) <> " translation keys")
      
      // Scan source files for translation key usage
      use source_files <- result.try(find_gleam_files(scan_dir))
      use used_keys_with_files <- result.try(extract_translation_keys_from_files(source_files))
      
      let unique_keys = list.map(used_keys_with_files, fn(pair) { pair.0 }) |> list.unique
      
      io.println("📁 Scanned " <> int.to_string(list.length(source_files)) <> " source files")
      io.println("🔑 Found " <> int.to_string(list.length(unique_keys)) <> " translation keys in source code")
      io.println("")
      
      // Find keys used in source code that don't exist in translations
      let missing_keys_with_files = list.filter(used_keys_with_files, fn(pair) {
        let key = pair.0
        !list.contains(all_translation_keys, key)
      })
      
      case missing_keys_with_files {
        [] -> {
          io.println("✅ All translation keys found in source code exist in translation files!")
          Ok(Nil)
        }
        _ -> {
          io.println("❌ Found " <> int.to_string(list.length(missing_keys_with_files)) <> " untranslated keys:")
          io.println("")
          list.each(missing_keys_with_files, fn(pair) {
            let #(key, file_path) = pair
            // Make file path relative for cleaner output
            let clean_path = case string.starts_with(file_path, scan_dir) {
              True -> string.drop_start(file_path, string.length(scan_dir))
              False -> file_path
            }
            let clean_path = case string.starts_with(clean_path, "/") {
              True -> string.drop_start(clean_path, 1)
              False -> clean_path
            }
            io.println("  🚫 " <> key <> " (" <> clean_path <> ")")
          })
          io.println("")
          io.println("These keys are used in source code but missing from translation files.")
          snag.error("Untranslated keys found - fix the issues above")
        }
      }
    }
  }
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

// Helper functions for scanning source code

fn get_all_translation_keys(locale_data: List(#(String, g18n.Translations))) -> List(String) {
  // Collect all unique keys from all locales
  list.fold(locale_data, [], fn(acc, locale_pair) {
    let #(_, translations) = locale_pair
    let keys_from_this_locale = trie.fold(
      translations |> g18n.extract_trie,
      [],
      fn(key_acc, key_parts, _value) {
        let key = string.join(key_parts, ".")
        [key, ..key_acc]
      }
    )
    list.append(acc, keys_from_this_locale)
  })
  |> list.unique
}

fn find_gleam_files(directory: String) -> SnagResult(List(String)) {
  use files <- result.try(collect_gleam_files_recursive(directory, []))
  Ok(files)
}

fn collect_gleam_files_recursive(directory: String, acc: List(String)) -> SnagResult(List(String)) {
  case simplifile.read_directory(directory) {
    Ok(entries) -> {
      list.try_fold(entries, acc, fn(file_acc, entry) {
        let full_path = filepath.join(directory, entry)
        case simplifile.is_directory(full_path) {
          Ok(True) -> {
            // Skip build and other generated directories
            case entry {
              "build" | "target" | ".git" | "node_modules" -> Ok(file_acc)
              _ -> collect_gleam_files_recursive(full_path, file_acc)
            }
          }
          Ok(False) -> {
            case string.ends_with(entry, ".gleam") {
              True -> Ok([full_path, ..file_acc])
              False -> Ok(file_acc)
            }
          }
          Error(_) -> Ok(file_acc)
        }
      })
    }
    Error(_) -> snag.error("Could not read directory: " <> directory)
  }
}

fn extract_translation_keys_from_files(files: List(String)) -> SnagResult(List(#(String, String))) {
  list.try_fold(files, [], fn(acc, file_path) {
    use keys <- result.try(extract_translation_keys_from_file(file_path))
    let keys_with_file = list.map(keys, fn(key) { #(key, file_path) })
    Ok(list.append(acc, keys_with_file))
  })
}

fn extract_translation_keys_from_file(file_path: String) -> SnagResult(List(String)) {
  use content <- result.try(
    simplifile.read(file_path)
    |> snag.map_error(fn(_) { "Could not read file: " <> file_path })
  )
  
  use keys <- result.try(extract_keys_from_gleam_content(content))
  Ok(keys)
}

fn extract_keys_from_gleam_content(content: String) -> SnagResult(List(String)) {
  case glance.module(content) {
    Ok(module) -> {
      let keys = extract_keys_from_functions(module.functions)
      Ok(keys)
    }
    Error(_) -> {
      // If we can't parse the module, fall back to an empty list
      // This might happen with malformed or incomplete Gleam files
      Ok([])
    }
  }
}

fn extract_keys_from_functions(functions: List(glance.Definition(glance.Function))) -> List(String) {
  list.fold(functions, [], fn(acc, definition) {
    case definition {
      glance.Definition(_, glance.Function(_, _, _, _, _, body)) -> {
        list.append(acc, extract_keys_from_statements(body))
      }
    }
  })
}

fn extract_keys_from_statements(statements: List(glance.Statement)) -> List(String) {
  list.fold(statements, [], fn(acc, statement) {
    case statement {
      glance.Use(_, _, function) -> {
        list.append(acc, extract_keys_from_expression(function))
      }
      glance.Assignment(_, _, _, _, value) -> {
        list.append(acc, extract_keys_from_expression(value))
      }
      glance.Assert(_, expression, message) -> {
        let keys_from_expr = extract_keys_from_expression(expression)
        let keys_from_message = case message {
          Some(msg) -> extract_keys_from_expression(msg)
          None -> []
        }
        list.append(acc, list.append(keys_from_expr, keys_from_message))
      }
      glance.Expression(expression) -> {
        list.append(acc, extract_keys_from_expression(expression))
      }
    }
  })
}

fn extract_keys_from_expression(expression: glance.Expression) -> List(String) {
  case expression {
    // Function calls - look for g18n.translate* functions
    glance.Call(_, function, arguments) -> {
      let keys_from_call = extract_keys_from_function_call(function, arguments)
      let keys_from_args = list.fold(arguments, [], fn(acc, arg) {
        case arg {
          glance.LabelledField(_, expr) -> list.append(acc, extract_keys_from_expression(expr))
          glance.UnlabelledField(expr) -> list.append(acc, extract_keys_from_expression(expr))
          glance.ShorthandField(_) -> acc
        }
      })
      list.append(keys_from_call, keys_from_args)
    }
    
    // Block expressions
    glance.Block(_, statements) -> {
      extract_keys_from_statements(statements)
    }
    
    // Case expressions
    glance.Case(_, subjects, clauses) -> {
      let keys_from_subjects = list.fold(subjects, [], fn(acc, subject) {
        list.append(acc, extract_keys_from_expression(subject))
      })
      let keys_from_clauses = list.fold(clauses, [], fn(acc, clause) {
        let keys_from_guard = case clause.guard {
          Some(guard) -> extract_keys_from_expression(guard)
          None -> []
        }
        list.append(acc, list.append(keys_from_guard, extract_keys_from_expression(clause.body)))
      })
      list.append(keys_from_subjects, keys_from_clauses)
    }
    
    // List expressions
    glance.List(_, elements, rest) -> {
      let keys_from_elements = list.fold(elements, [], fn(acc, element) {
        list.append(acc, extract_keys_from_expression(element))
      })
      let keys_from_rest = case rest {
        Some(rest_expr) -> extract_keys_from_expression(rest_expr)
        None -> []
      }
      list.append(keys_from_elements, keys_from_rest)
    }
    
    // Tuple expressions
    glance.Tuple(_, elements) -> {
      list.fold(elements, [], fn(acc, element) {
        list.append(acc, extract_keys_from_expression(element))
      })
    }
    
    // Binary operator expressions
    glance.BinaryOperator(_, _, left, right) -> {
      let keys_from_left = extract_keys_from_expression(left)
      let keys_from_right = extract_keys_from_expression(right)
      list.append(keys_from_left, keys_from_right)
    }
    
    // Negation expressions  
    glance.NegateInt(_, operand) -> extract_keys_from_expression(operand)
    glance.NegateBool(_, operand) -> extract_keys_from_expression(operand)
    
    // Field access
    glance.FieldAccess(_, container, _) -> {
      extract_keys_from_expression(container)
    }
    
    // Tuple access
    glance.TupleIndex(_, tuple, _) -> {
      extract_keys_from_expression(tuple)
    }
    
    // Function definitions
    glance.Fn(_, _, _, body) -> {
      extract_keys_from_statements(body)
    }
    
    // Record update
    glance.RecordUpdate(_, _, _, record, fields) -> {
      let keys_from_record = extract_keys_from_expression(record)
      let keys_from_fields = list.fold(fields, [], fn(acc, field) {
        case field.item {
          Some(expr) -> list.append(acc, extract_keys_from_expression(expr))
          None -> acc
        }
      })
      list.append(keys_from_record, keys_from_fields)
    }
    
    // Literals and variables - no keys to extract
    glance.String(_, _) | glance.Int(_, _) | glance.Float(_, _) | glance.Variable(_, _) | 
    glance.Todo(_, _) | glance.Panic(_, _) | glance.FnCapture(_, _, _, _, _) | 
    glance.BitString(_, _) | glance.Echo(_, _) -> []
  }
}

fn extract_keys_from_function_call(function: glance.Expression, arguments: List(glance.Field(glance.Expression))) -> List(String) {
  case function {
    // Direct function calls like translate(...)
    glance.Variable(_, name) -> {
      case is_translation_function(name) {
        True -> extract_key_from_arguments(arguments)
        False -> []
      }
    }
    
    // Module function calls like g18n.translate(...)
    glance.FieldAccess(_, glance.Variable(_, module_name), function_name) -> {
      case module_name == "g18n" && is_translation_function(function_name) {
        True -> extract_key_from_arguments(arguments)
        False -> []
      }
    }
    
    _ -> []
  }
}

fn is_translation_function(name: String) -> Bool {
  case name {
    "translate" | "translate_with_params" | "translate_with_context" | 
    "translate_with_context_and_params" | "translate_plural" | 
    "translate_plural_with_params" | "translate_cardinal" | "translate_ordinal" | 
    "translate_range" | "translate_ordinal_with_params" | 
    "translate_range_with_params" -> True
    _ -> False
  }
}

fn extract_key_from_arguments(arguments: List(glance.Field(glance.Expression))) -> List(String) {
  // Look for the translation key in the arguments
  // The key is typically the second argument (after translator)
  case arguments {
    [_, glance.LabelledField(_, glance.String(_, key)), ..] -> [key]
    [_, glance.UnlabelledField(glance.String(_, key)), ..] -> [key]
    _ -> []
  }
}

@external(erlang, "g18n_dev_ffi", "exit")
@external(javascript, "g18n_dev_ffi.mjs", "exit")
fn exit(code: Int) -> Nil
