use ~/dev/sync/nushell/vars.nu

export def add-to-list [v: list<string>, path: string]: list<string> -> list<string> {
    ($v | split row (char esep) | append $path)
}

# update (find-index $env.config.keybindings { where item.name == "cut_line_from_start" }) {
export def find-index [v: list, pred: closure]: list -> int {
    $v | enumerate | do $pred | get index | if ($in | is-empty) { (-1) } else { $in | get 0 }
}

export def jump-locations [] { 
    [
     {value: dev, description: $vars.dev_dir},
     {value: arkc, description: $vars.arkc_dir},
     {value: core, description: $vars.core_dir},
     {value: etsfront, description: $vars.etsfrontend_dir},
     {value: build, description: ($vars.arkc_dir + "/build")},
     {value: sandbox, description: $vars.sandbox_dir},
     {value: sync, description: $vars.sync_dir},
     {value: plugin, description: $vars.ets_plugin_dir},
    ]
}

export def run-cmake [cmake_flags: string, default_dir: string, ...flags: string] {
    print "Executing with parameters: "
    print $flags
    run-external 'cmake' ...($cmake_flags | split row " ") ...$flags $default_dir
}

export def git-rebase [remote: string, dir: string] {
    let words = $remote | split words
    let remote_part = $words.0
    cd $dir
    git fetch $remote_part
    git rebase $remote
}

export def git-reset [remote: string, dir: string] {
    let words = $remote | split words
    let remote_part = $words.0
    cd $dir
    git fetch $remote_part
    git reset --hard $remote
}
