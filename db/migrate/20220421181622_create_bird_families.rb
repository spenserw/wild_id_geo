class CreateBirdFamilies < ActiveRecord::Migration[7.0]
  def change
    create_table :bird_families do |t|
      t.string :scientific_name
      t.string :common_names, array: true
      t.integer :species_count

      t.timestamps
    end
  end
end
