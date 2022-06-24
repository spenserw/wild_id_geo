# frozen_string_literal: true

require 'json'
require 'csv'

# DEV: Experiments with possible internal ID generation
# def generate_id(genus, spec_epi)
#   return genus[..3].upcase + spec_epi[..3].upcase
# end

# def gen_genus_id(genus)
#   return genus[..5].upcase
# end

# def test_ids_for_dupes()
#   ids = {}
#   taxon_rows = CSV.read("./taxonomy.csv", headers: true)
#   taxon_rows.each do |row|
#     sci_name = row["ScientificName"].split
#     if(sci_name.length > 2) then
#       puts "ERROR: Subspecies/variant found. [#{sci_name}]"
#       exit
#     end

#     id = gen_genus_id(sci_name[0])
#     if not ids[id] then
#       ids[id] = sci_name[0]
#     elsif ids[id] != sci_name[0] then
#       puts "Duplicate genus id [#{id}] for [#{sci_name[0]}] & [#{ids[id]}]!"
#       exit
#     end
#     # else
#     #   puts "ERROR: Duplicate id [#{id}]! Count: #{ids.keys.length}"
#     #   exit
#     # end
#   end
# end

# TODO: Make extraction respect --force
def extract_birdlife_source
  data_dir = File.join(File.dirname(__FILE__), 'data')
  esri_archive = File.join(File.dirname(__FILE__), 'BOTW.7z')
  esri_db_path = File.join(data_dir, 'BOTW.gdb')

  birdlife_taxon_table = 'birdlife_taxonomy'
  birdlife_distribution_table = 'birdlife_distributions'

  if !Dir.exist?(esri_db_path)
    `7z x -o#{data_dir} #{esri_archive}`
  else
    # If we've already extracted, skip this step.
    puts('Birdlife already extracted, skipping. Use --force to override...')
  end

  ogr2ogr_cmd = Rails.configuration.x.datasets[:constants][:OGR2OGR_CMD]
  pg_db = Rails.configuration.database_configuration[Rails.env]
  pg_db_name = pg_db['database']
  pg_db_user = pg_db['username']
  pg_conn = "dbname='#{pg_db_name}' user='#{pg_db_user}'"
  # Extract taxonomic checklist (contains db specific IDs)
  if !ActiveRecord::Base.connection.data_source_exists? birdlife_taxon_table
    `#{ogr2ogr_cmd} PG:"#{pg_conn}" #{esri_db_path} -nln #{birdlife_taxon_table} BirdLife_Taxonomic_Checklist_V5`
  else
    puts('Birdlife taxonomy already exported, skipping. Use --force to override...')
  end

  # Extract distribution data ==> Postgres
  if !ActiveRecord::Base.connection.data_source_exists? birdlife_distribution_table
    `#{ogr2ogr_cmd} PG:"#{pg_conn}" #{esri_db_path} -nln #{birdlife_distribution_table} -nlt 'MULTIPOLYGON' All_Species`
  else
    puts('Birdlife distributions already exported, skipping. Use --force to override...')
  end
end

def generate_all_seasons(species_name)
  dist_data = []
  origin_summation = []

  season = BirdSpecies::Season::RESIDENT
  until season > BirdSpecies::Season::PASSAGE

    # Data has a top-level summary for origin
    data = nil
    [BirdSpecies::Origin::NATIVE, BirdSpecies::Origin::INTRODUCED].each do |origin|
      county_dist = County.bird_species_distribution(species_name, season, origin)

      county_dist.each do |v|
        data ||= { origin: [] }
        data[v.statefp.to_s] ||= { origin: [], "#{v.countyfp}": { origin: [] } }
        data[v.statefp.to_s][v.countyfp.to_s] ||= { origin: [] }

        # Push origin to overall distribution, seasonal level, state level & county level
        origin_summation.push(origin) unless origin_summation.include?(origin)
        data[:origin].push(origin) unless data[:origin].include?(origin)
        data[v.statefp.to_s][:origin].push(origin) unless data[v.statefp.to_s][:origin].include?(origin)
        data[v.statefp.to_s][v.countyfp.to_s][:origin].push(origin)
      end
    end

    dist_data[season - 1] = data

    season += 1
  end

  {
    origin: origin_summation,
    resident: dist_data[0],
    breeding: dist_data[1],
    nonbreeding: dist_data[2],
    passage: dist_data[3]
  }
