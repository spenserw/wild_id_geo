module DatasetsHelper
  def self.fetch_resource(url, filename: '', base_dir: '.', extract: true, extract_dir: '.')
    filename = %r{/([^/]*)$}.match(url)[1] if filename.empty?
    filepath = "#{base_dir}/#{filename}"

    `wget #{url} -O #{filepath}` unless File.exist?(filepath)

    return unless extract

    # Extract if necessary
    if filename.end_with?('.zip')
      `unzip -od #{extract_dir} #{filepath}`
    elsif filename.end_with?('.7z')
      `7z x -o#{extract_dir} #{filepath}`
    end
  end
end
