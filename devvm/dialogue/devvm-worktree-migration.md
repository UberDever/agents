# Devvm worktree migration — dialogue ledger

## Framing

- [fact, user] Replace the current independent local `clickhouse`, `clickhouse2`,
  `clickhouse3`, and `clickhouse4` clones with Git linked worktrees.
- [requirement, user] Each local worktree must sync quickly to a VM workspace that
  can build ClickHouse correctly.
- [superseded decision, user] Local worktrees were initially described as
  long-lived reusable slots.
- [decision, user] Prefer disposable, CI-like, task-named worktrees; shared
  compiler caching should recover most compilation cost.
- [decision, user] Task workspace survives repeated edit/sync/build/test cycles
  and is deleted only when the task is merged or abandoned.
- [derived requirement] Task name/path is temporary workspace identity. Deleting
  a task must not delete shared Git-object or compiler caches.
- [fact, inspection] Canonical main checkout is `/home/uberdever/dev/clickhouse`.
  Disposable worktrees are siblings directly under `/home/uberdever/dev`, e.g.
  `clickhouse-uberdever-bug-table-restart-hang-clickhouse`.
- [fact, inspection] Current devvm basename default already maps that worktree to
  `/mnt/devssd/dev/clickhouse-uberdever-bug-table-restart-hang-clickhouse`.
- [fact, inspection] The example worktree shares the main checkout's common Git
  directory and currently carries three modified top-level source files.
- [fact, code] Current devvm already creates independent shallow VM checkouts and
  shares top-level immutable Git objects between workspaces from the same origin.
- [fact, investigation] Current linked-worktree sync fails during first submodule
  materialization: the local worktree's direct submodules are uninitialized, the
  preflight does not reject that state, and the VM then clones `.gitmodules` URLs.
- [fact, upstream documentation] Git describes multiple-worktree submodule support
  as incomplete.

Decision question: How should devvm create, sync, build, and retire disposable
task-named local worktrees and VM workspaces while preserving expensive shared
Git-object and compiler caches?

Stakes: preserve build-cache isolation and exact local snapshot semantics while
removing duplicate local top-level repositories and keeping normal sync fast.

Depth: lightweight dialogue.

- [fact, code] Current ClickHouse Praktika uses `sccache`, but sets `SCCACHE_DIR`
  to the workspace-local `ci/tmp/sccache`; deleting a workspace deletes its local
  compiler cache.
- [fact, code] CMake build state and linked outputs are also workspace-local and
  are not restored by `sccache`.

## Model

- [confirmed, user] Keep `/home/uberdever/dev/clickhouse` as canonical main
  checkout and shared top-level/submodule object source.
- [confirmed, user] Create disposable task-named linked worktrees directly under
  `/home/uberdever/dev`, using names such as `clickhouse-<task-name>`.
- [confirmed, user] Map each local task basename to the same basename under
  `/mnt/devssd/dev` on the VM.
- [confirmed, user] Keep both task workspaces through repeated edit, sync, build,
  and test iterations; delete them only after merge or abandonment.
- [confirmed, user] Preserve shared Git-object and compiler caches across task
  deletion; retire the fixed `clickhouse2`, `clickhouse3`, and `clickhouse4`
  clones/workspaces after migration.
- [confirmed, user] Disposable local worktrees may leave all direct submodule
  working trees uninitialized if devvm can build complete normal submodules on
  the VM.

## Assumptions register

- [requirement, user] Correctness outranks speed: VM checkout must match exact
  superproject `HEAD`, gitlinks, and top-level staged/unstaged/untracked overlay.
- [requirement, user] Normal repeated sync should remain incremental and fast.
- [requirement, user] Cold task bootstrap must be faster than making a full
  independent recursive clone; no fixed wall-clock threshold is required.
- [decision, user] If a required gitlink object is absent from the canonical
  local module cache, devvm should automatically fetch it there. If its source
  URL is unavailable, fail with the exact path, SHA, URL, and fetch error.
