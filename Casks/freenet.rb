cask "freenet" do
  version "1.0.0"
  sha256 "212260965b546a197fe0f942a04d52d8287bacd17a550060777f012d8194e2bb"

  url "https://github.com/rishwajeet/freenet/releases/download/v#{version}/FreeNet.dmg"
  name "FreeNet"
  desc "Intelligent internet freedom — no blocks, no ads, no friction"
  homepage "https://github.com/rishwajeet/freenet"

  depends_on macos: ">= :sonoma"

  app "FreeNet.app"

  zap trash: [
    "~/Library/Application Support/FreeNet",
    "~/Library/Caches/com.freenet.app",
    "~/Library/Preferences/com.freenet.app.plist",
  ]
end
