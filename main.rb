# frozen_string_literal: true

require 'active_support/inflector'
require 'date'
require 'fileutils'
require 'erubis'
require 'bunny/tsort'

# Global generator
class GlobalGenerator
  attr_reader :resources
  def initialize(file, resources)
    @resources = resources
    @file = file
  end

  def filename
    @file
      .sub(%r{^generators/}, './')
      .sub(/.erb$/, '')
  end
end

# Resource generator
class ResourceGenerator
  attr_reader :name, :resource, :index
  def initialize(file, name, resource, index)
    @name = name
    @resource = resource
    @index = index
    @file = file
  end

  def id_of(index)
    # date = Time.now
    # year = date.year
    # month = date.month.to_s.rjust(2, '0')
    # day = date.day.to_s.rjust(2, '0')
    count = index.to_s.rjust(6, '0')
    "20342034#{count}"
  end

  def filename
    @file
      .sub(%r{^generators/}, './')
      .sub(/.erb$/, '')
      .sub('-id-', id_of(index))
      .sub('-resourcename-plural-', name.to_s.pluralize)
      .sub('-resourcename-', name.to_s)
  end
end

# Expands collections to a nominal class structure
class ResourceExpander
  attr_reader :expanded, :deptree, :owners

  def initialize(resources)
    @resources = resources
    @expanded = {}
    @deptree = {}
    @owners = {}
    expand!
  end

  private

  def expand!
    cur_collections = @resources.dup
    # Expand collections
    loop do
      collections = blow_up(cur_collections)
      break if collections.count.zero?

      cur_collections = collections
    end
  end

  def blow_up(cur_collections)
    collections = {}
    cur_collections.each do |k, r|
      expanded[k] = r
      add_dependencies(k, r)
      r.collections.each do |ck, cr|
        collections[:"#{k}_#{ck}"] = cr
      end
    end
    collections
  end

  def add_dependencies(resource_name, resource)
    @deptree[resource_name] = [] unless @deptree.key? resource_name
    @deptree[resource_name] << resource.parent if resource.parent
    resource.collections.each do |ck, _|
      @owners[:"#{resource_name}_#{ck}"] = resource_name
      @deptree[:"#{resource_name}_#{ck}"] = [resource_name]
    end
  end
end

# generator
class Generator
  def initialize(dsl)
    @dsl = dsl
  end

  def generate
    prepare_program!
    generate_resources!
    generate_globals!
    system 'cd rails-zen && rubocop --auto-correct'
  end

  def basic_types
    %i[string integer boolean]
  end

  def basic?(type)
    basic_types.include? type
  end

  def indexable?(type)
    %i[string integer].include? type
  end

  private

  def expander
    @expander ||= ResourceExpander.new(@dsl.resources)
  end

  # Expand collections
  def expanded_resources
    expander.expanded
  end

  def resource_deptree
    expander.deptree
  end

  def resources_in_order
    @resources_in_order ||= Bunny::Tsort.tsort(resource_deptree)
  end

  def prepare_resources
    result = {}

    # Prepare main resource classes
    resources_in_order.each do |arr|
      arr.each do |resourcename|
        r = expanded_resources[resourcename]
        result[resourcename] = make_prepared_resource(resourcename, r, result)
      end
    end
    { **result }
  end

  def make_prepared_resource(resource_name, resource, result)
    PreparedResourceClass.new(
      resource.fields,
      resource.parent,
      result[resource.parent],
      resource.collections.map { |k, _| [k, { type: :"#{resource_name}_#{k}" }] }.to_h,
      expander.owners[resource_name]
    )
  end

  def resources
    @resources ||= prepare_resources
  end

  def generator_files
    Dir['generators/**/*.erb']
  end

  def general_files
    generator_files.reject { |x| x.include? '-resourcename-' }
  end

  def resource_files
    generator_files.select { |x| x.include? '-resourcename-' }
  end

  def generate_resources!
    resource_files.each do |file|
      template = File.read(file)
      resources.each_with_index do |(name, resource), index|
        generate_file!(template, file, name, resource, index)
      end
    end
  end

  def generate_file!(template, file, name, resource, index)
    generator = Erubis::Eruby.new(template, filename: file)
    rg = ResourceGenerator.new(file, name, resource, index)
    FileUtils.mkdir_p File.dirname(rg.filename)
    result = generator.result(rg.send(:binding)).gsub(/\n\n+/, "\n\n")
    File.write(rg.filename, result)
  end

  def generate_globals!
    general_files.each do |file|
      gen = GlobalGenerator.new(file, resources)
      template = File.read(file)
      generator = Erubis::Eruby.new(template)
      FileUtils.mkdir_p File.dirname(gen.filename)
      File.write(gen.filename, generator.result(gen.send(:binding)))
    end
  end

  def prepare_program!
    repo = ENV['REPO'] || 'git@github.com:davidsiaw/rails-zen'
    `rm -rf rails-zen`
    `git clone #{repo}`
    files = Dir['rails-zen/**/*']
    files.each do |file|
      next unless File.file?(file)

      content = File.read(file)
      content = content.gsub('rails_zen', 'meowery').gsub('RailsZen', 'Meowery')
      File.write(file, content)
    end
  end

  def owners_of(resource)
    result = []
    cur_owner_name = resource.owner
    loop do
      break if cur_owner_name.nil?

      result << cur_owner_name
      cur_owner_name = @resources[cur_owner_name].owner
    end
    result
  end

  def base_owners_of(resource)
    arr = owners_of(resource)
    arr.count.times do |index|
      word = arr[-1 - index]
      (arr.count - index - 1).times do |i|
        arr[i] = arr[i].to_s[word.length + 1..-1].to_sym
      end
    end
    arr
  end
