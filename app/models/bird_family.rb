class BirdFamily < ApplicationRecord
  has_many :bird_species, class_name: 'BirdSpecies'

  def self.compose(families)
    resp = {}
    families.each do |family|
      id = family[:id]
      resp[id] = { id: id, scientific_name: family[:scientific_name] }
    end

    resp
  end
end
