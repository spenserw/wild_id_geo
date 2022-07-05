require 'set'

class BirdSpecies < ApplicationRecord
  belongs_to :bird_family

  module Season
    RESIDENT = 1
    BREEDING = 2
    NONBREEDING = 3
    PASSAGE = 4
    UNCERTAIN = 5
  end

  module Origin
    NATIVE = 1
    INTRODUCED = 3
  end

  # Transform list of species to an organized object by families
  def self.compose(species)
    resp = {}

    # Fetch families in bulk
    family_ids = Set[]
    species.each_pair do |_, s|
      family_ids.add(s[:family_id])
    end
    families = BirdFamily.compose(BirdFamily.where(id: family_ids.to_a))

    species.each_pair do |_, s|
      family = families[s[:family_id]]
      family_name = family[:scientific_name]
      resp[family_name] = { 'species' => {} } unless resp[family_name]
      resp[family_name]['species'][s[:scientific_name]] ||= { seasons: s['seasons'], origin: s[:origin] }
    end

    resp
  end

  # Get seasonal presence based on a given json path in the distribution data.
  # <distribution_path> example: distribution->'resident'->'35'->'039' Resident distribution for Rio Arriba County, NM
  def self.get_species_seasonsal_presence(seasons, origin, path = '')
    present_species = {}
    seasons.each do |season|
      species = nil
      # Are we querying a location, or overall distribution?
      if !path.empty?
        distribution_path = "distribution->'#{season}'->#{path}"
        origin_path = "#{distribution_path}->'origin'"
        species = BirdSpecies.where("#{distribution_path} IS NOT NULL AND #{origin_path} <@ '#{origin}'::jsonb")
                             .select(:scientific_name, :bird_family_id, "#{origin_path} AS origin")
      else
        species = BirdSpecies.where("distribution->'#{season}' ? 'origin'")
                             .select(:scientific_name, :bird_family_id, "distribution->'#{season}'->'origin' AS origin")
      end

      species.each do |s|
        name = s.scientific_name.to_s
        present_species[name] ||= { "scientific_name": name, "family_id": s.bird_family_id, origin: s.origin }
        if !present_species[name]['seasons']
          present_species[name]['seasons'] = [season]
        else
          present_species[name]['seasons'].push(season)
        end
      end
    end

    present_species
  end

  # Get seasonal presence in full coverage
  def self.get_species(seasons, origin)
    present_species = get_species_seasonsal_presence(seasons, origin)
    compose(present_species)
  end

  # Get seasonal presence for a given state
  def self.get_species_in_state(state_fips, seasons, origin)
    present_species = get_species_seasonsal_presence(seasons, origin, "'#{state_fips}'")
    compose(present_species)
  end

  # Get seasonal presence for a given county
  def self.get_species_in_county(state_fips, county_fips, seasons, origin)
    present_species = get_species_seasonsal_presence(seasons, origin, "'#{state_fips}'->'#{county_fips}'")
    compose(present_species)
  end
end
