require 'psych'
require 'nokogiri'

ASpaceImport::Importer.importer :xml do

  def initialize(opts)

    # TODO:
    # validate(opts[:input_file]) 
    
    hack_input_file_for_nokogiri_exceptions(opts)

    @reader = Nokogiri::XML::Reader(IO.read(opts[:input_file]))
    @regex_cache = {}
    
    @xpath, @depth = "/", 0
    
    # Allow JSON Models to hold some XML info
    ASpaceImport::Crosswalk.models.each do |key, model|
      model.class_eval do
        attr_accessor :depth
        attr_accessor :xpath
      end
    end
    
    # Tell the crosswalk objects when to create record links
    ASpaceImport::Crosswalk.add_link_condition(lambda { |r, json|

      if r.class.xdef['axis'] && r.class.valid_json_types.include?(json.jsonmodel_type)
      
        return Proc.new {|axis, offset|
          if (axis == 'parent' && offset == 1) || \
             (axis == 'ancestor' && offset >= 1) || \
             (axis == 'descendant' && offset <= -1 )
            true
          else
            false
          end
        }.call(r.class.xdef['axis'], r.object.depth - json.depth)      

      else
        # Fall back to testing the other object's source node
        return false unless r.class.xdef['xpath']

        offset = json.depth - r.object.depth
        xpath_regex = regexify_xpath(json.xpath, offset)
        
        # use caching to limit regex matching
        unless r.cache.has_key?(xpath_regex)
          r.cache[xpath_regex] = r.class.xdef['xpath'].find { |xp| xp.match(xpath_regex) } ? true : false
        end
        
        r.cache[xpath_regex]
      end
    })
    
    set_up_tracer if $DEBUG   
      
    super

  end


  def self.profile
    "Imports XML based formats using Nokogiri; requires a crosswalk (YAML)"
  end


  def run  
    @reader.each do |node|

      node.start_trace(xpath(node), node.depth, node.node_type) if $DEBUG

      case node.node_type

      when 1
        handle_opener(node)
      when 3
        handle_text(node)
      else
        handle_closer(node)
      end
    end

    save_all

    $tracer.out(@uri_map) if $DEBUG
     
  end  


  def handle_opener(node)
    
    if object_for_node(node)
    
      with_receivers_for("self") do |r|
        r << node.inner_xml
      end
        
      with_receivers_for("self::name") do |r|
        r << node.name
      end
        
      node.attributes.each do |a|        
        with_receivers_for("@#{a[0]}") do |r|
          r << a[1]
        end                         
      end

    else
      parse_queue.iterate do |json|
        with_receivers_for(xpath(node), node.depth, node.node_type) do |r|
          r << node.inner_xml
        end  
      end
    end
  end
  
  def handle_text(node)
        
    parse_queue.iterate do |json|
      with_receivers_for(xpath(node), node.depth, node.node_type) do |r|
        r << node.value.sub(/[\s\n]*$/, '')
      end  
    end
  end
  
  def handle_closer(node)
    
    return unless object_for_node(node)
    
    parse_queue.last.set_default_properties
    
    # Fill in missing values; add supporting records etc.
    # For instance:
    lambda {|json|
      if ['subject'].include?(json.class.record_type)
    
        @vocab_uri ||= "/vocabularies/#{@vocab_id}"

        json.vocabulary = @vocab_uri
        json.terms.each {|t| t['vocabulary'] = @vocab_uri}
      end
      
    }.call(parse_queue.last)

    parse_queue.pop
  end
  
  def with_receivers_for(*nodeargs)
    
    xpath, depth, ntype = *nodeargs
    return unless xpath
    
    offset = depth ? depth - parse_queue.selected.depth : 0 
    xpath_regex = regexify_xpath(xpath, offset) 

    parse_queue.selected.receivers.each do |r|

      next unless r.class.xdef['xpath']
        
      yield r if r.class.xdef['xpath'].find { |xp| xp.match(xpath_regex) } 
    end
  end
  
  
  def object_for_node(node)

    if (type = get_type_for_node(node))
      if node.node_type == 1
        json = ASpaceImport::Crosswalk.models[type].new

        json.xpath, json.depth = xpath(node), node.depth

        $tracer.trace(:aspace_data, json, nil) if $DEBUG

        parse_queue.push json 
      else
        raise "Record Type mismatch in parse queue" unless parse_queue.last.class.record_type == type
 
        parse_queue.selected
      end
    else
      false
    end
  end
  
  
  def validate(input_file)
    
    # open(input_file).read().match(/xsi:schemaLocation="[^"]*(http[^"]*)"/)
    # 
    # require 'net/http'
    # 
    # uri = URI($1)
    # xsd_file = Net::HTTP.get(uri)
    # 
    # xsd = Nokogiri::XML::Schema(xsd_file)
    # doc = Nokogiri::XML(File.read(input_file))
    # 
    # xsd.validate(doc).each do |error|
    # end
  
  end
  
  
  def get_type_for_node(node)
    regex = regexify_xpath(xpath(node))    
    if (types = ASpaceImport::Crosswalk.entries.map {|k,v| k if v["xpath"] and v["xpath"].find {|x| x.match(regex)}}.compact)
      raise "Too many matched entries" if types.length > 1
      return types[0]
    else
      return nil
    end
  end
  
  # Returns a regex object that is used to match the xpath of a 
  # parsed node with an xpath definition in the crosswalk. In the 
  # case of properties, the offset is the depth of the predicate 
  # node less the depth of the subject node. An offset of nil
  # indicates a root perspective.
  
  def regexify_xpath(xp, offset = nil)
    
    # Slice the xpath based on the offset
    # escape for `text()` nodes
    unless offset.nil? || offset < 1
      xp = xp.scan(/[^\/]+/)[offset*-1..-1].join('/')
      xp.gsub!(/\(\)/, '[(]{1}[)]{1}')
    end
    
    @regex_cache[xp] ||= {}
    
    case offset
      
    when nil
      @regex_cache[xp][offset] ||= Regexp.new "^(/|/" << xp.split("/")[1..-2].map { |n| 
                              "(child::)?(#{n}|\\*)" 
                              }.join('/') << ")" << xp.gsub(/.*\//, '/') << "$"
      
    when 0
      @regex_cache[xp][offset] ||= /^[\/]?#{xp.gsub(/.*\//, '')}$/

    when 1..100
      @regex_cache[xp][offset] ||= Regexp.new "^(descendant::|" << xp.scan(/[a-zA-Z_]+/)[offset*-1..-2].map { |n| 
                              "(child::)?(#{n}|\\*)" 
                              }.join('/') << (offset > 1 ? "/" : "") << "(child::)?)" << xp.gsub(/.*\//, '') << "$"

    
    when -100..-1
      @regex_cache[xp][offset] ||= Regexp.new "^(ancestor::|" << ((offset-1)*-1).times.map {
                                "parent::\\*/"
                                }.join << "parent::)#{xp.gsub(/.*\//, '')}"
    end

    @regex_cache[xp][offset]
    
  end
  
  private
  
  # Builds a full path to the node
  def xpath(node)
    
    name = node.name.gsub(/#text/, "text()")

    if @depth < node.depth
      @xpath.concat("/#{name}")
    elsif @depth == node.depth
      @xpath.sub!(/\/[#()a-z0-9]*$/, "/#{name}")
    elsif @depth > node.depth
      @xpath.sub!(/\/[#()a-z0-9]*\/[#()a-z0-9]*$/, "/#{name}")
    else
      raise "Can't parse node depth to create XPATH"
    end

    @depth = node.depth
    @xpath.clone
  end
  
  # Development / Debugging stuff
  
  def set_up_tracer
    require 'tmpdir'
    $tracer = Tracer.new

    
    Nokogiri::XML::Reader.class_eval do
      alias_method :inner_xml_original, :inner_xml

      def start_trace(*parseargs)
        $tracer.set_node(self, parseargs[0])
      end

      def inner_xml
        $tracer.trace(:inner_xml, inner_xml_original)
        inner_xml_original
      end
          
    end
    
    ASpaceImport::Crosswalk::PropertyReceiver.class_eval do
      alias_method :receive_original, :receive
      
      def receive(val = nil)
        if receive_original(val)
          set_val = @object.send("#{self.class.property}") 
          if set_val.is_a? String
            received_val = @object.send("#{self.class.property}")
          elsif set_val and set_val.is_a? Array
            received_val = @object.send("#{self.class.property}").last
          end

          $tracer.trace(:aspace_data, @object, self.class.property, received_val)
        end
      end
    end
  end

  
  def hack_input_file_for_nokogiri_exceptions(opts)
    
    # Workaround for Nokogiri bug:
    # https://github.com/sparklemotion/nokogiri/pull/805
    
    new_file = File.new(opts[:input_file].gsub(/\.xml/, '_no_xlink.xml'), "w")
    
    File.open opts[:input_file], 'r' do |f|
      f.each_line do |line|
        new_file.puts line.gsub(/\sxlink:href=\".*?\"/, "")
      end
    end
    
    new_file.close
    
    opts[:input_file] = new_file.path
  end

end

class Tracer
  attr_accessor :registry
  
  def initialize(tfile = File.new("#{Dir.tmpdir}/ead-trace.tsv", "w"))
    @file = tfile
    @index, @registry = 0, []
  end
  
  def set_node(node, xpath)
    @index += 1 unless @index == 0 and @registry.length == 0
    @registry[@index] = {
                          :node_type => node.node_type, 
                          :node_value => node.value? ? node.value.sub(/[\s\n]*$/, '') : nil,
                          :xpath => xpath,
                          :aspace_data => [],
                          :inner_xml => []
                        }
  end

  
  def trace(key, *j, val)
    json, prop = j

    val = sanitize(val)

    if json and json.class.method_defined? :uri
      ref = prop ? "#{json.uri}\##{prop}" : "#{json.uri}"
    elsif json
      ref = prop ? "#{json.class.to_s}\##{prop}" : "#{json.class.to_s}"
    end

    if key == :aspace_data
      @registry[@index][key] << [ref, val]
    else
      @registry[@index][key] << val
    end
  end
  
  def sanitize(val)

    return if val.nil? 
    return val if val.is_a?(Hash)

    if val.class.method_defined? :uri
      val = val.uri
    end

    val.gsub!(/^\s*/, '')
    val.gsub!(/\s*$/, '')
    val.gsub!(/[\t\n\r]/, '')

    val
  end
  
  def out(map = {})
    @file.write(%w(00000 NODE.TYPE XPATH NODE.XML NODE.TEXT ASPACE.REF ASPACE.VAL).join("\t").concat("\n"))
    @registry.each_with_index do |l, i|

      [1, l[:aspace_data].length].max.times do |j|
        
        if l[:aspace_data][j].is_a?(Array)
          aspace_data = "#{l[:aspace_data][j][0]}\t#{l[:aspace_data][j][1]}"
        else
          aspace_data = "\t"
        end
        
        if j == 0
          line = "#{'%05d' % i}-#{j}\t#{l[:node_type]}\t#{l[:xpath]}\t#{l[:inner_xml][j]}\t#{l[:node_value]}\t#{aspace_data}\n"
        else
          line = "#{'%05d' % i}-#{j}\t\t\t#{l[:inner_xml][j]}\t\t#{aspace_data}\n"
        end
        map.each do |posted_uri, actual_uri|
          line.gsub!(posted_uri, actual_uri)
        end
      
        @file.write(line)
      end
    end
  end 
end   

