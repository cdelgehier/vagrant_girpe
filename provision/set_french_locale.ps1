# Use French formats and keyboard without requiring a downloaded display language.
$ErrorActionPreference = 'Stop'
Set-WinSystemLocale -SystemLocale fr-FR
Set-Culture -CultureInfo fr-FR
Set-WinUserLanguageList -LanguageList fr-FR -Force
