defmodule Brewery.Mixfile do
  use Mix.Project

  def project do
    [app: :brewery,
     description: "Compiling Elixir code into standalone executables",
     version: "0.1.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package()]
  end

  defp deps do
    [{:ex_doc, "~> 0.15.0"}]
  end

  defp package() do
    [licenses: ["MIT"],
     maintainers: ["Jamen Marz <jamenmarz@gmail.com>"],
     links: %{
      "GitHub" => "https://github.com/jamen/brewery",
      "Docs" => "https://hexdocs.pm/brewery"
     }]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
