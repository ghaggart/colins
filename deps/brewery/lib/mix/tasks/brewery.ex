defmodule Mix.Tasks.Brewery do
  use Mix.Task

  @moduledoc """
  Compile your project's target Brewery module to an executable

  Specify a `main_module`, `out_file`, and maybe `shims` in your mix.exs file:

  ```elixir
  def project do
    [app: :brewery_example,
     version: "0.1.0",
     # ...
     # the brewery field:
     brewery: [
       main_module: BreweryExample,
       out_file: "./brewery_example"
    ]]
  end
  ```

  And then compile it with a mix task:

  ```shell
  mix brewery
  ```

  Where it will compile to `out_file`, or to `./_build/dev/lib/<ModuleName>.out`
  by default.
  """

  @cli_switches [
    out_file: :string
  ]

  @cli_aliases [
    out: :out_file,
    o: :out_file
  ]

  def run(args) do
    # Parse options
    options = get_options(args)
    compile_path = Mix.Project.compile_path
    main_module = options[:main_module]
    out_file = options[:out_file]
    shims = options[:shims]

    # Build the main module with shims to out file
    case build([
      main_module: main_module,
      out_file: out_file,
      shims: shims,
      compile_path: compile_path,
    ]) do
      :ok -> Mix.shell.info("Project built")
      {:error, reason} ->
        Mix.shell.error("Project failed to build:")
        IO.inspect(reason)
    end
  end

  defp build(options) do
    compile_path = options[:compile_path]
    main_module = options[:main_module]
    shims = options[:shims]

    # Check that main module was configured
    unless main_module do
      {:error, "No main module provided"}
    else
      # Convert main module to a string name
      main_module_name = Atom.to_string(main_module)

      # Default out file to: project/_build/Elixir.ModuleName.out
      out_file = unless options[:out],
        do: Path.expand("#{compile_path}/../#{main_module_name}.out"),
        else: options[:out]

      # Compile project, read the main Brewery module, compile it to out file
      # TODO: Make custom exceptions instead of other -> other
      Mix.Project.compile([])
      case File.read("#{compile_path}/#{main_module_name}.beam") do
        {:ok, beam_code} ->
          case parse_beam!(beam_code) |> Brewery.compile(compile_path, shims) do
            {:ok, native_code} -> File.write(out_file, native_code)
            other -> other
          end
        other -> other
      end
    end
  end

  # Parse the beam and just throw exceptions if any
  defp parse_beam!(beam_code) do
    case :beam_lib.chunks(beam_code, [:abstract_code]) do
      {:ok, {_main, [abstract_code: abstract_code]}} -> abstract_code
      {:error, _beam, reason} -> throw reason
    end
  end

  # Get options from args and mix.exs
  defp get_options(args) do
    {cli_options, _, _} = args |> OptionParser.parse([switches: @cli_switches, aliases: @cli_aliases])
    cli_options = if cli_options, do: cli_options |> Enum.into(%{}), else: %{}
    mix_options = Mix.Project.config()[:brewery]
    mix_options = if mix_options, do: Enum.into(mix_options, %{}), else: %{}
    Map.merge(mix_options, cli_options)
  end
end
