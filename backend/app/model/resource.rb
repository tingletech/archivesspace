class Resource < Sequel::Model(:resources)
  plugin :validation_helpers
  include ASModel
  include Identifiers
  include Subjects


  def link(opts)
    child = ArchivalObject.get_or_die(opts[:child])
    child.resource_id = self.id
    child.parent_id = opts[:parent]
    child.save
  end


  def assemble_tree(node, links, properties)
    result = properties[node]

    result[:archival_object] = JSONModel(:archival_object).uri_for(result[:id],
                                                                   :repo_id => self.repo_id)
    result.delete(:id)

    if links[node]
      result[:children] = links[node].map do |child_id|
        assemble_tree(child_id, links, properties)
      end
    else
      result[:children] = []
    end

    result
  end


  def tree
    links = {}
    properties = {}

    root_node = nil
    ArchivalObject.filter(:resource_id => self.id).each do |ao|
      if ao.parent_id
        links[ao.parent_id] ||= []
        links[ao.parent_id] << ao.id
      else
        root_node = ao.id
      end

      properties[ao.id] = {:title => ao.title, :id => ao.id}
    end

    # Check for empty tree
    return nil if root_node.nil?

    assemble_tree(root_node, links, properties)
  end


  def update_tree(tree)
    Resource.db[:archival_objects].
             filter(:resource_id => self.id).
             update(:parent_id => nil)

    # The root node has a null parent
    self.link(:parent => nil,
              :child => JSONModel(:archival_object).id_for(tree["archival_object"],
                                                           :repo_id => self.repo_id))

    nodes = [tree]
    while not nodes.empty?
      parent = nodes.pop

      parent_id = JSONModel(:archival_object).id_for(parent["archival_object"],
                                                     :repo_id => self.repo_id)

      parent["children"].each do |child|
        child_id = JSONModel(:archival_object).id_for(child["archival_object"],
                                                      :repo_id => self.repo_id)

        self.link(:parent => parent_id, :child => child_id)
        nodes.push(child)
      end
    end
  end


end
