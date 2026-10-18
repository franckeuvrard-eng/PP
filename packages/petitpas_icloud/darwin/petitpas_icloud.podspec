Pod::Spec.new do |s|
  s.name             = 'petitpas_icloud'
  s.version          = '1.0.0'
  s.summary          = "Acces au conteneur iCloud Drive prive de l'application."
  s.homepage         = 'https://github.com/franckeuvrard-eng/PP'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'A petits pas'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.swift_version    = '5.0'
end
