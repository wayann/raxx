# Maybe rename Raxx.HTMLTemplate
defmodule Raxx.View do
  @moduledoc ~S"""
  Generate views from `.eex` template files.

  Using this module will add the functions `html` and `render` to a module.

  ## Example

      # greet.html.eex
      <p>Hello, <%= name %></p>

      # layout.html.eex
      <h1>Greetings</h1>
      <%= __content__ %>

      # greet.ex
      defmodule Greet do
        use Raxx.View,
          arguments: [:name],
          layout: "layout.html.eex"
      end

      # iex -S mix
      Greet.html("Alice")
      # => "<h1>Greetings</h1>\n<p>Hello, Alice</p>"

      Raxx.response(:ok)
      |> Greet.render("Bob")
      # => %Raxx.Response{
      #      status: 200,
      #      headers: [{"content-type", "text/html"}],
      #      body: "<h1>Greetings</h1>\n<p>Hello, Alice</p>"
      #    }

  ### Options

    - **arguments:** A list of atoms for variables used in the template.
      This will be the argument list for the html function.
      The render function takes one additional argument to this list,
      a response struct.

    - **template (optional):** The eex file containing a main content template.
      If not given the template file will be generated from the file of the calling module.
      i.e. `path/to/file.ex` -> `path/to/file.html.eex`

    - **layout (optional):** An eex file containing a layout template.
      This template can use all the same variables as the main template.
      In addition it must include the content using `<%= __content %>`
  """
  defmacro __using__(options) do
    {options, []} = Module.eval_quoted(__CALLER__, options)

    {arguments, options} = Keyword.pop_first(options, :arguments, [])

    {page_template, options} =
      Keyword.pop_first(options, :template, Raxx.View.template_for(__CALLER__.file))

    page_template = Path.expand(page_template, Path.dirname(__CALLER__.file))

    {layout_template, remaining_options} = Keyword.pop_first(options, :layout)

    if remaining_options != [] do
      keys =
        Keyword.keys(remaining_options)
        |> Enum.map(&inspect/1)
        |> Enum.join(", ")

      raise ArgumentError, "Unexpected options for #{inspect(unquote(__MODULE__))}: [#{keys}]"
    end

    layout_template =
      if layout_template do
        Path.expand(layout_template, Path.dirname(__CALLER__.file))
      end

    arguments = Enum.map(arguments, fn a when is_atom(a) -> {a, [line: 1], nil} end)

    compiled_page = EEx.compile_file(page_template, engine: EEx.HTMLEngine)

    # This step would not be necessary if the compiler could return a wrapped value.
    safe_compiled_page =
      quote do
        EEx.HTML.raw(unquote(compiled_page))
      end

    compiled_layout =
      if layout_template do
        EEx.compile_file(layout_template, engine: EEx.HTMLEngine)
      else
        {:__content__, [], nil}
      end

    {compiled, has_page?} =
      Macro.prewalk(compiled_layout, false, fn
        {:__content__, _opts, nil}, _acc ->
          {safe_compiled_page, true}

        ast, acc ->
          {ast, acc}
      end)

    if !has_page? do
      raise ArgumentError, "Layout missing content, add `<%= __content__ %>` to template"
    end

    quote do
      import EEx.HTML, only: [raw: 1]

      if unquote(layout_template) do
        @external_resource unquote(layout_template)
        @file unquote(layout_template)
      end

      @external_resource unquote(page_template)
      @file unquote(page_template)
      def render(request, unquote_splicing(arguments)) do
        request
        |> Raxx.set_header("content-type", "text/html")
        # FIXME when Raxx works through with iodata
        |> Raxx.set_body("#{html(unquote_splicing(arguments)).data}")
      end

      def html(unquote_splicing(arguments)) do
        EEx.HTML.raw(unquote(compiled))
      end
    end
  end

  @doc false
  def template_for(file) do
    case String.split(file, ~r/\.ex(s)?$/) do
      [path_and_name, ""] ->
        path_and_name <> ".html.eex"

      _ ->
        raise "#{__MODULE__} needs to be used from a `.ex` or `.exs` file"
    end
  end
end
