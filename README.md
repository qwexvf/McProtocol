# McProtocol

Implementation of the Minecraft protocol in Elixir.

Aims to provide functional ways to interact with the minecraft protocol on all levels, including packet reading and writing, encryption, compression, authentication and more.

## Installation

The package can be installed as:

  1. Add elixir_mc_protocol to your list of dependencies in `mix.exs`:

        def deps do
          [{:elixir_mc_protocol, "~> 0.0.1"}]
        end

  2. Ensure elixir_mc_protocol is started before your application:

        def application do
          [applications: [:elixir_mc_protocol]]
        end

## Documentation
Documentation can be found [here](https://hexdocs.pm/mc_protocol/api-reference.html) with some usages [here](https://github.com/McEx/McProtocol/tree/master/test)
