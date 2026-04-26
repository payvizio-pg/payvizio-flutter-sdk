Pod::Spec.new do |s|
  s.name             = 'payvizio'
  s.version          = '0.1.0'
  s.summary          = 'Flutter wrapper around the Payvizio iOS SDK.'
  s.homepage         = 'https://payvizio.com'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Payvizio'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.9'
  s.dependency 'Flutter'
  s.dependency 'Payvizio', '~> 0.1.0'
end
