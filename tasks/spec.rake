require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

spec_defaults = lambda do |spec|
  spec.pattern    = 'spec/**/*_spec.rb'
  spec.libs      << 'lib' << 'spec'
  spec.spec_opts << '--options' << 'spec/spec.opts'
end

Spec::Rake::SpecTask.new(:spec, &spec_defaults)

Spec::Rake::SpecTask.new(:rcov) do |rcov|
  spec_defaults.call(rcov)
  rcov.rcov       = true
  rcov.rcov_opts << File.readlines('spec/rcov.opts').map { |line| line.strip }
end

RCov::VerifyTask.new(:verify_rcov => :rcov) do |rcov|
  rcov.threshold = 94.73
end

# original code by Ashley Moran:
# http://aviewfromafar.net/2007/11/1/rake-task-for-heckling-your-specs
desc 'Heckle each module and class'
task :heckle => :verify_rcov do
  root_module = 'Yardstick'
  spec_files  = FileList['spec/**/*_spec.rb']

  current_module = nil
  current_method = nil

  heckle_caught_modules = Hash.new { |hash, key| hash[key] = [] }
  unhandled_mutations = 0

  IO.popen("spec --heckle #{root_module} #{spec_files}") do |pipe|
    while line = pipe.gets
      case line = line.chomp
        when /\A\*\*\*\s+(#{root_module}(?:::)?(?:\w+(?:::)?)*)#(\w+)\b/
          current_module, current_method = $1, $2
        when "The following mutations didn't cause test failures:"
          heckle_caught_modules[current_module] << current_method
        when '+++ mutation'
          unhandled_mutations += 1
      end

      puts line
    end
  end

  if unhandled_mutations > 0
    error_message_lines = [ "*************\n" ]

    error_message_lines << "Heckle found #{unhandled_mutations} " \
      "mutation#{"s" unless unhandled_mutations == 1} " \
      "that didn't cause spec violations\n"

    heckle_caught_modules.each do |mod, methods|
      error_message_lines << "#{mod} contains the following " \
        'poorly-specified methods:'
      methods.each do |m|
        error_message_lines << " - #{m}"
      end
      error_message_lines << ''
    end

    error_message_lines << 'Get your act together and come back ' \
      'when your specs are doing their job!'

    puts '*************'
    raise error_message_lines.join("\n")
  else
    puts 'Well done! Your code withstood a heckling.'
  end
end

task :default => :spec
