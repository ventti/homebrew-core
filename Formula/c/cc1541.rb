class Pucrunch < Formula
  desc "cc1541 is a a tool for creating Commodore Floppy disk images in D64, D71 or D81 format."
  homepage "https://acoustic-velocity.com/cc1541/"
  version "4.2"
  url "https://bitbucket.org/ptv_claus/cc1541/downloads/cc1541-4.2.zip"
  sha256 "4fc88bcbaa94df194013d3e461657ffc72653b60047afd8a64ea9c0100c3daa1"
  license "MIT"
  head "https://bitbucket.org/ptv_claus/cc1541.git"

  def install
    system "make all"
    bin.install "cc1541"
  end

  test do
    # Run the command `cc1541 -h` and check if the output contains the expected version string
    assert_match "*** This is cc1541 version 4.2", shell_output("#{bin}/cc1541 -h")
  end
end
