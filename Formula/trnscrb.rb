class Trnscrb < Formula
  desc "Offline meeting transcription for macOS — auto-detects meetings, transcribes locally"
  homepage "https://github.com/artback/trnscrb"
  url "https://github.com/artback/trnscrb/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "bc49111868a198e4c2026122674fa2020857a455b473d3f16adc02627c4c9f2b"
  license "MIT"
  head "https://github.com/artback/trnscrb.git", branch: "main"

  depends_on "uv"
  depends_on :macos

  def install
    venv = libexec / "venv"
    system "uv", "venv", venv.to_s, "--python", "3.12"
    system "uv", "pip", "install", "--python", venv / "bin" / "python", buildpath.to_s
    (bin / "trnscrb").write_env_script venv / "bin" / "trnscrb", PATH: "#{venv}/bin:$PATH"
  end

  def caveats
    <<~EOS
      To start trnscrb automatically on login:
        trnscrb install

      Or launch now with:
        trnscrb start
    EOS
  end

  service do
    run [opt_bin / "trnscrb", "start"]
    keep_alive false
    log_path var / "log/trnscrb.log"
    error_log_path var / "log/trnscrb.err"
  end

  test do
    assert_match "trnscrb", shell_output("#{bin}/trnscrb --help")
  end
end