- [preference, derived] Shared compiler cache and low manual setup matter more
  than preserving disposable task build directories after task completion.
- [fact, inspection] The example task has 139 direct gitlinks. Canonical
  `.git/modules` already contains repositories and exact required commits for
  137; only `contrib/Jieba-CPP` and `contrib/darts-clone` lack repositories.
- [fact, inspection] Existing canonical module repositories are not shallow and
  occupy approximately 16 GiB, so they can seed almost the entire task without
  remote submodule cloning.
- [fact, implementation] `sccache` recovers compilation work, not CMake
  configuration or linking; cold tasks still pay those costs.
- [requirement, user] Tool scope stays narrow: reproduce current checkout plus
  staged/unstaged changes on VM, then provide build/test execution.
- [requirement, user] Many task worktrees may coexist, so per-task source setup
  must be bounded and shared immutable Git objects must prevent recursive clones.
- [requirement, user] Preserve remote build acceleration state across repeated
  syncs for one task. Other VM workspace state may be removed or rewritten on
  every sync.
- [superseded contract] Current devvm intentionally preserves arbitrary ignored
  and stale untracked VM files. New desired contract is an exact disposable
  source snapshot with an explicit cache whitelist.
- [fact, implementation] `sccache` preserves compilation results, but not CMake
  configuration, Ninja dependency state, or linked binaries. Fast iterative
  builds therefore require preserving `ci/tmp/build` in addition to
  `ci/tmp/sccache` unless reconfigure/relink cost is explicitly accepted.
- [decision, user] Initial per-task cache whitelist is exactly `ci/tmp/build`
  and `ci/tmp/sccache`. Additions require measured evidence.
- [decision, user] Each sync removes stale non-cache VM state and reconstructs
  exact tracked source, top-level staged/unstaged/untracked overlay, and direct
  submodule gitlinks. Task completion removes the task workspace and both
  per-task caches; shared Git-object pools remain.

## Design space

Working morphological box; selected cells remain proposals until convergence.

| Dimension | Option A | Option B | Option C |
|---|---|---|---|
| Local repository | **Canonical main checkout + sibling linked task worktrees** | Bare hub + task worktrees | Independent clones (status quo) |
| Task identity | **Local basename maps to same VM basename** | Branch name | Generated task ID + registry |
| VM superproject | **Independent shallow normal checkout per task** | VM linked worktree | Full clone per task |
| Superproject objects | **Existing origin-keyed append-only pool** | Per-task object store | Fetch from origin |
| Local task submodules | **Remain uninitialized** | Initialize all per task | Initialize only touched paths |
| Gitlink object source | **Canonical `.git/modules`, auto-fetch missing objects** | VM fetch `.gitmodules` URLs | Copy local submodule worktrees |
| Gitlink transport | **Exact shallow commit/tree/blob closure** | Whole module bundle | Recursive filesystem copy |
| VM submodule objects | **Append-only pool per canonical submodule identity** | Per-task repositories only | One pool mixing all submodules |
| VM submodule checkout | **Normal independent submodule per task, backed by pool** | Shared submodule worktree | Plain copied files without Git metadata |
| Source overlay | **Top-level staged, unstaged, untracked only** | Include local submodule edits | Commit-only snapshot |
| Source reconciliation | **In-place hard reset + exhaustive clean with cache/submodule exclusions** | Evacuate caches, recreate whole workspace | Rsync full source tree |
| Submodule reconciliation | **Reuse object/gitdir state; reset and clean each checkout to exact gitlink** | Delete and rematerialize every sync | Preserve arbitrary module files |
| Cache preservation | **Exclude exactly `ci/tmp/build` and `ci/tmp/sccache` from clean** | Move out/back around recreation | Preserve all ignored files |
| Compiler cache ownership | **Underlying build/Praktika** | Devvm-global mount | Seed/merge task caches |
| Build state | **Per-task CMake/output tree** | Shared build directory | Delete after each build |
| Sync cleanup | **Remove all stale non-whitelisted state** | Preserve stale files | Delete whole workspace |
| Task cleanup | **Explicit task destroy; preserve shared object pools** | TTL garbage collector | Manual directory deletion |

