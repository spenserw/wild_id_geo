Rails.application.routes.draw do

  get '/counties', to: 'county#all'
  get '/state/:id/counties', to: 'county#for_state'

  get '/birds/presence', to: 'bird#presence'
  get '/birds/:sci_name/distribution', to: 'bird#distribution'

end
