# Homebrew cask template. Update `version` and `sha256` per release, then submit
# to homebrew-cask (or host a tap).
cask "copy-for-llm" do
  version "0.2.1"
  # Hash of the *stapled* DMG — stapling rewrites the file, so compute this
  # after Packaging/notarize.sh, not from make-dmg.sh's output.
  sha256 "9f79c56445cf01c8d6b4fd91112d339e5bf33f9cc4e50c500d925996c12403f6"

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
