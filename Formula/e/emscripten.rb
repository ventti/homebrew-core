class Emscripten < Formula
  desc "LLVM bytecode to JavaScript compiler"
  homepage "https://emscripten.org/"
  # To automate fetching the required resource revisions, you can use this helper script:
  #   https://gist.github.com/carlocab/2db1d7245fa0cd3e92e01fe37b164021
  url "https://github.com/emscripten-core/emscripten/archive/refs/tags/3.1.69.tar.gz"
  sha256 "3ceb2acbf3551146753c1abef8feb24347403bf13713820ea9dddbd946f9e4ac"
  license all_of: [
    "Apache-2.0", # binaryen
    "Apache-2.0" => { with: "LLVM-exception" }, # llvm
    any_of: ["MIT", "NCSA"], # emscripten
  ]
  head "https://github.com/emscripten-core/emscripten.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_sequoia: "5f1bdf5a5b31dc764a55698577c19de2c1ccde0ccf322bd9bfe1358e56400c64"
    sha256 cellar: :any,                 arm64_sonoma:  "b73510f701cd0569475b07a41ce28f16b52a53b09dac212e903c738ba90eaed1"
    sha256 cellar: :any,                 arm64_ventura: "f40d73a708d4a11ce83b600ee8849fcc5c8555cd0dd46360b5be4727ce5271df"
    sha256 cellar: :any,                 sonoma:        "8543bffab2b8e48870f206f27434fd03c24922ca8b14037a22974bda5dd8f4ed"
    sha256 cellar: :any,                 ventura:       "20ff272c8048fc60e2e05f1d93a832b1767ac1c417afbf31e40c1c6e6e9911dc"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "68b4b2de730a82e884fe2bbbb2da13a95e90e1738c9365d7524ad71cea374cf8"
  end

  depends_on "cmake" => :build
  depends_on "node"
  depends_on "python@3.12"
  depends_on "yuicompressor"

  uses_from_macos "llvm" => :build
  uses_from_macos "zlib"

  # OpenJDK is needed as a dependency on Linux and ARM64 for google-closure-compiler,
  # an emscripten dependency, because the native GraalVM image will not work.
  on_macos do
    on_arm do
      depends_on "openjdk"
    end
  end

  on_linux do
    depends_on "openjdk"
  end

  # We use LLVM to work around an error while building bundled `google-benchmark` with GCC
  fails_with :gcc do
    cause <<~EOS
      .../third-party/benchmark/src/thread_manager.h:50:31: error: expected ‘)’ before ‘(’ token
         50 |   GUARDED_BY(GetBenchmarkMutex()) Result results;
            |                               ^
    EOS
  end

  # Use emscripten's recommended binaryen revision to avoid build failures.
  # https://github.com/emscripten-core/emscripten/issues/12252
  # To find the correct binaryen revision, find the corresponding version commit at:
  # https://github.com/emscripten-core/emsdk/blob/main/emscripten-releases-tags.json
  # Then take this commit and go to:
  # https://chromium.googlesource.com/emscripten-releases/+/<commit>/DEPS
  # Then use the listed binaryen_revision for the revision below.
  resource "binaryen" do
    url "https://github.com/WebAssembly/binaryen.git",
        revision: "d8c1b0c0ceb4cc4eb59f3f3ab4840636c78e2a44"
  end

  # emscripten does not support using the stable version of LLVM.
  # https://github.com/emscripten-core/emscripten/issues/11362
  # See binaryen resource above for instructions on how to update this.
  # Then use the listed llvm_project_revision for the tarball below.
  resource "llvm" do
    url "https://github.com/llvm/llvm-project/archive/5cc64bf60bc04b9315de3c679eb753de4d554a8a.tar.gz"
    sha256 "29468bf46f23fa893ec1332bb70ae24f44897b9865fd4354a9f51ad1c8ff0174"
  end

  def install
    # Avoid hardcoding the executables we pass to `write_env_script` below.
    # Prefer executables without `.py` extensions, but include those with `.py`
    # extensions if there isn't a matching executable without the `.py` extension.
    emscripts = buildpath.children.select do |pn|
      pn.file? && pn.executable? && !(pn.extname == ".py" && pn.basename(".py").exist?)
    end.map(&:basename)

    # All files from the repository are required as emscripten is a collection
    # of scripts which need to be installed in the same layout as in the Git
    # repository.
    libexec.install buildpath.children

    # Remove unneeded files. See `tools/install.py`.
    rm_r(libexec/"test/third_party")

    # emscripten needs an llvm build with the following executables:
    # https://github.com/emscripten-core/emscripten/blob/#{version}/docs/packaging.md#dependencies
    resource("llvm").stage do
      projects = %w[
        clang
        lld
      ]

      targets = %w[
        host
        WebAssembly
      ]

      # Apple's libstdc++ is too old to build LLVM
      ENV.libcxx if ENV.compiler == :clang

      # See upstream configuration in `src/build.py` at
      # https://chromium.googlesource.com/emscripten-releases/
      args = %W[
        -DLLVM_ENABLE_LIBXML2=OFF
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_LINK_LLVM_DYLIB=OFF
        -DLLVM_BUILD_LLVM_DYLIB=OFF
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
        -DLLVM_ENABLE_BINDINGS=OFF
        -DLLVM_TOOL_LTO_BUILD=OFF
        -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON
        -DLLVM_TARGETS_TO_BUILD=#{targets.join(";")}
        -DLLVM_ENABLE_PROJECTS=#{projects.join(";")}
        -DLLVM_ENABLE_TERMINFO=#{!OS.linux?}
        -DCLANG_ENABLE_ARCMT=OFF
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_INSTALL_UTILS=OFF
        -DLLVM_ENABLE_ZSTD=OFF
        -DLLVM_ENABLE_Z3_SOLVER=OFF
      ]
      args << "-DLLVM_ENABLE_LIBEDIT=OFF" if OS.linux?

      system "cmake", "-S", "llvm", "-B", "build",
                      "-G", "Unix Makefiles",
                      *args, *std_cmake_args(install_prefix: libexec/"llvm")
      system "cmake", "--build", "build"
      system "cmake", "--build", "build", "--target", "install"

      # Remove unneeded tools. Taken from upstream `src/build.py`.
      unneeded = %w[
        check cl cpp extef-mapping format func-mapping import-test offload-bundler refactor rename scan-deps
      ].map { |suffix| "clang-#{suffix}" }
      unneeded += %w[lld-link ld.lld ld64.lld llvm-lib ld64.lld.darwinnew ld64.lld.darwinold]
      (libexec/"llvm/bin").glob("{#{unneeded.join(",")}}").map(&:unlink)
      (libexec/"llvm/lib").glob("libclang.{dylib,so.*}").map(&:unlink)

      # Include needed tools omitted by `LLVM_INSTALL_TOOLCHAIN_ONLY`.
      # Taken from upstream `src/build.py`.
      extra_tools = %w[FileCheck llc llvm-as llvm-dis llvm-link llvm-mc
                       llvm-nm llvm-objdump llvm-readobj llvm-size opt
                       llvm-dwarfdump llvm-dwp]
      (libexec/"llvm/bin").install extra_tools.map { |tool| "build/bin/#{tool}" }

      %w[clang clang++].each do |compiler|
        (libexec/"llvm/bin").install_symlink compiler => "wasm32-#{compiler}"
        (libexec/"llvm/bin").install_symlink compiler => "wasm32-wasi-#{compiler}"
        bin.install_symlink libexec/"llvm/bin/wasm32-#{compiler}"
        bin.install_symlink libexec/"llvm/bin/wasm32-wasi-#{compiler}"
      end
    end

    resource("binaryen").stage do
      system "cmake", "-S", ".", "-B", "build", *std_cmake_args(install_prefix: libexec/"binaryen")
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end

    cd libexec do
      system "npm", "install", *std_npm_args(prefix: false)
      # Delete native GraalVM image in incompatible platforms.
      if OS.linux?
        rm_r("node_modules/google-closure-compiler-linux")
      elsif Hardware::CPU.arm?
        rm_r("node_modules/google-closure-compiler-osx")
      end
    end

    # Add JAVA_HOME to env_script on ARM64 macOS and Linux, so that google-closure-compiler
    # can find OpenJDK
    emscript_env = { PYTHON: Formula["python@3.12"].opt_bin/"python3.12" }
    emscript_env.merge! Language::Java.overridable_java_home_env if OS.linux? || Hardware::CPU.arm?

    emscripts.each do |emscript|
      (bin/emscript).write_env_script libexec/emscript, emscript_env
    end

    # Replace universal binaries with their native slices
    deuniversalize_machos libexec/"node_modules/fsevents/fsevents.node"
  end

  def post_install
    return if File.exist?("#{Dir.home}/.emscripten")
    return if (libexec/".emscripten").exist?

    system bin/"emcc", "--generate-config"
    inreplace libexec/".emscripten" do |s|
      s.change_make_var! "LLVM_ROOT", "'#{libexec}/llvm/bin'"
      s.change_make_var! "BINARYEN_ROOT", "'#{libexec}/binaryen'"
      s.change_make_var! "NODE_JS", "'#{Formula["node"].opt_bin}/node'"
    end
  end

  def caveats
    return unless File.exist?("#{Dir.home}/.emscripten")
    return if (libexec/".emscripten").exist?

    <<~EOS
      You have a ~/.emscripten configuration file, so the default configuration
      file was not generated. To generate the default configuration:
        rm ~/.emscripten
        brew postinstall emscripten
    EOS
  end

  test do
    # We're targeting WASM, so we don't want to use the macOS SDK here.
    ENV.remove_macosxsdk if OS.mac?
    # Avoid errors on Linux when other formulae like `sdl12-compat` are installed
    ENV.delete "CPATH"

    ENV["NODE_OPTIONS"] = "--no-experimental-fetch"

    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      int main()
      {
        printf("Hello World!");
        return 0;
      }
    EOS

    system bin/"emcc", "test.c", "-o", "test.js", "-s", "NO_EXIT_RUNTIME=0"
    assert_equal "Hello World!", shell_output("node test.js").chomp
  end
end
