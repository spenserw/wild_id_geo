class CreateBirdSpecies < ActiveRecord::Migration[7.0]
  def change
    create_table :bird_species do |t|
      t.string :external_id, limit: 12, null: false
      t.string :scientific_name, null: false
      t.string :common_names, array: true, null: false
      t.jsonb :distribution
      t.references :bird_family, foreign_key: true

      t.timestamps
    end
  end
end