end

# resource used for generation
class PreparedResourceClass
  attr_reader :fields,
              :parent_name,
              :parent_resource,
              :collections,
              :owner

  def initialize(fields,
                 parent_name = nil,
                 parent_resource = nil,
                 collections = {},
                 owner = nil)
    @fields = fields
    @parent_name = parent_name
    @parent_resource = parent_resource
    @collections = collections
    @owner = owner
  end

  def parent_fields
    @parent_fields ||= compile_fields
  end

  private

  def compile_fields
    return [] if @parent_name.nil?

    result = {}
    result[parent_name] = parent_resource.fields.dup
    parent_resource.parent_fields.each do |_gparent_name, gparent_fields|
      result[parent_name].merge! gparent_fields
    end
    result
  end
end

# resource
class ResourceClass
  attr_reader :fields, :parent, :collections

  def initialize(parent_class:)
    @fields = {}
    @parent = parent_class
    @collections = {}
  end

  private

  def field(name, options = {})
    raise 'fields cannot start with underscore' if name.to_s.start_with?('_')

    @fields[name] = options
  end

  def collection(name, &block)
    crc = ResourceClass.new(parent_class: nil)
    crc.instance_eval(&block)
    @collections[name] = crc
  end
end

# meow
class DSL
  attr_reader :resources

  def initialize
    @resources = {}
  end

  private

  def resource_class(name, extends: nil, &block)
    rc = ResourceClass.new(parent_class: extends)
    rc.instance_eval(&block)
    @resources[name] = rc
  end
end

dsl = DSL.new
dsl.instance_eval do
  resource_class :band do
    field :name, type: :string
    # has_many :artist
  end

  resource_class :artist do
    field :name, type: :string
  end

  resource_class :album do
    field :name, type: :string
    # has_many :song
  end

  resource_class :song do
    field :name, type: :string
    field :url, type: :string
    field :length_seconds, type: :integer
    # has_many :artist

    collection :lyric do
      field :timestamp_seconds, type: :integer

      collection :line do
        field :content, type: :string
        field :lang_code, type: :string

        collection :annotation do
          field :content, type: :string
          field :tag, type: :string
        end
      end
    end
  end

  resource_class :derivation, extends: :song do
    field :original, type: :song
  end

  resource_class :remix, extends: :derivation do
  end

  resource_class :cover, extends: :derivation do
  end

  resource_class :instrumental, extends: :derivation do
  end

  resource_class :arrange, extends: :derivation do
  end
end

gen = Generator.new dsl
gen.generate

if ENV['REPO']
  exec <<~START
    cd rails-zen
    bundle install
    ls
    docker-compose -f .circleci/compose-unit.yml up -d
  START
else
  exec <<~START
    cd rails-zen
    docker-compose -f docker-compose.unit.yml up --build -d
    docker logs -f rz
    docker-compose -f docker-compose.unit.yml down -v
  START
end
