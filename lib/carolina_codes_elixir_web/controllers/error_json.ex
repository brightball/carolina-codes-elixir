defmodule CarolinaCodesElixirWeb.ErrorJSON do
  @moduledoc false

  def render("404.json", _assigns) do
    %{"error" => "not_found"}
  end

  def render(template, _assigns) do
    %{"error" => Phoenix.Controller.status_message_from_template(template)}
  end
end
