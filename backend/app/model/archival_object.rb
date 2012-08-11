class ArchivalObject < Sequel::Model(:archival_objects)
  plugin :validation_helpers
  include ASModel
#  include Identifiers

  def children
    ArchivalObject.db[:collection_tree].
                   filter(:parent_id => self.id).
                   select(:child_id).map do |child_id|
      ArchivalObject[child_id[:child_id]]
    end
  end

  
  def validate
    # RefID must be unique within a collection
    refcount = ArchivalObject.db[:archival_objects].
                              join(:collection_tree, :child_id => :id).
                              where(:ref_id=>@values[:ref_id]).count
    super
    errors.add(:ref_id, 'cannot already exist in this collection') if refcount > 0
  
  end
end
