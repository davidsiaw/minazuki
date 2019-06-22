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
      .sub(/^generators/, 'rails-zen')
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
    date = Time.now
    year = date.year
    month = date.month.to_s.rjust(2, '0')
    day = date.day.to_s.rjust(2, '0')
    count = index.to_s.rjust(6, '0')
    "#{year}#{month}#{day}#{count}"
  end

  def filename
    @file
      .sub(/^generators/, 'rails-zen')
      .sub(/.erb$/, '')
      .sub('-id-', id_of(index))
      .sub('-resourcename-plural-', name.to_s.pluralize)
      .sub('-resourcename-', name.to_s)
  end
end

# generator
class Generator
  def initialize(dsl)
    @dsl = dsl
  end

  def generate
    #prepare_program!
    generate_resources!
    generate_globals!
  end

  private

  def resources
    @resources ||= prepare_resources
  end

  def resource_tree
    Bunny::Tsort.tsort(@dsl.resources.map do |k, r|
      [k, r.parents.map { |e| e }.to_a]
    end.to_h)
  end

  def prepare_resources
    result = {}
    resource_tree.each do |arr|
      arr.each do |resourcename|
        r = @dsl.resources[resourcename]
        result[resourcename] = PreparedResourceClass.new(
          r.fields, r.parents.map { |e| [e, result[e]] }.to_h
        )
      end
    end
    result
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
        generator = Erubis::Eruby.new(template)
        rg = ResourceGenerator.new(file, name, resource, index)
        FileUtils.mkdir_p File.dirname(rg.filename)
        File.write(rg.filename, generator.result(rg.send(:binding)))
      end
    end
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
    `rm -rf rails-zen`
    `git clone git@github.com:davidsiaw/rails-zen`
    files = Dir['rails-zen/**/*']
    files.each do |file|
      next unless File.file?(file)

      content = File.read(file)
      content.gsub!('rails_zen', 'meowery')
      content.gsub!('RailsZen', 'Meowery')
      File.write(file, content)
    end
  end
end

# resource used for generation
class PreparedResourceClass
  attr_reader :fields, :parents

  def initialize(fields, parents)
    @fields = fields
    @parents = parents
  end

  def parent_fields
    @parent_fields ||= compile_fields
  end

  def parent_names
    @parents.keys
  end

  private

  def compile_fields
    result = {}
    @parents.each do |parent_name, parent_resource|
      result[parent_name] = parent_resource.fields
      parent_resource.parent_fields.each do |gparent_name, gparent_fields|
        result[parent_name].merge! gparent_fields
      end
    end
    result
  end
end

# resource
class ResourceClass
  attr_reader :fields, :parents

  def initialize
    @fields = {}
    @parents = Set.new
  end

  private

  def field(name, options = {})
    @fields[name] = options
  end

  def extends(resource_class)
    @parents << resource_class
  end
end

# meow
class DSL
  attr_reader :resources

  def initialize
    @resources = {}
  end

  private

  def resource_class(name, &block)
    rc = ResourceClass.new
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

    # collection :alt_name do
    #   field :name, type: :string
    # end
  end

  resource_class :derivation do
    extends :song
    field :original, type: :song
  end

  resource_class :remix do
    extends :derivation
  end

  resource_class :cover do
    extends :derivation
  end

  resource_class :instrumental do
    extends :derivation
  end

  resource_class :arrange do
    extends :derivation
  end
end

gen = Generator.new dsl
gen.generate

exec <<~START
  cd rails-zen &&
  docker-compose -f docker-compose.unit.yml up -d
  docker logs -f rz
  docker-compose -f rails-zen/docker-compose.unit.yml down -v
START
