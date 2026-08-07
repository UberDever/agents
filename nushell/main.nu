use ~/dev/sync/nushell/env.nu
source ~/dev/sync/nushell/config.nu
source ~/dev/sync/nu_scripts/custom-completions/git/git-completions.nu
source ~/dev/sync/nu_scripts/custom-completions/make/make-completions.nu
source ~/dev/sync/nu_scripts/custom-completions/vscode/vscode-completions.nu
source ~/dev/sync/nu_scripts/custom-completions/typst/typst-completions.nu

use ~/dev/sync/nu_scripts/themes/nu-themes/onedark.nu
$env.config = ($env.config | merge {color_config: (onedark | upsert hints light_cyan)})
