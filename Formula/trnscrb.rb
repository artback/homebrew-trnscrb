class Trnscrb < Formula
  desc "Offline meeting transcription for macOS — auto-detects meetings, transcribes locally"
  homepage "https://github.com/artback/trnscrb"
  url "https://github.com/artback/trnscrb/archive/refs/tags/v0.57.0.tar.gz"
  sha256 "102d48f02a6c01732d8ab79fced225f0d715e831aa473aece7ee959b43b2fb68"
  license "MIT"
  head "https://github.com/artback/trnscrb.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "python@3.12"
  depends_on "uv"
  depends_on :macos

  def install
    python = Formula["python@3.12"].opt_bin / "python3.12"
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

    # Homebrew relocates the keg's Mach-O files after `install` returns,
    # rewriting their load commands in place. That edit invalidates the ad-hoc
    # signature each file shipped with, and macOS refuses to load a library
    # whose signature no longer matches its contents — which is how the
    # vendored audio libraries came to kill the MCP server on a fresh install.
    # `post_install_steps` runs this script after the relocation pass, so the
    # repair happens on the user's machine, for bottle pours as well as source
    # builds.
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

      find "$root/libexec/venv" -type f \\( -name '*.dylib' -o -name '*.so' \\) |
        while IFS= read -r lib; do
          resign_if_broken "$lib"
        done

      # The .app carries the TCC permissions; a broken seal re-prompts for them.
      [ -d "$root/Trnscrb.app" ] && resign_if_broken "$root/Trnscrb.app"
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
