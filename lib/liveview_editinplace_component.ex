defmodule LiveviewEditinplace.Component do
  @moduledoc false

  use Phoenix.LiveComponent

  @form_options [name: :eip, as: "eip"]

  # def render(assigns) do
  #   ~H"""
  #   <div>
  #     <%= if @editinplace_edit_id == @id do %>
  #       <div style="width: 300px">
  #         <.simple_form for={@form} phx-value-id={@id} phx-submit="save" phx-target={@myself}>
  #           <.input field={@form[:value]} phx-hook="setFocus"/>
  #           <.input type="hidden" field={@form[:id]}/>
  #           <:actions>
  #             <.button>Save</.button>
  #             <.button type="button" phx-click="cancel" phx-target={@myself}>Cancel</.button>
  #           </:actions>
  #         </.simple_form>
  #       </div>
  #     <%= else %>
  #       <span id={"editinplace-#{@id}"} phx-target={@myself} style="border-bottom: 1px dashed blue;" phx-click="eip-start">
  #         <%= @value %>
  #       </span>
  #     <% end %>
  #   </div>
  #   """
  # end

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:editinplace_edit_id, nil)}
  end

  def handle_event("eip-start", _params, %{assigns: %{id: id, value: value}} = socket) do
    changeset = changeset(%{id: id, value: value})

    {:noreply,
      socket
      |> assign(:editinplace_edit_id, id)
      |> assign(:form, to_form(changeset, @form_options))}
  end

  def handle_event("save", %{"eip" => %{"id" => id, "value" => value}}, socket) do
    changeset = changeset(%{id: id, value: value})

    case socket.assigns.execute.(id, value) do
      {:ok, value} ->
        {:noreply,
         socket
         |> assign(:editinplace_edit_id, nil)
         |> assign(:value, value)
         |> assign(:form, to_form(changeset, @form_options))}

      {:error, message} ->
        {:error, changeset} =
          changeset
          |> add_error(message)
          |> Ecto.Changeset.apply_action(:update)

        {:noreply,
         socket
         |> assign(:form, to_form(changeset, @form_options))}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply,
      socket
      |> assign(:editinplace_edit_id, nil)
      |> assign(:form, nil)}
  end

  def button(assigns), do: apply(core_component_module(), :button, [assigns])
  def input(assigns), do: apply(core_component_module(), :input, [assigns])
  def simple_form(assigns), do: apply(core_component_module(), :simple_form, [assigns])

  defp core_component_module, do: Application.get_env(:liveview_editinplace, :core_component)

  defp changeset(params) do
    data = %{id: params.id, value: nil}
    types = %{value: :string}

    Ecto.Changeset.cast({data, types}, params, Map.keys(types))
  end

  defp add_error(changeset, error) when is_binary(error), do: Ecto.Changeset.add_error(changeset, :value, error)

  defp add_error(changeset, errors) when is_list(errors) do
    errors
    |> Enum.map(fn {_key, {msg, opts}} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.reverse()
    |> Enum.reduce(changeset, fn error, changeset ->
      add_error(changeset, error)
    end)
  end
end
