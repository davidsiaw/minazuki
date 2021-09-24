# frozen_string_literal: true

require 'minazuki'

dsl = Minazuki::DSL.new
dsl.instance_eval do
  resource_class :create_artist_command, writable: true do
    field :name, type: :string, writable: true
    field :status, type: :string

    on_create do |x|
      if (x.name.start_with?('david'))
        return
      end
      Artist.create!(name: x.name)
    end
  end

  resource_class :artist do
    field :name, type: :string
  end

end

gen = Minazuki::Generator.new dsl
gen.prepare_program! if ENV['REBUILD']
gen.generate

return

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
    docker-compose up --build -d
    docker logs -f rails
    docker-compose  down -v
  START
end
  # resource_class :band do
  #   field :name, type: :string
  #   # has_many :artist
  # end

  # resource_class :artist do
  #   field :name, type: :string
  # end

  # resource_class :album do
  #   field :name, type: :string
  #   # has_many :song
  # end

  # resource_class :song do
  #   field :name, type: :string
  #   field :url, type: :string
  #   field :length_seconds, type: :integer
  #   # has_many :artist

  #   collection :lyric do
  #     field :timestamp_seconds, type: :integer

  #     collection :line do
  #       field :content, type: :string
  #       field :lang_code, type: :string

  #       collection :annotation do
  #         field :content, type: :string
  #         field :tag, type: :string
  #       end
  #     end
  #   end
  # end

  # resource_class :derivation, extends: :song do
  #   field :original, type: :song
  # end

  # resource_class :remix, extends: :derivation do
  # end

  # resource_class :cover, extends: :derivation do
  # end

  # resource_class :instrumental, extends: :derivation do
  # end

  # resource_class :arrange, extends: :derivation do
  # end























