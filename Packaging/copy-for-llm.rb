# Homebrew cask template. Update `version` and `sha256` per release, then submit
# to homebrew-cask (or host a tap).
cask "copy-for-llm" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_make-dmg.sh"

  url "https://github.com/OWNER/copy-for-llm/releases/download/v#{version}/CopyForLLM-#{version}.dmg"
  name "Copy for LLM"
  desc "Finder Quick Actions that copy project context for LLMs"
  homepage "https://github.com/OWNER/copy-for-llm"

  depends_on macos: ">= :sonoma"

  app "Copy for LLM.app"

  caveats <<~EOS
    Launch Copy for LLM once, then enable the Quick Actions in
    System Settings → General → Login Items & Extensions → Finder Quick Actions.
  EOS

  zap trash: [
    "~/Library/Application Support/CopyForLLM",
    "~/Library/Preferences/com.selcukbilmis.copyforllm.plist",
  ]
end
