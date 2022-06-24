# frozen_string_literal: true

def collect_datasets(domain)
  path = dataset_path(domain)
  datasets = []
  Dir.each_child(path) do |d|
    dataset_script_path = File.join(path, d, 'dataset.rb')
    datasets.push(File.join(path, d)) if File.exist?(dataset_script_path)
  end

  datasets
end

def import_dataset(path)
  puts "Importing dataset [#{dataset_from_path(path)}]..."
  dataset_script = File.join(path, 'dataset.rb')
  raise "No dataset script found in [#{dataset_from_path(path)}]" unless File.exist?(dataset_script)

  load(dataset_script)
  puts "Imported dataset [#{dataset_from_path(path)}]."
end

def import_all_datasets(domain = '')
  datasets_paths = collect_datasets(domain)
  datasets_paths.each do |path|
    import_dataset(path)
  end
end

def dataset_path(name = '')
  File.absolute_path(File.join(Rails.configuration.x.datasets[:path], name), Rails.root)
end

def dataset_from_path(path)
  path.split('/').last
end

namespace :dataset do
  desc 'Dataset processing tasks'

  desc 'Import a given dataset(s)'
  task :import, [:dataset] => :environment do |_, args|
    if args[:dataset]
      dataset = args[:dataset]
      if dataset == 'core'
        import_all_datasets('core')
      else
        import_dataset(dataset_path(dataset))
      end
    else
      import_all_datasets('core')
      import_all_datasets
    end
  end
end
