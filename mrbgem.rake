MRuby::Gem::Specification.new('mruby-uv') do |spec|
  spec.license = 'MIT'
  spec.authors = 'mattn'

  if ENV['OS'] == 'Windows_NT'
    spec.linker.libraries << ['uv', 'psapi', 'iphlpapi', 'ws2_32']
    next
  end

  require 'open3'

  libuv_dir = "#{build_dir}/libuv"
  libuv_lib = libfile "#{libuv_dir}/.libs/libuv"
  header = "#{libuv_dir}/include/uv.h"

  task :clean do
    FileUtils.rm_rf [libuv_dir, "#{libuv_dir}.tar.gz"]
  end

  file header do |t|
    FileUtils.mkdir_p libuv_dir

    _pp 'getting', "libuv"
    begin
      FileUtils.mkdir_p build_dir
      Dir.chdir(build_dir) do
        sh 'git clone --depth 1 https://github.com/joyent/libuv'
      end
    rescue IOError
      exit(-1)
    end
  end

  def run_command(env, command)
    Open3.popen2e(env, command) do |stdin, stdout, thread|
      print stdout.read
      fail "#{command} failed" if thread.value != 0
    end
  end

  file libuv_lib => header do |t|
    Dir.chdir(libuv_dir) do
      e = {
        'CC' => "#{spec.build.cc.command} #{spec.build.cc.flags.join(' ')}",
        'CXX' => "#{spec.build.cxx.command} #{spec.build.cxx.flags.join(' ')}",
        'LD' => "#{spec.build.linker.command} #{spec.build.linker.flags.join(' ')}",
        'AR' => spec.build.archiver.command }
      _pp 'autotools', libuv_dir
      run_command e, './autogen.sh' if File.exists? 'autogen.sh'
      run_command e, './configure --disable-shared --enable-static'
      run_command e, 'make'
    end
  end

  file "#{dir}/src/mrb_uv.c" => libuv_lib
  spec.cc.include_paths << "#{libuv_dir}/include"
  spec.linker.library_paths << File.dirname(libuv_lib)
  spec.linker.libraries << 'uv' << 'm'
end
