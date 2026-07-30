# Homebrew cask template. Update `version` and `sha256` per release, then submit
# to homebrew-cask (or host a tap).
cask "copy-for-llm" do
  version "0.1.0"
  # Hash of the *stapled* DMG — stapling rewrites the file, so compute this
  # after Packaging/notarize.sh, not from make-dmg.sh's output.
  sha256 "925a616cfe650351a148e7a29016e310b9c8038a3225dfeeddad740058b336d5"

  url "https://github.com/sbilmis/copy-for-llm/releases/download/v#{version}/CopyForLLM-#{version}.dmg"
  name "Copy for LLM"
  desc "Finder Quick Actions that copy project context for LLMs"
  homepage "https://github.com/sbilmis/copy-for-llm"

  depends_on macos: ">= :sonoma"

  app "Copy for LLM.app"

  caveats <<~EOS
    Launch Copy for LLM once, then enable the Quick Actions in
    System Settings → General → Login Items & Extensions → Finder Quick Actions.
  EOS

  zap trash: [
    "~/Library/Application Support/CopyForLLM",
    "~/Library/Preferences/app.copyforllm.plist",
  ]
end
