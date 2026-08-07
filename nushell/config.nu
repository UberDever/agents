use ~/dev/sync/nushell/vars.nu
use ~/dev/sync/nushell/commands.nu [
    jump-locations, run-cmake, git-rebase, git-reset
]

export alias vim = ~/apps/nvim/bin/nvim
export alias c = xclip
export alias v = xclip -o

export def --env my [loc: string@jump-locations] {
    cd (jump-locations | where value == $loc | get description | get 0)
}


# WORK WORK

def "arkc selfcheck" [] {
    ^($vars.dev_dir + /gitee_sync/selfcheck.sh) --configure --build=tests_full --run-func-suite --run-cts --build-clean
}

def "arkc cmake" [...flags: string, --default] {
    # -DPANDA_WITH_BENCHMARKS=true \
    let cmake_flags = "-GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -DPANDA_CROSS_COMPILER=false"
    let default_dir = if $default { $vars.core_dir } else { "" }
    run-cmake $cmake_flags $default_dir ...$flags 
}

def "etsfront cmake" [...flags: string, --default] {
    let cmake_flags = "-GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -DPANDA_CROSS_COMPILER=false -DPANDA_WITH_TESTS=true -DPANDA_WITH_BENCHMARKS=true -DPANDA_ETS_INTEROP_JS=ON -DES2PANDA_PATH=" + $vars.es2panda_dir
    let default_dir = if $default { $vars.core_dir } else { "" }
    run-cmake $cmake_flags $default_dir ...$flags 
}

def "core git rebase" [remote: string = "origin/master"] {
    print $"Rebasing onto ($remote) in ($vars.core_dir)"
    git-rebase $remote $vars.core_dir
}

def "etsfront git rebase" [remote: string = "origin/master"] {
    print $"Rebasing onto ($remote) in ($vars.etsfrontend_dir)"
    git-rebase $remote $vars.etsfrontend_dir
}

def "core git reset" [remote: string = "origin/master"] {
    print $"Resetting to ($remote) in ($vars.core_dir)"
    git-reset $remote $vars.core_dir
}

def "etsfront git reset" [remote: string = "origin/master"] {
    print $"Resetting to ($remote) in ($vars.etsfrontend_dir)"
    git-reset $remote $vars.etsfrontend_dir
}

def "core git switch" [branch: string] {
    print $"Switching to ($branch) in ($vars.core_dir)"
    cd $vars.core_dir
    git switch $branch
}

def "etsfront git switch" [branch: string] {
    print $"Switching to ($branch) in ($vars.etsfrontend_dir)"
    cd $vars.etsfrontend_dir
    git switch $branch
}

def "arkc git switch" [branch: string] {
    core git switch $branch
    es2panda git switch $branch
}

def "arkc clang-tidy" [] {
    git diff-tree --no-commit-id --name-only -r HEAD |
    split row "\n" |
    filter { $in != "" } |
    each { 
        |it|
        let filter = $"--filename-filter=.*($it)"
        print $"Processing: ($it) with ($filter)"
        /home/huawei/dev/arkcompiler/runtime_core/static_core/scripts/clang-tidy/clang_tidy_check.py $filter $vars.core_dir $"($vars.arkc_dir)/build"
    }
}

