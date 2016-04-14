defmodule McProtocol.Mixfile do
  use Mix.Project

  def project do
    [app: :mc_protocol,
     version: "0.0.2",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cutkey]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:cutkey, github: "imtal/cutkey", optional: true},
     {:uuid, "~> 1.1"},
     {:proto_def, "~> 0.0.2"},
     {:mc_data, "~> 0.0.4"},
     {:credo, "~> 0.3", only: [:dev, :test]},
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev},
     {:benchfella, "~> 0.3.0", only: [:dev, :test]}]
  end

  defp description do
    """
    Implementation of the Minecraft protocol in Elixir.
    Aims to provide functional ways to interact with the minecraft protocol on all levels, including packet reading and writing, encryption, compression, authentication and more.
    """
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["hansihe"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/McEx/McProtocol"},
    ]
  end
end
