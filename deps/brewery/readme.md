
# Brewery

> Compiling Elixir code into standalone executables

I enjoy the [Elixir language](https://elixir-language.org).  It is based on [Erlang VM](http://erlang.org/faq/implementations.html) which is used for servers and scaling horizontally.  But, I still think the ideas inside Elixir and Erlang could be valuable outside of that scope, in things like applications.

This tool hooks into Mix by letting it compile your project to [BEAM code](http://erlang.org/doc/man/beam_lib.html), and then transforming the BEAM code to LLVM IR.  It can shim bigger Erlang/Elixir APIs such as `gen_tcp` with a native alternative (called "Brewery Shims").

## Installation

Add `:brewery` as a dependency in your `mix.exs`:

```elixir
def deps do
  [{:brewery, "~> 0.1.0"}]
end
```

And also the application:

```elixir
def application do
  [extra_applications: [:brewery]]
end
```

## Documentation

View the documentation on [hexdocs.pm/brewery](https://hexdocs.pm/brewery)

## License

MIT © [Jamen Marz](https://git.io/jamen)