Known infeasible or rejected cells:

- VM linked worktrees do not provide required submodule/build isolation.
- Full recursive clone loses requested bootstrap advantage.
- Initialized local task submodules conflict with desired lightweight local
  worktrees and Git's incomplete linked-worktree submodule support.
- Shared build directory risks concurrent CMake/Ninja and branch-switch
  corruption.
- Plain copied submodule files break Praktika/CMake operations requiring normal
  Git submodules.

Current design region uses bold cells.

- [decision, user] Compiler-cache lifecycle is outside devvm scope. Underlying
  ClickHouse build already uses `sccache`; devvm must not add cache mounting,
  seeding, merging, or cleanup machinery.
- [decision, user] All remaining design dimensions and separations in this box
  are accepted.

Reopened after stricter sync contract:

- [proposal, agent] Prefer exact in-place reconciliation over whole-workspace
  recreation. `reset --hard` plus exhaustive `clean` can produce the same source
  state without rewriting unchanged tracked files or submodule worktrees.
- [proposal, agent] Protect only the two accepted cache paths. Exclude direct
  submodule roots from the superproject clean, then reset/clean each submodule
  independently to its recorded gitlink.
- [decision, user] Exact in-place reconciliation is the preferred design region;
  full workspace recreation remains a comparison candidate.

## Candidates

### A. Git-native reconciler — hybrid

Extend current shallow-snapshot protocol. Keep one origin-keyed superproject
pool and per-identity submodule pools; transfer only missing exact object
closures. In each task workspace, hard-reset/clean superproject and normal
submodules, protect the two cache paths, then apply exact top-level overlay.
Central bet: Git reset/clean semantics can produce exact state with far less I/O
than source recreation.

### B. Cache evacuation + atomic source recreation — agent

Rename the two cache directories into adjacent task state, delete the disposable
source checkout, recreate a minimal shallow superproject and normal submodules
from shared object pools, then rename caches back. Central bet: simpler state
replacement and failure recovery justify rematerializing the full source tree on
every sync.

### C. Golden workspace snapshot + copy-on-write task clone — agent

Maintain one clean VM baseline for each required `HEAD`/gitlink set, create task
source trees using filesystem reflinks or snapshots, then apply local overlay;
keep per-task build caches in place. Central bet: VM filesystem copy-on-write can
make whole-tree replacement nearly constant-time while preserving normal Git
metadata.

## Objections

### Candidate A steelman

A extends the already validated exact-SHA shallow protocol, reuses current
superproject pooling, transfers only missing objects, avoids Git's incomplete
local worktree/submodule behavior, and preserves task-local build state without
recopying unchanged source. It adds one new general mechanism—pooled exact
submodule snapshots—rather than a second replication architecture.

### Red-team results

1. **Interrupted sync can expose mixed source to build/test — mitigated.** Use a
   per-task remote lock, clear a `ready` generation marker before mutation, and
   publish it only after superproject, overlay, and all gitlinks verify. Build/test
   refuse a missing or mismatched marker.
2. **Concurrent sync/build can corrupt source or build state — mitigated.** Hold
   the same per-task lock for sync and foreground build/test execution. Separate
   tasks use separate locks and workspaces.
3. **Exhaustive clean can destroy caches or submodule Git metadata — standing
   until tested.** Generate exclusions from the two literal cache paths and
   current direct gitlink roots; clean superproject and each normal submodule in
   separate scopes. Require adversarial tests with stale ignored/untracked files,
   nested repositories, and interrupted state.
