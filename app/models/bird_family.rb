class BirdFamily < ApplicationRecord
  has_many :bird_species, class_name: 'BirdSpecies'
end
