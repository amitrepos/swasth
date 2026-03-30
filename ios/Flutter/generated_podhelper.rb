require 'json'

def flutter_install_all_ios_pods(ios_application_path = nil)
  native_additions_path = File.join(File.realpath('..'), '.flutter-plugins-dependencies')
  return unless File.exist?(native_additions_path)
  
  dependencies_file = JSON.parse(File.read(native_additions_path))
  dependencies_file['plugins']['ios'].each do |plugin|
    # Check common locations for podspecs
    possible_paths = [
      File.join(plugin['path'], 'ios'),
      File.join(plugin['path'], 'darwin'),
      plugin['path']
    ]
    
    selected_path = possible_paths.find { |path| Dir.glob(File.join(path, '*.podspec')).any? }
    
    if selected_path
      pod plugin['name'], :path => selected_path
    else
      puts "Warning: Still couldn't find podspec for #{plugin['name']}"
    end
  end
end

def flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
  end
end
