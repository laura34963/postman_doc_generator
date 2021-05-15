Gem::Specification.new do |s|
  s.name        = 'postman_doc_generator'
  s.version     = '0.1.6'
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Generate Postman Doc Json After Run Rspec'
  s.description = 'A Json API Doc Generator of Postman'
  s.authors     = ['JiaRou']
  s.email       = 'laura34963@kdanmobile.com'
  s.homepage    = 'https://github.com/laura34963/postman_doc_generator'
  s.license     = 'MIT'

  s.files            = `git ls-files`.split("\n")
  s.extra_rdoc_files = [ 'README.md' ]
  s.rdoc_options     = ['--charset=UTF-8']

  s.required_ruby_version = '>= 2.6.1'
  s.add_development_dependency 'rspec', ['~> 3.0']
end
