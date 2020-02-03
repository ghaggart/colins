defmodule Colins.MixProject do
  use Mix.Project

  def project do
    [
      app: :colins,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env == :dev,
      start_permanent: Mix.env == :dev,
     # build_embedded: Mix.env == :prod,
     # start_permanent: Mix.env == :prod,
      deps: deps(),
      escript: escript(),
      description: description(),
      package: package(),
      deps: deps(),
      name: "colins",
      source_url: "https://github.com/ghaggart/colins",
      docs: [
          main:  "Colins", # The main page in the docs
             # logo: "path/to/logo.png",
              extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger,:timex,:yaml_elixir,:logger_file_backend,:math,:erlport],
      mod: {Colins,[]},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.0"},
      {:tzdata, "~> 0.1.8", override: true},
      {:yaml_elixir, "== 1.3.1"},
      {:logger_file_backend, ">= 0.0.0"},
      {:math,">= 0.0.0"},
      {:erlport, "~> 0.9"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  def escript do
      [main_module: Colins ]
      # Specify the number of schedulers available here:
      #emu_args: "+S 1"]
  end

 def brewery do
      [
       main_module: Colins,
       out_file: "./colinsb"
      ]
  end

  defp description() do
    "COLINS is an adaptive ODE solver that leverages Elixir Actors for concurrency"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "colins",
      # These are the default files included in the package
      files: ~w(lib priv .formatter.exs mix.exs README* readme* LICENSE*
                license* CHANGELOG* changelog* src),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/ghaggart/colins"}
    ]
  end
end

