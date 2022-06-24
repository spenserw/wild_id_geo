class BirdSpeciesDistribution < ApplicationRecord
  self.table_name = 'birdlife_distributions'
  self.primary_key = 'objectid'

  def self.species_in_boundary(boundary)
    BirdSpeciesDistribution.where("ST_Intersects(
                                        birdlife_distributions.shape,
                                       (SELECT geometry FROM us_boundary WHERE id = '#{boundary}')
                                       )
                                   AND origin in (1, 3)")
  end
end
