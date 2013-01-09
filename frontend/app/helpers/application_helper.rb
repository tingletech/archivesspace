module ApplicationHelper

  def include_controller_js
    scripts = ""

    scripts += javascript_include_tag "#{controller.controller_name}" if File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.js") ||  File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.js.erb")

    scripts += javascript_include_tag "#{controller.controller_name}.#{controller.action_name}" if File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.#{controller.action_name}.js") ||  File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.#{controller.action_name}.js.erb")

    if ["new", "create", "edit", "update"].include?(controller.action_name)
      scripts += javascript_include_tag "#{controller.controller_name}.crud" if File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.crud.js") ||  File.exists?("#{Rails.root}/app/assets/javascripts/#{controller_name}.crud.js.erb")
    end

    scripts.html_safe
  end

  def include_theme_css
    css = ""
    css += stylesheet_link_tag("themes/#{ArchivesSpace::Application.config.frontend_theme}/bootstrap", :media => "all")
    css += stylesheet_link_tag("themes/#{ArchivesSpace::Application.config.frontend_theme}/application", :media => "all")
    css.html_safe
  end

  def set_title(title)
    @title = title
  end

  def setup_context(options)

    breadcrumb_trail = []

    if options.has_key? :object
      object = options[:object]

      type = options[:type] || object["jsonmodel_type"]
      controller = options[:controller] || type.to_s.pluralize

      title = options[:title] || object["title"] || object["username"]

      breadcrumb_trail.push(["#{I18n.t("#{controller.to_s.singularize}._html.plural")}", {:controller => controller, :action => :index}])

      if object.id
        breadcrumb_trail.push([title, {:controller => controller, :action => :show}])
        breadcrumb_trail.last.last[:id] = object.id unless object['username']

        if ["edit", "update"].include? action_name
          breadcrumb_trail.push([I18n.t("actions.edit")])
          set_title("#{I18n.t("#{type}._html.plural")} | #{title} | #{I18n.t("actions.edit")}")
        else
          set_title("#{I18n.t("#{type}._html.plural")} | #{title}")
        end
      else # new object
        breadcrumb_trail.push([options[:title] || "#{I18n.t("actions.new_prefix")} #{I18n.t("#{type}._html.singular")}"])
        set_title("#{I18n.t("#{controller.to_s.singularize}._html.plural")} | #{options[:title] || I18n.t("actions.new_prefix")}")
      end
    elsif options.has_key? :title
        set_title(options[:title])
        breadcrumb_trail.push([options[:title]])
    end

    render(:partial =>"shared/breadcrumb", :layout => false , :locals => { :trail => breadcrumb_trail }).to_s if options[:suppress_breadcrumb] != true
  end

  def render_token(opts)
    popover = "<div class='btn-group'>"
    popover += "<a href='#{root_path}resolve/readonly?uri=#{opts[:uri]}'"
    popover += " target='_blank'" if opts[:inside_token_editor] || opts[:inside_linker_browse]
    popover += " class='btn btn-mini'>#{I18n.t("actions.view")}</a>"
    popover += "</div>"

    popover_template = "<div class='popover token-popover'><div class='arrow'></div><div class='popover-inner'><div class='popover-content'><p></p></div></div></div>"

    html = "<div class='"
    html += "token " if not opts[:inside_token_editor] 
    html += "#{opts[:type]} has-popover' data-trigger='#{opts[:trigger] || "focus"}' data-html='true' data-placement='bottom' data-content=\"#{CGI.escape_html(popover)}\" data-template=\"#{popover_template}\" tabindex='1'>"
    html += "<span class='icon-token'></span>"
    html += opts[:label]
    html += "</div>"
    html.html_safe
  end

end
