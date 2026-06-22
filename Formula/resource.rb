class Resource < Formula
  desc "Mac resource inspector — startup items, disk cleanup, and memory"
  homepage "https://github.com/GNelster/ReSource"
  url "https://github.com/GNelster/ReSource/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "27b0680cb4fd577438ad748823d77adb1d58ea86488618d816c72ae0ccdddf16"
  license "MIT"
  head "https://github.com/GNelster/ReSource.git", branch: "main"

  depends_on xcode: ["16.0", :build]
  depends_on :macos => :sonoma

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/ReSource" => "resource"
  end

  test do
    assert_match "Mac resource inspector", shell_output("#{bin}/resource --help")
  end
end