end

def write_output(name, data)
  # sub whitespace with '_'
  filename = "#{name.gsub(/[^\w.]/, '_').downcase}.json"
  File.write("#{File.dirname(__FILE__)}/#{filename}", data)
end

def build_county_distribution
  json = JSON.generate(generate_all_seasons(ARGV[0]))
  write_output(ARGV[0], json)
end

def filter_us_species_taxa
  us_species = BirdSpeciesDistribution.species_in_boundary('us50')
  data = {
    'species' => {},
    'families' => {},
    'count' => 0
  }

  us_species.each do |s|
    species_tax = BirdSpeciesTaxonomy.find_by(sisrecid: s.sisid)
    family = species_tax.familyname
    sci_name = species_tax.scientificname

    species = {
      'scientific_name' => sci_name,
      'common_name' => species_tax.commonname
    }

    if !data['species'][family]
      data['species'][family] = { sci_name => species }
      data['families'][family] = {
        'common_name' => species_tax.family,
        'count' => 1
      }
      data['count'] += 1
    elsif !data['species'][family][sci_name]
      data['species'][family][sci_name] = species
      data['families'][family]['count'] += 1
      data['count'] += 1
    end
  end

  data
end

def whitelist_us_species_taxa
  if File.exist?(File.join(File.dirname(__FILE__), 'whitelisted_taxa.json'))
    puts("File 'whitelist_taxa.json' already present, skipping generation...")
    return
  end

  family_whitelist = %w[Accipitridae Strigidae]

  taxa = filter_us_species_taxa
  whitelisted_taxa = {
    'species' => {},
    'families' => {},
    'count' => 0
  }
  taxa['species'].each do |k, v|
    whitelisted_taxa['species'][k] = v if family_whitelist.include?(k)
  end

  taxa['families'].each do |k, v|
    whitelisted_taxa['families'][k] = v if family_whitelist.include?(k)
  end

  whitelisted_taxa['count'] = whitelisted_taxa['families'].keys.length
  write_output('whitelisted_taxa', JSON.pretty_generate(whitelisted_taxa))
end

def output_us_species_taxa
  if File.exist?(File.join(File.dirname(__FILE__), 'us_taxa.json'))
    puts('File \'us_taxa.json\' already present, skipping generation...')
    return
  end

  puts 'Generating US taxonomy...'
  data = filter_us_species_taxa
  write_output('us_taxa', JSON.pretty_generate(data))
end

def load_taxon_dump
  file = File.open(File.join(File.dirname(__FILE__), 'us_taxa.json'))
  JSON.parse(file.read)
end

def delete_existing_data
  BirdSpecies.destroy_all
  BirdFamily.destroy_all
end

# DEV: Families must be populated prior to species
def populate_us_bird_families
  puts 'Importing bird families...'
  taxa = load_taxon_dump
  puts 'Loaded taxon dump...'
  taxa['families'].each do |k, v|
    family = BirdFamily.new do |f|
      f.scientific_name = k
      f.common_names = [v['common_name']]
      f.species_count = v['count']
    end
    family.save!
  end

  puts 'Bird families imported.'
end

def populate_us_bird_species
  puts 'Importing bird species...'
  taxa = load_taxon_dump
  taxa['species'].each do |family_name, species|
    species.each do |_, v|
      sci_name = v['scientific_name']
      puts "Importing species [#{sci_name}]..."
      taxonomy = BirdSpeciesTaxonomy.find_by(scientificname: sci_name)
      dist_data = generate_all_seasons(sci_name)
      new_species = BirdSpecies.new do |s|
        s.external_id = taxonomy.sisrecid
        s.scientific_name = sci_name
        s.common_names = [v['common_name']]
        s.distribution = dist_data

        s.bird_family = BirdFamily.find_by(scientific_name: family_name)
      end
      new_species.save!
      puts "Imported species [#{sci_name}]"
    end
  end

  puts 'Bird species imported.'
end

extract_birdlife_source
delete_existing_data
output_us_species_taxa
populate_us_bird_families
populate_us_bird_species
