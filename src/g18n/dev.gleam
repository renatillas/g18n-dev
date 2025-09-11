import argv
import filepath
import g18n
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
/// gleam run help              # Show help
/// gleam run                   # Show help (default)
/// ```
pub fn main() {
  case argv.load().arguments {
    ["generate"] -> generate_command()
    ["generate", "--nested"] -> generate_nested_command()
    ["generate", "--po"] -> generate_po_command()
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
