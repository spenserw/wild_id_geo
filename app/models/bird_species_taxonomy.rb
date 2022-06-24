class BirdSpeciesTaxonomy < ApplicationRecord
  self.table_name = 'birdlife_taxonomy'
  self.primary_key = 'objectid'
end
