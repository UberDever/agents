use ~/dev/sync/nushell/vars.nu
use ~/dev/sync/nushell/commands.nu [
    add-to-list
]

export-env {
    # config
    $env.config = ($env.config | upsert show_banner false)

    # PATH
    $env.PATH = (add-to-list $env.PATH ($env.HOME + '/.dotnet'))
    $env.PATH = (add-to-list $env.PATH ($env.HOME + '/.dotnet/tools'))
    for $app in (ls '~/apps' | where type == 'dir' | get name) { 
        $env.PATH = (add-to-list $env.PATH ($app + /bin))
    }

    # env vars
    $env.EDITOR = "~/apps/nvim/bin/nvim"
    $env.my = {
        dev_dir: $vars.dev_dir,
        sandbox_dir: $vars.sandbox_dir,
        sync_dir: $vars.sync_dir,
        arkc_dir: $vars.arkc_dir,
        core_dir: $vars.core_dir,
        es2panda_dir: $vars.es2panda_dir,
        etsfrontend_dir: $vars.etsfrontend_dir,
        ets_plugin_dir: $vars.ets_plugin_dir,
    }
}
