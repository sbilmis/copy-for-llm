# Developing & Releasing Copy for LLM

Working notes for maintaining this project — the day-to-day loop, the release
pipeline, and the macOS-specific traps that cost time to diagnose.

## Layout

```
CopyForLLMCore/     Swift package — ALL logic lives here, plus the unit tests
App/                SwiftUI menu-bar app (Options window, Settings, MenuBarExtra)
Extensions/         Four Quick Action targets; Shared/ holds the real handler
Packaging/          Icon generator, DMG + notarization scripts, Homebrew cask
project.yml         XcodeGen manifest — the .xcodeproj is generated, never edited
```

The app, the four extensions, and the CLI are all thin frontends over
`CopyPipeline.run(_:)`. Any new frontend (Raycast, Alfred, a real CLI release)
should call that and nothing else.

**Never edit `CopyForLLM.xcodeproj`** — it is git-ignored and regenerated from
`project.yml` by `xcodegen generate`. Changes made in Xcode's UI are lost.

## Day-to-day

```bash
make test        # core unit tests — fastest feedback, no Xcode project needed
make generate    # regenerate the .xcodeproj after editing project.yml
make build       # Debug build
make install     # build + copy to /Applications
```

Iterating on engine logic doesn't need the app at all — use the CLI harness:

```bash
cd CopyForLLMCore
swift run llmcopy ~/some/project --format xml --report
```

`--report` prints counts, skips, and the token estimate to stderr.

## Installing so Finder actually sees the actions

This is the fiddly part. After building, all four steps matter:

```bash
# 1. Install to /Applications (extensions are only trusted from there)
rm -rf "/Applications/Copy for LLM.app"
ditto ".build/DerivedData/Build/Products/Release/Copy for LLM.app" \
      "/Applications/Copy for LLM.app"

# 2. Register each extension with pkd
for x in "/Applications/Copy for LLM.app/Contents/PlugIns/"*.appex; do
    pluginkit -a "$x"
done

# 3. Enable them — newly registered Quick Actions default to DISABLED
for id in action-copy action-tree action-paths action-options; do
    pluginkit -e use -i app.copyforllm.$id
done

# 4. Restart Finder so the context menu is rebuilt
killall Finder
```

Check the result — `+` means enabled, `-` disabled, blank means registered but
never toggled:

```bash
pluginkit -m -p com.apple.services | grep copyforllm
```

In Finder the actions live **inside the "Quick Actions ▸" submenu**, not at the
top level of the context menu. The user-facing toggle is System Settings →
General → Login Items & Extensions → Finder Quick Actions.

### Duplicate actions in the menu

If each action appears **twice** in Finder or in System Settings, a stale copy is
registered from somewhere other than `/Applications` — almost always the build
products in `.build/DerivedData/`, because `xcodebuild` runs
`RegisterWithLaunchServices` on whatever it builds. A Debug build and an
installed Release build therefore register two sets.

List every registration with its path and remove the ones you don't want:

```bash
pluginkit -m -v -p com.apple.services | grep copyforllm | awk -F'\t' '{print $NF}'

pluginkit -m -v -p com.apple.services | grep copyforllm \
  | awk -F'\t' '{print $NF}' | grep -v '^/Applications' \
  | while IFS= read -r p; do pluginkit -r "$p"; done
```

`pluginkit -e ignore` only *hides* an entry — it still appears in System Settings
and can be switched back on. Use `-r` to actually unregister, and delete the
stale bundle so it isn't rediscovered. `make clean` removes DerivedData for this
reason.

### After changing the bundle ID

Old identifiers linger in pkd and stay enabled while pointing at a deleted
bundle, which is confusing. Disable them explicitly and rebuild the
LaunchServices database:

```bash
pluginkit -e ignore -i old.bundle.id.action-copy
/System/Library/Frameworks/CoreServices.framework/Frameworks/\
LaunchServices.framework/Support/lsregister -kill -r \
  -domain local -domain system -domain user
```

## Releasing

