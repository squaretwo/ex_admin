defmodule ExAdmin.Theme.AdminLte2.Form do
  import Kernel, except: [div: 2]
  import Xain
  import ExAdmin.Utils
  import ExAdmin.ViewHelpers
  import ExAdmin.Form
  require Integer
  require Logger
  import ExAdmin.Helpers
  alias ExAdmin.Schema

  @doc false
  def build_form(conn, resource, items, params, script_block) do
    mode = if params[:id], do: :edit, else: :new
    markup do
      model_name = model_name resource
      action = get_action(conn, resource, mode)
      # scripts = ""
      Xain.form "accept-charset": "UTF-8", action: "#{action}", class: "form-horizontal",
          id: "new_#{model_name}", method: :post, enctype: "multipart/form-data", novalidate: :novalidate  do

        resource = setup_resource(resource, params, model_name)

        build_hidden_block(conn, mode)
        div ".box-body" do
          scripts = build_main_block(conn, resource, model_name, items)
          |> build_scripts
        end
        build_actions_block(conn, model_name, mode)
      end
      put_script_block(scripts)
      put_script_block(script_block)
    end
  end

  def theme_build_inputs(_item, _opts, fun) do
    fun.()
  end

  @doc false
  def theme_wrap_item(_type, ext_name, label, hidden, ajax, error, contents, as) when as in [:check_boxes, :radio] do
    # li([class: "#{as} input optional #{error}stringish", id: "#{ext_name}_input"] ++ hidden) do
Logger.warn "theme wrap item 2. ..."
    div ".form-group", hidden do
      fieldset ".choices" do
        legend ".label" do
          label humanize(label)
        end
        if ajax do
          div "##{ext_name}-update" do
            if hidden == [] do
              contents.(ext_name)
            end
          end
        else
          contents.(ext_name)
        end
      end
    end
  end

  @doc false
  def theme_wrap_item(type, ext_name, label, hidden, ajax, error, contents, as) do
    # Logger.warn ".... ext_name: #{inspect ext_name}, as: #{inspect as}"
    # TODO: Fix this to use the correct type, instead of hard coding string
    # li([class: "string input optional #{error}stringish", id: "#{ext_name}_input"] ++ hidden) do
    Logger.warn "theme wrap item 3. ... #{ext_name}"
    div ".form-group", hidden do
      if ajax do
        label(".col-sm-2.control-label #{humanize label}", for: ext_name)
        div "##{ext_name}-update" do
          if hidden == [] do
            div ".col-sm-10" do
              contents.(ext_name)
            end
          end
        end
      else
        wrap_item_type(type, label, ext_name, contents, error)
      end
    end
  end

  def build_actions_block(conn, model_name, mode) do
    display_name = ExAdmin.Utils.displayable_name_singular conn
    label = if mode == :new, do: "Create", else: "Update"
    div ".box-footer" do
      Xain.input ".btn.btn-primary", name: "commit", type: :submit, value: escape_value("#{label} #{humanize display_name}")
      a(".btn.btn-default.btn-cancel Cancel", href: get_route_path(conn, :index))
    end
  end

  def build_form_error(error) do
    label ".control-label" do
      i ".fa.fa-times-circle-o"
      text " #{ExAdmin.Form.error_messages(error)}"
    end
  end

  def build_inputs_collection(model_name, name, name_ids, fun) do
    div(".form-group") do
      label ".col-sm-2.control-label #{humanize name}", for: "#{model_name}_#{name_ids}"
      div ".col-sm-10" do
        fun.()
      end
    end
  end

  def build_inputs_has_many(field_name, human_label, fun) do
    div ".input" do
      res = fun.()
    end
    res
  end

  def has_many_insert_item(html, new_record_name_var) do
    ~s|$(this).siblings("div.input").append("#{html}".replace(/#{new_record_name_var}/g,| <>
      ~s|new Date().getTime())); return false;|
  end
  def form_box(item, opts, fun) do
    # Logger.warn "item: #{inspect item}, opts: #{inspect opts}"
    div ".box.box-primary" do
      div ".box-header.with-border" do
        h3 ".box-title" do
          text item[:name]
        end
      end
      div ".box-body" do
        fun.()
      end
    end
  end

  # TODO: Refactor some of this back into ExAdmin.Form
  def theme_build_has_many_fieldset(conn, res, fields, orig_inx, ext_name, field_name, field_field_name, model_name, errors) do
    inx = cond do
      is_nil(res) -> orig_inx
      Schema.get_id(res) ->  orig_inx
      true -> timestamp   # case when we have errors. need to remap the inx
    end

    div ".box" do
      div ".box-header.with-border" do
        title = humanize(field_name) |> Inflex.singularize
        h3 ".box-title #{title}"
      end
      div ".box-body" do
      # build the destroy field
      base_name = "#{model_name}[#{field_field_name}][#{inx}]"
      base_id = "#{ext_name}__destroy"
      name = "#{base_name}[_destroy]"
      div [id: "#{base_id}_input", class: "form-group"] do
        div ".col-sm-offset-2" do
          div ".checkbox" do
            Xain.input type: :hidden, value: "0", name: name
            label for: base_id do
              Xain.input type: :checkbox, id: "#{base_id}", name: name, value: "1"
              text "Remove"
            end
          end
        end
      end

      for field <- fields do
        f_name = field[:name]
        name = "#{base_name}[#{f_name}]"
        errors = get_errors(errors, "#{model_name}[#{field_field_name}][#{orig_inx}][#{f_name}]")
        error = if errors in [nil, [], false], do: "", else: ".has-error"
        case field[:opts] do
          %{collection: collection} ->
            if is_function(collection) do
              collection = collection.(conn, res)
            end
            div ".form-group", [id: "#{ext_name}_label_input"] do
              label ".col-sm-2.control-label #{humanize f_name}", for: "#{ext_name}_#{f_name}" # do
                # abbr "*", title: "required"
              # end
              div ".col-sm-10" do
                select "##{ext_name}_#{f_name}#{error}.form-control", [name: name ] do
                  for opt <- collection do
                    if not is_nil(res) and (Map.get(res, f_name) == opt) do
                      option "#{opt}", [value: escape_value(opt), selected: :selected]
                    else
                      option "#{opt}", [value: escape_value(opt)]
                    end
                  end
                end
                build_errors(errors)
              end
            end
          _ ->
            div ".form-group", id: "#{ext_name}_#{f_name}_input"  do
              label ".col-sm-2.control-label #{humanize f_name}", for: "#{ext_name}_#{f_name}" # do
              #   abbr "*", title: "required"
              # end
              div ".col-sm-10#{error}" do
                val = if res, do: [value: Map.get(res, f_name, "") |> escape_value], else: []
                Xain.input([type: :text, maxlength: "255", id: "#{ext_name}_#{f_name}",
                  class: "form-control", name: name] ++ val)
                build_errors(errors)
              end
            end
        end
      end
      unless res do
        div ".form-group" do
          a ".btn.btn-default Delete", href: "#",
            onclick: ~S|$(this).closest(\".has_many_fields\").remove(); return false;|
        end
      end
    end
    end
    inx
  end

  def theme_button(content, attrs) do
    a ".btn#{content}", attrs
  end
end