class ArchivalObject < Sequel::Model(:archival_objects)
  plugin :validation_helpers
  include ASModel

  many_to_many :subjects

  def children
    ArchivalObject.filter(:parent_id => self.id)
  end


  def self.apply_subjects(ao, json, opts)
    ao.remove_all_subjects

    (json.subjects or []).each do |subject|
      ao.add_subject(Subject[JSONModel(:subject).id_for(subject)])
    end
  end


  def self.set_collection(json, opts)
    opts["collection_id"] = nil
    opts["parent_id"] = nil

    if json.collection
      opts["collection_id"] = JSONModel::parse_reference(json.collection, opts)[:id]

      if json.parent
        opts["parent_id"] = JSONModel::parse_reference(json.parent, opts)[:id]
      end
    end
  end


  def self.create_from_json(json, opts = {})
    set_collection(json, opts)
    obj = super(json, opts)
    apply_subjects(obj, json, opts)
    obj
  end


  def update_from_json(json, opts = {})
    self.class.set_collection(json, opts)
    obj = super(json, opts)
    self.class.apply_subjects(obj, json, {})
    obj
  end


  def self.to_jsonmodel(obj, type)
    if obj.is_a? Integer
      # An ID.  Get the Sequel row for it.
      obj = get_or_die(obj)
    end

    json = super(obj, type)
    json.subjects = obj.subjects.map {|subject| JSONModel(:subject).uri_for(subject.id)}
    json
  end


  def validate
    validates_unique([:collection_id, :ref_id],
                     :message => "An Archival Object Ref ID must be unique to its collection")
    super
  end

end