Prerequisite, once: a **Developer ID Application** certificate in the keychain
(Xcode → Settings → Accounts → Manage Certificates → +) and a stored notary
profile. The notary profile must use the account's **primary** Apple ID — an
alias returns a confusing `401 Invalid credentials`.

```bash
xcrun notarytool store-credentials copyforllm \
  --apple-id <primary-apple-id> --team-id 38X62GQ8HC
```

Then per release:

```bash
# 1. Build + sign the DMG
DEVELOPER_ID="Developer ID Application: <name> (38X62GQ8HC)" Packaging/make-dmg.sh

# 2. Notarize + staple (fails loudly and prints Apple's log if rejected)
Packaging/notarize.sh Packaging/build/CopyForLLM-0.1.0.dmg

# 3. Hash the STAPLED file — stapling rewrites the DMG, so the hash from
#    step 1 is already stale. This value goes in Packaging/copy-for-llm.rb.
shasum -a 256 Packaging/build/CopyForLLM-0.1.0.dmg

# 4. Publish
gh release create v0.1.0 Packaging/build/CopyForLLM-0.1.0.dmg \
  --title "v0.1.0" --notes "..."
```

Confirm the result — you want `source=Notarized Developer ID`:

```bash
spctl -a -t open --context context:primary-signature -v \
  Packaging/build/CopyForLLM-0.1.0.dmg
```

Bump `MARKETING_VERSION` in `project.yml` and `version` in the cask together.

Regenerate the icon after editing the generator: `swift Packaging/make-icon.swift`.

## Traps already hit (don't rediscover these)

**Notarization rejects `get-task-allow`.** Xcode injects the debugger-attach
entitlement into every binary, and Apple treats it as a critical error. Fixed by
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` on the Release config in `project.yml`.

**`notarytool submit` exits 0 even when Apple rejects the archive** — the exit
code reflects the upload, not the verdict. `notarize.sh` greps for
`status: Accepted` and aborts otherwise; keep that check. To read a verdict
later: `xcrun notarytool log <submission-id> --keychain-profile copyforllm`.

**`NSExtensionPrincipalClass` must be a bare `@objc` name.** A module-qualified
Swift name (`CopyDefaultAction.ActionRequestHandler`) does not resolve. Each
handler is exposed as `@objc(CopyForLLM<Dir>Handler)` and `project.yml`
references that. Verify with:

```bash
nm ".../CopyDefaultAction.appex/Contents/MacOS/CopyDefaultAction" \
  | grep CopyForLLMCopyDefaultHandler
```

**pkd refuses to register unsandboxed app extensions.** The symptom is
`pluginkit -a` succeeding while `pkd` logs `Final plugin count: 0`. The
extensions are therefore sandboxed, and reach the shared settings directory via
a `temporary-exception` entitlement. That entitlement is the main thing standing
between this app and the Mac App Store — a real App Group would replace it, and
`SharedStore.init(directory:)` already takes an injectable path for exactly that.

**`pbs -dump` does not list extension-based Quick Actions.** Searching it for
the app name returns nothing even when everything works — built-in actions like
Rotate and Markup are equally absent. It is not a diagnostic; use
`pluginkit -m -p com.apple.services`.

**`nonisolated(unsafe)` locals are not portable.** Passing `NSExtensionContext`
into a `Task` compiled on Swift 6.3 but failed on CI's 6.0. Use the explicit
`Unchecked<T>` box in `CopyActionHandler.swift`.

**CI needs `CODE_SIGNING_ALLOWED=NO`.** The extensions declare entitlements, and
signing those fails with exit 65 on a runner with no identity.

## Testing checklist before a release

Unit tests cover the engine; these need a human because Finder can't be driven
headlessly:

- Single text file → contents only, no tree
- Folder → tree + contents
- Multi-file selection → paths prefixed correctly
- Folder with `.gitignore` → ignored files absent
- Folder with `node_modules/` → skipped, notification count sane
- Binary-only selection → graceful "nothing to copy" notification
- Huge repo → truncation notice, and Options… stays responsive
- Options… → window opens with the selection, filters re-scan live, ⌘F searches
