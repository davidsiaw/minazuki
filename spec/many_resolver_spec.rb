require_relative '../lib/minazuki'

describe ManyResolver do
  it 'builds one to many' do
    dsl = DSL.new
    dsl.instance_eval do
      resource_class :name do
      end

      resource_class :thing do
        has_many :name
      end
    end

    mr = ManyResolver.new
    dsl.resources.each do |rname, r|
      mr.add(rname, r)
    end

    expect(mr.has_many_of(:thing)).to eq([:name])
    expect(mr.has_many_of(:name)).to eq([])
  end

  it 'builds many to many' do
    dsl = DSL.new
    dsl.instance_eval do
      resource_class :name do
        has_many :thing
      end

      resource_class :thing do
        has_many :name
      end
    end

    mr = ManyResolver.new
    dsl.resources.each do |rname, r|
      mr.add(rname, r)
    end

    expect(mr.has_many_of(:thing)).to eq([:name_thing])
    expect(mr.has_many_of(:name)).to eq([:name_thing])
    expect(mr.mapping_tables[:name_thing]).to match_array(%i[name thing])
  end
end
