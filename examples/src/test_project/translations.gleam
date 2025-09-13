import g18n
import g18n/locale

pub fn en_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation(
    "admin.settings.description",
    "Manage your application settings",
  )
  |> g18n.add_translation("admin.settings.title", "Settings")
  |> g18n.add_translation("admin.users.count", "Total Users")
  |> g18n.add_translation("messages.goodbye", "Thank you for using our service")
  |> g18n.add_translation("messages.welcome", "Welcome to our application")
  |> g18n.add_translation("ui.button.cancel", "Cancel")
  |> g18n.add_translation("ui.button.delete", "Delete")
  |> g18n.add_translation("ui.button.save", "Save")
  |> g18n.add_translation("user.profile.avatar", "Profile Picture")
  |> g18n.add_translation("user.profile.email", "Email")
  |> g18n.add_translation("user.profile.name", "Name")
}

pub fn en_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("en")
  locale
}

pub fn en_translator() -> g18n.Translator {
  g18n.new_translator(en_locale(), en_translations())
}

pub fn fr_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation("admin.settings.title", "Paramètres")
  |> g18n.add_translation("admin.users.count", "Nombre total d'utilisateurs")
  |> g18n.add_translation("messages.goodbye", "Merci d'utiliser notre service")
  |> g18n.add_translation(
    "messages.welcome",
    "Bienvenue dans notre application",
  )
  |> g18n.add_translation("ui.button.cancel", "Annuler")
  |> g18n.add_translation("ui.button.delete", "Supprimer")
  |> g18n.add_translation("ui.button.save", "Sauvegarder")
  |> g18n.add_translation("user.profile.avatar", "Photo de profil")
  |> g18n.add_translation("user.profile.email", "E-mail")
  |> g18n.add_translation("user.profile.name", "Nom")
}

pub fn fr_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("fr")
  locale
}

pub fn fr_translator() -> g18n.Translator {
  g18n.new_translator(fr_locale(), fr_translations())
}

pub fn es_translations() -> g18n.Translations {
  g18n.new_translations()
  |> g18n.add_translation("admin.settings.description", "")
  |> g18n.add_translation("admin.settings.title", "Configuración")
  |> g18n.add_translation("admin.users.count", "Total de Usuarios")
  |> g18n.add_translation("messages.welcome", "Bienvenido a nuestra aplicación")
  |> g18n.add_translation("ui.button.cancel", "Cancelar")
  |> g18n.add_translation("ui.button.delete", "Eliminar")
  |> g18n.add_translation("ui.button.save", "Guardar")
  |> g18n.add_translation("user.profile.avatar", "")
  |> g18n.add_translation("user.profile.email", "Correo electrónico")
  |> g18n.add_translation("user.profile.name", "Nombre")
}

pub fn es_locale() -> locale.Locale {
  let assert Ok(locale) = locale.new("es")
  locale
}

pub fn es_translator() -> g18n.Translator {
  g18n.new_translator(es_locale(), es_translations())
}

pub fn available_locales() -> List(String) {
  ["en", "fr", "es"]
}
