class Pyyaml < Formula
  desc "YAML parser and emitter for Python"
  homepage "https://pyyaml.org/"
  url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
  sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  license "MIT"

  livecheck do
    url :stable
    strategy :pypi
  end

  depends_on "libyaml"
  depends_on "python@3.14"

  def install
    python3 = Formula["python@3.14"].opt_bin/"python3.14"
    system python3, "-m", "pip", "install", "--prefix=#{prefix}", "."
  end

  test do
    python3 = Formula["python@3.14"].opt_bin/"python3.14"
    system python3, "-c", "import yaml; assert yaml.safe_load('foo: bar') == {'foo': 'bar'}"
  end
end
