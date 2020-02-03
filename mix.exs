defmodule Colins.MixProject do
  use Mix.Project

  def project do
    [
      app: :colins,
      version: "0.1.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env == :dev,
      start_permanent: Mix.env == :dev,
     # build_embedded: Mix.env == :prod,
     # start_permanent: Mix.env == :prod,
      deps: deps(),
       escript: escript(),
      # brewery: brewery(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger,:timex,:yaml_elixir,:logger_file_backend,:math,:erlport],
   #   extra_applications: [:logger,:timex,:yaml_elixir,:logger_file_backend,:math],
      mod: {Colins,[]},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.0"},
      {:tzdata, "~> 0.1.8", override: true},
     # {:tzdata, ">= 0.1.8"},
    #  {:brewery, "== 0.1.1"},
      {:yaml_elixir, "== 1.3.1"},
      #{:expline, "~> 0.1.0"}
      {:logger_file_backend, ">= 0.0.0"},
      {:math,">= 0.0.0"},
      {:erlport, "~> 0.9"},
      {:ex_doc, "~> 0.18", only: :dev}
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
end