4. **Missing local gitlink object may be impossible to fetch — mitigated, not
   eliminated.** Auto-fetch into canonical module cache; fail with path, SHA, URL,
   and fetch error. Current example lacks repositories for `Jieba-CPP` and
   `darts-clone`, making them mandatory integration cases.
5. **Preserved CMake state may become incompatible after a large branch/toolchain
   change — standing.** Normal build configuration should repair ordinary source
   changes, but tool needs an explicit cache-dropping recovery operation; devvm
   cannot prove arbitrary build-system cache compatibility.
6. **Append-only pools grow across many tasks — standing.** Content addressing
   deduplicates common objects, but long-term size needs reporting and an explicit
   offline prune policy; normal sync must not delete shared objects.
7. **Full recreation is simpler to reason about — refuted for normal sync,
   retained for recovery.** It rewrites all source/submodule files every sync and
   violates speed intent. Its strongest feature becomes explicit reset/recovery,
   not the steady-state algorithm.

- [superseded decision, user] An earlier pass accepted per-task locks, readiness
  markers, cache-aware reset variants, and pool reporting. The later simplicity
  preference removes those features.
- [superseding preference, user] Favor simplicity; devvm is a small synchronous
  developer tool, not a CI orchestrator.
- [proposal, agent] Drop new lock management, readiness generations, TTL cleanup,
  pool reporting/pruning, cache-aware reset variants, and task registries. Keep
  foreground command exit status as the normal success boundary. A failed or
  interrupted sync is repaired by rerunning `sync`; users must not run build/test
  after a failed sync.
- [proposal, agent] Preserve current small interface: `sync`, generic `run`, and
  destructive `reset`. Normal `sync` preserves the two cache paths; `reset`
  deletes the task workspace and its caches while retaining shared object pools.
- [decision, user] Accept this minimal synchronous contract.

## Cruxes

1. **Exactness crux:** Can in-place reconciliation remove every stale non-cache
   path while preserving both cache paths and valid normal submodule metadata?
   Cheapest decisive test: adversarial parent/submodule fixture containing
   tracked changes, staged/unstaged/untracked overlays, ignored files, nested
   repositories, stale files, and interrupted-sync state. Gate: resulting trees,
   indexes, gitlinks, and overlay manifest match source; only whitelist survives.
2. **Uninitialized-worktree crux:** Can an uninitialized linked worktree seed VM
   normal submodules solely from canonical `.git/modules` plus on-demand fetch?
   Cheapest decisive test: linked-worktree fixture with no local submodule
   checkout, one cached gitlink, and one missing module repository. Gate: both
   become normal shallow destination submodules at exact SHAs without modifying
   the linked worktree.
3. **Interrupted-sync crux:** Can a subsequent synchronous `sync` repair partial
   state? Cheapest decisive test: inject failure after superproject
   materialization and after one submodule, then rerun and verify exact state.
   No separate readiness or orchestration protocol is required.
4. **Concurrency assumption:** User does not run `sync` while build/test is active
   in the same task workspace. Distinct task directories may operate separately;
   shared pools remain append-only. Revisit only after an observed collision.
5. **Performance crux:** Is first task bootstrap faster than an independent full
   recursive clone, and is no-op sync acceptably incremental? Decisive test: real
   ClickHouse VM benchmark after correctness gates pass. Revisit design if pooled
   bootstrap is not faster than recursive clone or no-op sync regresses materially
   from current shallow protocol.
6. **Cache-compatibility assumption:** Preserved CMake/Ninja state usually remains
   usable across task syncs. Trigger: configure/build failure attributable to stale
   cache; recovery is explicit cache-dropping reset, not broader sync complexity.

## Decision

### Convergence matrix

Datum: current independent `clickhouse1/2/3/4` clones and current devvm sync.

