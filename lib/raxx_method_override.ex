defmodule Raxx.MethodOverride do
  @moduledoc """
  Allows browser submitted forms to use HTTP verbs other than `POST`.

  Only the `POST` method can be overridden,
  It can be overridden to use any of these HTTP verbs.

  - `PUT`
  - `PATCH`
  - `DELETE`

  Should the field be customisable? `_method` as default.
  Should it ever error for bad requests.
  """

  @doc """
  Edits the request method based on the request body
  """
  def override_method(request = %{method: :POST, body: form}) do
    case Map.pop(form, "_method") do
      {method, form} ->
        %{request | method: String.to_atom(method)}
    end
  end
end