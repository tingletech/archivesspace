class Resource < JSONModel(:resource)

  def initialize(values)
    super

    if !self.extents || self.extents.empty?
      self.extents = [JSONModel(:extent).new._always_valid!]
    end

    self
  end


  def populate_from_accession(accession)
    values = accession.to_hash(true)

    # Recursively remove bits that don't make sense to copy (like "lock_version"
    # properties)
    values = JSONSchemaUtils.map_hash_with_schema(values, JSONModel(:accession).schema,
                                                        [proc { |hash, schema|
                                                          hash = hash.clone
                                                          hash.delete_if {|k, v| k.to_s =~ /^(id_[0-9]|lock_version)$/}
                                                          hash
                                                        }])

    notes ||= []

    if accession.content_description
      notes << JSONModel(:note_multipart).from_hash(:type => "Scope and Contents",
                                                    :label => I18n.t('accession.content_description'),
                                                    :content => accession.content_description)
    end

    if accession.condition_description
      notes << JSONModel(:note_singlepart).from_hash(:type => "General Physical Description",
                                                     :label => I18n.t('accession.condition_description'),
                                                     :content => accession.condition_description)
    end

    self.related_accessions = [{'ref' => accession.uri, '_resolved' => accession}]

    self.notes = notes

    self.update(values)

    if !self.extents || self.extents.empty?
      self.extents = [JSONModel(:extent).new._always_valid!]
    end
  end


end
