# Example-only policy; does not change the Flutter plugin's supported minimum OS.
module ExampleIosDeploymentTarget
  VERSION = '15.0'.freeze

  def self.apply(installer)
    projects = installer.generated_projects + installer.aggregate_targets.map(&:user_project)
    projects.compact.uniq.each do |project|
      configurations = project.build_configurations + project.targets.flat_map(&:build_configurations)
      configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = VERSION
      end
      project.save
    end
  end
end