| Criterion | A: Git-native reconciler | B: Recreate every sync |
|---|---:|---:|
| Exact snapshot correctness | + | + |
| Fast repeated sync | + | - |
| Bootstrap faster than recursive clone | + | + |
| Preserve task build state | + | + |
| Lightweight local worktrees | + | + |
| Operational simplicity | 0 | 0 |
| Low filesystem write volume | + | - |
| Recovery simplicity | 0 | + |

Ordinal scores are not summed. A dominates the repeated-sync and write-volume
criteria that motivated the worktree migration. B contributes one useful feature:
the existing destructive `reset` remains the simple recovery path.

### Selected design

Use A for normal `sync`, hybridized with destructive B-style `reset` recovery.
Keep interface limited to `sync`, generic `run`, and `reset`. Local disposable
worktrees remain uninitialized for submodules. Normal sync preserves only
`ci/tmp/build` and `ci/tmp/sccache`; reset removes the whole task workspace and
both caches while retaining shared object pools.

Explicitly given up: arbitrary stale VM-file preservation, initialized local
task submodules, atomic readiness/orchestration machinery, automatic lifecycle
cleanup, pool pruning/reporting, and guaranteed reuse of build state after reset.

- [decision, user] Selected design confirmed.

## Teach-back

- [confirmed, user] Normal `sync` preserves only `ci/tmp/build` and
  `ci/tmp/sccache`; `reset` preserves neither and retains only shared object pools.
- [confirmed, user] devvm—not the local task worktree—initializes and updates
  normal VM submodules from canonical/local and VM shared object pools.

## Decision record

Accepted ADR: `dialogue/adr-001-disposable-worktree-sync.md`.

## Implementation and validation

- [fact] `devvm_sync.sh` now implements `worktree-snapshot-v2`, accepts
  uninitialized local task submodules, transfers exact submodule snapshots through
  shared pools, materializes normal VM submodules, and reconciles source while
  preserving only `ci/tmp/build` and `ci/tmp/sccache`.
- [fact] Interface is reduced to `sync`, generic `run`, and destructive `reset`.
- [fact] Added `test_devvm_sync.sh`. Against the committed v1 script, its retired
  submodule URL reproduces the original clone failure. Against v2, two syncs pass,
  including missing-object fetch, normal absorbed submodules, Praktika's
  `submodule sync/update` sequence without network, exact overlays, stale-state
  cleanup, cache preservation, reset/pool survival, and gitlink-overlay rejection.
- [fact] Real task worktree contains 139 direct gitlinks. Canonical stores contain
  137 exact commits; exact-SHA fetches for the missing `Jieba-CPP` and
  `darts-clone` commits succeeded (8.5 MiB combined test pool).
- [fact] The default VM directory is now normalized to
  `/mnt/devssd/dev/<local-worktree-basename>`. A regression test covers the
  relative-state-path failure that previously looked for
  `<task>.devvm-sync/submodules.manifest.new` inside the checkout.
- [fact] Real VM validation passed for
  `clickhouse-uberdever-bug-table-restart-hang-clickhouse`: initial sync seeded
  and materialized all 139 direct submodules without VM GitHub cloning; remote
  `HEAD` matched `82f25519b1d1c50f4094c72525c776a53d5b0d27`, and every direct
  submodule matched its recorded gitlink. A no-change warm sync took 22.43 s.
- [fact] The relative-path bug left a partial checkout/state and duplicate pools
  under `/home/uberdever` on the VM. The checkout/state were reset after proving
  both preserved cache paths absent. The duplicate pools remain pending explicit
  deletion approval because other old relative workspaces could reference them.
- [fact] A later missing `contrib/substrait` object exposed a GitHub transport
  failure: HTTP/2 upload-pack POST returned a false 401 for a public repository,
  while the same exact-SHA fetch over HTTP/1.1 succeeded. On-demand submodule
  fetches now scope `http.version=HTTP/1.1`; a transport-boundary regression test
  and real VM sync both passed for gitlink
  `de9e6328f4f94abc0809977f57dfde7262a7258b`.
