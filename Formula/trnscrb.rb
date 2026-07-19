class Trnscrb < Formula
  desc "Offline meeting transcription for macOS — auto-detects meetings, transcribes locally"
  homepage "https://github.com/artback/trnscrb"
  url "https://github.com/artback/trnscrb/archive/refs/tags/v0.9.0.tar.gz"
  sha256 "f4077f231e42d3990b6ae3b65507c2b5f69d832b27b83382b8289049decb6451"
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
