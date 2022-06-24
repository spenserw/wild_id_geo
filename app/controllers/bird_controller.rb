class BirdController < ApplicationController
  require 'cgi'

  # TODO 4-2-2022: Add season querying
  def presence
    state_fips = params[:state]
    county_fips = params[:county]
    species = params[:species]
    family = params[:family]
    seasons = params[:seasons]
    origin = params[:origin]
    puts "Birds query: #{params}"

    species_slice = BirdSpecies.all
    if params[:family]
      id = BirdFamily.find_by(scientific_name: family)
      species_slice = BirdSpecies.where(bird_family_id: id)
    end

    # DEV: Family filter takes precedence? Species search with wildcard appended
    species_slice = species_slice.where("scientific_name LIKE '#{species}%'") if species

    seasons = %w[resident breeding nonbreeding passage] unless seasons || seasons&.length

    # Default origin value (Native, Introduced)
    origin ||= [1, 3]
    # Convert to array for JSONB query
    origin = [origin.to_i] unless origin.is_a?(Array)

    # No location provided
    if county_fips == '0' && state_fips == '0'
      render json: species_slice.get_species(seasons, origin)
    elsif county_fips != '0'
      render json: species_slice.get_species_in_county(state_fips, county_fips, seasons, origin)
    else
      render json: species_slice.get_species_in_state(state_fips, seasons, origin)
    end
  end

  def distribution
    sci_name = CGI.unescape(params[:sci_name])
    species = BirdSpecies.find_by(scientific_name: sci_name)
    render json: species.distribution
  end
end
