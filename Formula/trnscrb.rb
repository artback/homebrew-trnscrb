class Trnscrb < Formula
  desc "Offline meeting transcription for macOS — auto-detects meetings, transcribes locally"
  homepage "https://github.com/artback/trnscrb"
  url "https://github.com/artback/trnscrb/archive/refs/tags/v0.9.1.tar.gz"
  sha256 "f3d7e1a5006369ee806ca43ef26f7d341fa708cf954a9d6e0fb572fe8e676fed"
  license "MIT"
  head "https://github.com/artback/trnscrb.git", branch: "main"

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
