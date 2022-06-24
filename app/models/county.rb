class County < ApplicationRecord
  self.primary_key = 'gid'

  def self.compose_minimal(counties)
    counties = counties.select(:statefp, :countyfp, :name)
    data = {}
    counties.each do |county|
      state_key = county.statefp.to_s
      data[state_key] = [] unless data[state_key]
      data[state_key].push({ fips_code: county.countyfp, name: county.name })
    end

    data
  end

  # DEV: See `wid/issues/2`
  def self.bird_species_distribution(sci_name, season, origin = 1)
    County.where("ST_Intersects(counties.wkb_geometry,
                    (SELECT shape FROM birdlife_distributions
                            WHERE binomial = '#{sci_name}'
                            AND seasonal = #{season}
                            AND origin = #{origin}
                            AND presence = 1
                            AND ST_Intersects(birdlife_distributions.shape,
                                (SELECT geometry FROM us_boundary WHERE id = 'us50'))
                            ORDER BY shape_area DESC
                            LIMIT 1))")
  end
end
