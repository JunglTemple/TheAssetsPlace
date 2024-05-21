require 'glimmer-dsl-swt'
require 'nokogiri'
require 'open-uri'
require 'digest'
require 'fileutils'
require 'toml-rb'

class TheAssetsPlace
  include Glimmer

  REMOTE_ASSETFILE_URL = 'https://raw.githubusercontent.com/yourusername/yourrepo/main/assets/Assetfile.xml'
  LOCAL_ASSETFILE_PATH = 'assets/Assetfile.xml'
  CONFIG_DIR = File.join(Dir.home, 'TheAssetsPlace')
  CONFIG_PATH = File.join(CONFIG_DIR, 'config.toml')
  DEFAULT_DOWNLOADS_PATH = File.join(Dir.home, 'Downloads', 'TheAssetsPlace')

  def initialize
    ensure_config_exists
    @config = load_config
    set_default_paths
    check_for_updates
    @assets = fetch_metadata(LOCAL_ASSETFILE_PATH)
  end

  def launch
    shell {
      text 'The Assets Place'
      minimum_size 600, 400

      composite {
        grid_layout 2, false

        label {
          text 'Enter asset name:'
        }
        @asset_name = text {
          layout_data {
            horizontal_alignment :fill
            grab_excess_horizontal_space true
          }
        }

        button {
          text 'Download Asset'
          on_widget_selected {
            download_asset(@asset_name.text)
          }
        }

        label {
          text 'Status:'
        }
        @status = label {
          text ''
          layout_data {
            horizontal_alignment :fill
            grab_excess_horizontal_space true
          }
        }
      }

      @asset_list = composite {
        grid_layout 1, false
        layout_data {
          horizontal_span 2
          horizontal_alignment :fill
          grab_excess_horizontal_space true
        }

        render_asset_list
      }
    }.open
  end

  def ensure_config_exists
    unless File.exist?(CONFIG_PATH)
      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_PATH, <<~TOML)
				[minecraft]
				resourcepacks_path = ""
				mods_path = ""
				[generic]
				generic_path = ""
			TOML
      puts "Default config.toml created at #{CONFIG_PATH}. Please update the paths accordingly."
    end
  end

  def load_config
    TomlRB.load_file(CONFIG_PATH)
  rescue
    puts "Error loading config.toml. Please ensure the file exists and is correctly formatted."
    exit
  end

  def set_default_paths
    @config['minecraft']['resourcepacks_path'] = File.join(Dir.home, 'AppData', 'Roaming', '.minecraft', 'resourcepacks') if @config['minecraft']['resourcepacks_path'].empty?
    @config['minecraft']['mods_path'] = File.join(Dir.home, 'AppData', 'Roaming', '.minecraft', 'mods') if @config['minecraft']['mods_path'].empty?
    @config['generic']['generic_path'] = DEFAULT_DOWNLOADS_PATH if @config['generic']['generic_path'].empty?
  end

  def check_for_updates
    remote_assetfile_content = URI.open(REMOTE_ASSETFILE_URL).read
    local_assetfile_content = File.exist?(LOCAL_ASSETFILE_PATH) ? File.read(LOCAL_ASSETFILE_PATH) : ''

    if Digest::SHA256.hexdigest(remote_assetfile_content) != Digest::SHA256.hexdigest(local_assetfile_content)
      File.write(LOCAL_ASSETFILE_PATH, remote_assetfile_content)
      puts "Assetfile updated."
    else
      puts "Assetfile is up to date."
    end
  end

  def fetch_metadata(file_path)
    xml_data = File.read(file_path)
    doc = Nokogiri::XML(xml_data)
    assets = []

    doc.xpath('//asset').each do |asset_node|
      asset = {
        name: asset_node.xpath('name').text,
        filename: asset_node.xpath('filename').text,
        division: asset_node.xpath('division').text,
        description: asset_node.xpath('description').text,
        url: asset_node.xpath('url').text
      }
      assets << asset
    end

    assets
  end

  def download_asset(asset_name)
    selected_asset = @assets.find { |asset| asset[:name].casecmp(asset_name).zero? }

    if selected_asset
      destination_path = determine_destination_path(selected_asset)
      FileUtils.mkdir_p(File.dirname(destination_path))
      File.open(destination_path, 'wb') do |file|
        file.write(URI.open(selected_asset[:url]).read)
      end
      @status.text = "#{selected_asset[:name]} downloaded to #{destination_path}"
    else
      @status.text = "Asset not found."
    end
  end

  def determine_destination_path(asset)
    case asset[:division]
    when 'minecraft@mod'
      File.join(@config['minecraft']['mods_path'], asset[:filename])
    when 'minecraft@rp'
      File.join(@config['minecraft']['resourcepacks_path'], asset[:filename])
    when 'generic@generic'
      File.join(@config['generic']['generic_path'], asset[:filename])
    else
      File.join(DEFAULT_DOWNLOADS_PATH, asset[:filename])
    end
  end

  def render_asset_list
    @assets.each do |asset|
      composite {
        label {
          text "#{asset[:name]}: #{asset[:description]}"
        }
        label {
          text "URL: #{asset[:url]}"
        }
      }
    end
  end
end

TheAssetsPlace.new.launch
