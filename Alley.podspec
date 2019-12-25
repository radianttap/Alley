Pod::Spec.new do |s|
  s.name         = 'Alley'
  s.version      = '0.9'
  s.summary      = 'URLSessionDataTask with automatic retry mechanism.'
  s.description  = 'An extension for URLSession to perform automatic retries of request towards HTTP(S) web services.'

  s.homepage     = 'https://github.com/radianttap/Alley'
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { 'Aleksandar Vacić' => 'radianttap.com' }
  s.social_media_url   			= "https://twitter.com/radiantav"

  s.ios.deployment_target 		= "10.0"
  s.tvos.deployment_target 		= "12.0"
  s.osx.deployment_target 		= "10.10"
  s.watchos.deployment_target 	= "4.3"

  s.source       = { :git => "https://github.com/radianttap/Alley.git" }
  s.source_files = 'Alley/*.swift'

  s.swift_version  = '5.0'
end
