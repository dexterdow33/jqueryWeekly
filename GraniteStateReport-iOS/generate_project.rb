#!/usr/bin/env ruby
# Regenerates GraniteStateReport.xcodeproj from the source folders.
# You do not need to run this to build the app: the project is checked in.
# Run it only after adding, removing or renaming source files outside Xcode.
#
#   gem install xcodeproj
#   ruby generate_project.rb

require 'xcodeproj'

ROOT        = __dir__
NAME        = 'GraniteStateReport'
BUNDLE_ID   = 'com.granitestatereport.app'
DEPLOYMENT  = '17.0'
VERSION     = '1.0.0'
BUILD       = '1'

project_path = File.join(ROOT, "#{NAME}.xcodeproj")
project = Xcodeproj::Project.new(project_path, false, 56)
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'

app   = project.new_target(:application, NAME, :ios, DEPLOYMENT, nil, :swift)
tests = project.new_target(:unit_test_bundle, "#{NAME}Tests", :ios, DEPLOYMENT, nil, :swift)
tests.add_dependency(app)

# Mirror a folder on disk as groups, adding each file to the right build phase.
def add_folder(project, target, group, dir, skip: [])
  Dir.children(dir).sort.each do |entry|
    next if entry.start_with?('.')
    path = File.join(dir, entry)
    if File.directory?(path) && File.extname(entry) != '.xcassets'
      add_folder(project, target, group.new_group(entry, entry), path, skip: skip)
    else
      ref = group.new_file(entry)
      next if skip.include?(entry)
      case File.extname(entry)
      when '.swift'
        target.source_build_phase.add_file_reference(ref)
      when '.xcassets', '.xcprivacy'
        target.resources_build_phase.add_file_reference(ref)
      end
    end
  end
end

app_group = project.main_group.new_group(NAME, NAME)
add_folder(project, app, app_group, File.join(ROOT, NAME), skip: ['Info.plist'])

test_group = project.main_group.new_group("#{NAME}Tests", "#{NAME}Tests")
add_folder(project, tests, test_group, File.join(ROOT, "#{NAME}Tests"))

# Xcode links system frameworks on its own. Drop the SDK-versioned references the
# generator adds so the project does not depend on one Xcode release.
[app, tests].each { |target| target.frameworks_build_phase.clear }
project.frameworks_group.clear

common = {
  'SWIFT_VERSION'                 => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET'    => DEPLOYMENT,
  'TARGETED_DEVICE_FAMILY'        => '1',
  'MARKETING_VERSION'             => VERSION,
  'CURRENT_PROJECT_VERSION'       => BUILD,
  'CODE_SIGN_STYLE'               => 'Automatic',
  'DEVELOPMENT_TEAM'              => '',
  'SWIFT_EMIT_LOC_STRINGS'        => 'YES'
}

app.build_configurations.each do |config|
  config.build_settings.merge!(common)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER'                      => BUNDLE_ID,
    'PRODUCT_NAME'                                   => '$(TARGET_NAME)',
    'INFOPLIST_FILE'                                 => "#{NAME}/Resources/Info.plist",
    'GENERATE_INFOPLIST_FILE'                        => 'NO',
    'ASSETCATALOG_COMPILER_APPICON_NAME'             => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'ENABLE_PREVIEWS'                                => 'YES',
    'LD_RUNPATH_SEARCH_PATHS'                        => ['$(inherited)', '@executable_path/Frameworks'],
    'SUPPORTS_MACCATALYST'                           => 'NO',
    'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'          => 'NO',
    'SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD'           => 'NO'
  )
end

tests.build_configurations.each do |config|
  config.build_settings.merge!(common)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{BUNDLE_ID}.tests",
    'PRODUCT_NAME'              => '$(TARGET_NAME)',
    'GENERATE_INFOPLIST_FILE'   => 'YES',
    'BUNDLE_LOADER'             => '$(TEST_HOST)',
    'TEST_HOST'                 => "$(BUILT_PRODUCTS_DIR)/#{NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/#{NAME}"
  )
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app, tests, launch_target: true)
scheme.save_as(project_path, NAME, true)

puts "Wrote #{project_path}"
