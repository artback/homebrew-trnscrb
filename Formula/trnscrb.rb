class Trnscrb < Formula
  desc "Offline meeting transcription for macOS that auto-detects your meetings"
  homepage "https://github.com/artback/trnscrb"
  url "https://github.com/artback/trnscrb/archive/refs/tags/v0.67.7.tar.gz"
  sha256 "66ba840fdff6eb35562aa07fa38c7ee5f92026ac834ec55cb50c44cd08dac405"
  license "MIT"
  head "https://github.com/artback/trnscrb.git", branch: "main"

  depends_on "ffmpeg"
  depends_on :macos
  depends_on "python@3.12"
  depends_on "uv"

  def install
    python = formula_opt_bin("python@3.12") / "python3.12"
    venv = libexec / "venv"
    system "uv", "venv", venv.to_s, "--python", python.to_s
    system "uv", "pip", "install", "--python", (venv / "bin" / "python").to_s, buildpath.to_s
    (bin / "trnscrb").write_env_script venv / "bin" / "trnscrb", PATH: "#{venv}/bin:$PATH"

    # Build the Trnscrb.app wrapper so macOS attributes permission prompts
    # (Screen Recording, Microphone, Automation) to "Trnscrb" instead of the
    # invoking terminal. `trnscrb install` copies it into ~/Applications.
    # The module ships with trnscrb >= 0.10.0.
    if (buildpath / "trnscrb" / "app_bundle.py").exist?
      system venv / "bin" / "python", "-m", "trnscrb.app_bundle",
             prefix / "Trnscrb.app", opt_bin / "trnscrb"
    end

    # Every library in this venv was already relocated by the wheel that built
    # it: they find each other through @loader_path and carry ad-hoc signatures
    # that match their contents exactly. Homebrew's relocation pass has nothing
    # to add here and three ways to break it — it rewrites dylib IDs to absolute
    # Cellar paths, invalidating the signature of every file it touches; it
    # deletes the rpaths torchcodec needs to reach libtorch; and it raises
    # outright on libraries whose Mach-O header is too small to hold the longer
    # path, abandoning the rest of the keg and failing the install.
    #
    # So hide them from it. Gzipped, they are not Mach-O files and the pass
    # walks straight past; `post_install_steps` unpacks them once it has run.
    # Costs a few seconds each way and leaves the wheels' own linkage intact.
    system "sh", "-c", <<~SH
      find #{libexec}/venv -type f \\( -name '*.dylib' -o -name '*.so' \\) -print0 |
        xargs -0 -n 8 -P #{Hardware::CPU.cores} gzip -1 -n
    SH

    # Unpack those libraries again once the pass has run, and re-sign anything
    # Homebrew did modify and leave with a signature that no longer matches its
    # contents — the .app wrapper, and any Mach-O file outside the venv. This
    # runs on bottle pours as well as source builds.
    resign = libexec/"resign-relocated-libraries"
    resign.write <<~SH
      #!/bin/sh
      # Re-sign every Mach-O file in the keg whose signature no longer matches
      # its contents. `codesign -v` reports linker-signed libraries as "not
      # signed at all"; those load fine and are deliberately left alone.
      set -eu
      root=$(cd "$(dirname "$0")/.." && pwd)

      resign_if_broken() {
        codesign -v "$1" 2>&1 | grep -q 'invalid signature' || return 0
        # --preserve-metadata keeps the bundle identifier, so re-signing does
        # not change an app bundle's designated requirement.
        codesign --force --sign - \\
          --preserve-metadata=identifier,entitlements,requirements,flags,runtime \\
          "$1" || echo "warning: could not re-sign $1" >&2
      }

      # Unpack the venv libraries the formula gzipped so the relocation pass
      # would walk past them.
      find "$root/libexec/venv" -type f \\( -name '*.dylib.gz' -o -name '*.so.gz' \\) -print0 |
        xargs -0 -n 8 -P 4 gunzip -f

      find "$root/libexec/venv" -type f \\( -name '*.dylib' -o -name '*.so' \\) |
        while IFS= read -r lib; do
          resign_if_broken "$lib"
        done

      # The .app carries the TCC permissions; a broken seal re-prompts for
      # them. `trnscrb install` copies this packaged bundle into ~/Applications
      # ONLY when its identity marker changes, so ad-hoc is stable there:
      # routine releases never touch the installed bundle or its grant.
      if [ -d "$root/Trnscrb.app" ] && codesign -v "$root/Trnscrb.app" 2>&1 | grep -q 'invalid signature'; then
        resign_if_broken "$root/Trnscrb.app"
      fi
      exit 0
    SH
    chmod 0755, resign
  end

  post_install_steps do
    run "libexec/resign-relocated-libraries",
        base:           :prefix,
        writable_base:  :prefix,
        writable_paths: ["libexec/venv", "Trnscrb.app"],
        print_stdout:   true
  end

  def caveats
    <<~EOS
      Run the setup wizard (permissions, models, launch at login,
      and the ~/Applications/Trnscrb.app permission wrapper):
        trnscrb install

      Or launch now with:
        trnscrb start
    EOS
  end

  service do
    run [opt_prefix / "Trnscrb.app/Contents/MacOS/Trnscrb"]
    keep_alive false
    log_path var / "log/trnscrb.log"
    error_log_path var / "log/trnscrb.err"
  end

  test do
    assert_match "trnscrb", shell_output("#{bin}/trnscrb --help")
  end
end
