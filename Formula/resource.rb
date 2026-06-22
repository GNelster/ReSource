class Resource < Formula
  desc "Mac resource inspector — startup items, disk cleanup, and memory"
  homepage "https://github.com/GNelster/ReSource"
  url "https://github.com/GNelster/ReSource/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "0d309f228a488f6d3bb8c2d2cfff4d663a03ad81c542b5fed70b821a5fe13097"
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
