# frozen_string_literal: true

module GSheets
  require 'google_drive'
  @session = nil
  SPREADSHEET_ID = '1diYxdX2W9mWuhDZ232G-MJ12AjOymHWdxKOjWadZoLo'

  def self.init
    @session ||= GoogleDrive::Session.from_config(File.absolute_path('lib/tasks/curation/.credentials.json'))
    @session
  end

  def self.import_worksheets
    init
    @session.spreadsheet_by_key(SPREADSHEET_ID).worksheets
  end
end

# DEV: Update IDs - these should be constant in production I should think?
def update_ids(worksheet, id_col_index, name_col_index, class_name)
  worksheet_modified = false
  worksheet.rows.each_with_index do |row, index|
    # Skip header
    next if index.zero?

    row_id = row[id_col_index]
    sci_name = row[name_col_index]

    current_id = class_name.find_by(scientific_name: sci_name).id
    if row_id.to_i != current_id
      worksheet_modified ||= true
      worksheet[index + 1, 1] = current_id
    end
  end

  puts "Updating IDs for worksheet: [#{worksheet.title}]" if worksheet_modified
  worksheet_modified
end

# Filter out all species/families that are already present in the worksheet, so we don't produce duplicates
def filter_list(subjects, worksheet, scientific_name_index)
  worksheet.rows[1..].each do |row|
    sci_name = row[scientific_name_index]
    subjects.each_with_index do |s, i|
      if s[:scientific_name] == sci_name
        subjects.delete_at(i)
        break
      end
    end
  end

  subjects
end

def family_to_row(family)
  [family[:id], family[:scientific_name], family[:common_names], family[:species_count]]
end

# Takes a species and transforms it into a row for curation
# Headers are: "ID", "External ID", "Scientific Name", "Common Names", "Family", and "Published"
def species_to_row(species)
  family = BirdFamily.find_by(id: species[:bird_family_id])[:scientific_name]
  [species[:id], species[:external_id], species[:scientific_name], species[:common_names], family, 'false']
end

def populate_curation_worksheet_families(worksheet)
  worksheet_modified = update_ids(worksheet, 0, 1, BirdFamily)

  # Filter & add families that previously weren't present on the spreadsheet
  new_families = filter_list(BirdFamily.all.to_a, worksheet, 1)
  family_rows = []
  new_families.each do |f|
    family_rows.append(family_to_row(f))
  end

  if family_rows.empty?
    puts 'No new families to import...'
  else
    worksheet_modified ||= true
    worksheet.insert_rows(worksheet.num_rows + 1, family_rows)
  end

  worksheet.save if worksheet_modified
end

def populate_curation_worksheet_species(worksheet)
  worksheet_modified = update_ids(worksheet, 0, 2, BirdSpecies)

  species = filter_list(BirdSpecies.all.to_a, worksheet, 2)
  species_rows = []
  species.each do |s|
    species_rows.append(species_to_row(s))
  end

  if species_rows.empty?
    puts 'No new species to import...'
  else
    worksheet_modified ||= true
    worksheet.insert_rows(worksheet.num_rows + 1, species_rows)
  end

  worksheet.save if worksheet_modified
end

namespace :curation do
  desc 'Dump taxonomic information for curation purposes'

  task dump_families: :environment do
    ws = GSheets.import_worksheets
    populate_curation_worksheet_families(ws[1])
  end

  task dump_species: :environment do
    ws = GSheets.import_worksheets
    populate_curation_worksheet_species(ws[0])
  end

  task dump: %i[dump_families dump_species] do
    puts 'Dumping taxonomic information...'
  end
end
