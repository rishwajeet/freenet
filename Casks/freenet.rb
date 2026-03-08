cask "freenet" do
  version "1.1.0"
  sha256 "d9139b48378656f2c8195327300f220375835393f5c8921330297d97787e8b64"

  url "https://github.com/rishwajeet/freenet/releases/download/v#{version}/FreeNet.dmg"
  name "FreeNet"
  desc "Intelligent internet freedom — no blocks, no ads, no friction"
  homepage "https://rishwajeet.github.io/freenet/"

  depends_on macos: ">= :sonoma"

  app "FreeNet.app"

  zap trash: [
    "~/Library/Application Support/FreeNet",
    "~/Library/Caches/com.freenet.app",
    "~/Library/Preferences/com.freenet.app.plist",
  ]
end
