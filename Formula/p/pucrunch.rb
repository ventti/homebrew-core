class Pucrunch < Formula
  desc "pucrunch is a hybrid LZ77 and RLE data compression program for C64/VIC20/C16/C+4 executables, authored by Pasi 'Albert' Ojala"
  homepage "https://a1bert.kapsi.fi/Dev/pucrunch/"
  version "1.14"
  url "https://github.com/mist64/pucrunch/archive/refs/heads/master.zip"
  sha256 "59c0a20315b559badfbac4b07eb8db6b940da085d7d96f91e93fb22c5cf229bc"
  license "LGPL-2.1-only"
  head "https://github.com/mist64/pucrunch.git"

  def install
    system "make"
    bin.install "pucrunch"
  end

  test do
    system "#{bin}/pucrunch", "--help"
  end
end
