class Resource < Formula
  desc "Mac resource inspector — startup items, disk cleanup, and memory"
  homepage "https://github.com/GNelster/ReSource"
  url "https://github.com/GNelster/ReSource/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "9caa44fa1d3960c9c4fe6f4ad30c22c9b3ad48a1cab0a1d4da5c0196f35687b1"
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
