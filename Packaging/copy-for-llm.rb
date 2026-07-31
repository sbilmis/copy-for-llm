# Homebrew cask template. Update `version` and `sha256` per release, then submit
# to homebrew-cask (or host a tap).
cask "copy-for-llm" do
  version "0.2.0"
  # Hash of the *stapled* DMG — stapling rewrites the file, so compute this
  # after Packaging/notarize.sh, not from make-dmg.sh's output.
  sha256 "e27a1a64b45c900a0c32282c11eddc862f2cbd277ab1bff6140ffd65c30c5619"

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
