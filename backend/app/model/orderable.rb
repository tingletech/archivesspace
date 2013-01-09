# Mixin methods for objects that belong in an ordered hierarchy (archival
# objects, digital object components)

module Orderable

  def self.included(base)
    base.extend(ClassMethods)
  end


  def set_position_in_list(target_position)
    siblings_ds = self.class.dataset.
                       filter(:root_record_id => self.root_record_id,
                              :parent_id => self.parent_id,
                              ~:position => nil)

    # Find the position of the element we'll be inserted after.  If there are no
    # elements, or if our target position is zero, then we'll get inserted at
    # position zero.
    predecessor = (target_position > 0) && siblings_ds.order(:position).
                                                       limit(target_position).
                                                       select(:position).all

    new_position = (predecessor && !predecessor.empty?) ? (predecessor.last[:position] + 1) : 0

    100.times do
      DB.attempt {
        self.update(:position => new_position)
        self.save
        return
      }.and_if_constraint_fails {
          # Someone's in our spot!  Move everyone out of the way and retry.

          # Sigh.  Work around:
          # http://stackoverflow.com/questions/5403437/atomic-multi-row-update-with-a-unique-constraint

          # Disables the uniqueness constraint
          siblings_ds.
            filter { position >= new_position }.
            update(:parent_name => nil)

          # Do the update we actually wanted
          siblings_ds.
            filter { position >= new_position }.
            update(:position => Sequel.lit('position + 1'))

          # Puts it back again
          siblings_ds.
            filter { position >= new_position }.
            update(:parent_name => self.parent_name)
      }
    end

    raise "Failed to set the position for #{self}"
  end


  def update_from_json(json, opts = {})

    self.class.set_root_record(json, opts)

    opts["position"] = nil
    obj = super

    if json[self.class.root_record_type]

      if !json.position
        json.position = Sequence.get("#{json[self.class.root_record_type]}_#{json.parent}_children_position")
      end

      self.set_position_in_list(json.position)
    end

    obj
  end


  def children
    self.class.filter(:parent_id => self.id).order(:position)
  end


  def has_children?
    self.class.filter(:parent_id => self.id).count > 0
  end



  module ClassMethods

    def orderable_root_record_type(root, node)
      @root_record_type = root.to_s
      @node_record_type = node.to_s
    end

    def root_record_type
      @root_record_type
    end

    def node_record_type
      @node_record_type
    end


    def create_from_json(json, opts = {})
      set_root_record(json, opts)

      if json[root_record_type]
        # This new record is a member of a hierarchy, so add it to the end of its siblings
        json.position = Sequence.get("#{json[root_record_type]}_#{json.parent}_children_position")
      end

      super
    end


    def set_root_record(json, opts)
      opts["root_record_id"] = nil
      opts["parent_id"] = nil
      opts["parent_name"] = nil

      # 'parent_name' is a bit funny.  We need this column because the combination
      # of (parent, position) needs to be unique, to ensure that two siblings
      # don't occupy the same position when ordering them.  However, parent_id can
      # be NULL, meaning that the current node is at the top level of the tree.
      # This prevents the uniqueness check for working against top-level elements.
      #
      # So, parent_name gets used as a stand in in this case: it always has a
      # value for any node belonging to a hierarchy, and this value gets used in
      # the uniqueness check.

      if json[root_record_type]
        opts["root_record_id"] = parse_reference(json[root_record_type], opts)[:id]

        if json.parent
          opts["parent_id"] = parse_reference(json.parent, opts)[:id]
          opts["parent_name"] = opts["parent_id"].to_s
        else
          opts["parent_name"] = "(root)"
        end
      end
    end


    def sequel_to_jsonmodel(obj, opts = {})
      json = super

      if obj.root_record_id
        json[root_record_type] = uri_for(root_record_type, obj.root_record_id)

        if obj.parent_id
          json.parent = uri_for(node_record_type, obj.parent_id)
        end
      end

      json
    end


  end

end
