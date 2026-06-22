class Resource < Formula
  desc "Mac resource inspector — startup items, disk cleanup, and memory"
  homepage "https://github.com/gmnelson/ReSource"
  url "https://github.com/gmnelson/ReSource/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256_REPLACE_AFTER_TAGGING"
  license "MIT"
  head "https://github.com/gmnelson/ReSource.git", branch: "main"

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
