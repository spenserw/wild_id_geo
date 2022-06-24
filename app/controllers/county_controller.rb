class CountyController < ApplicationController
  def all
    counties = County.compose_minimal(County.all)
    render json: counties
  end

  def for_state
    state_fips_code = params[:id]
    counties = County.compose_minimal(County.where(statefp: state_fips_code))
    render json: counties
  end
end
