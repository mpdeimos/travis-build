module Travis
  module Build
    class Script
      class Go < Script
        DEFAULTS = {
          gobuild_args: '-v',
          go: '1.3.3'
        }

        def export
          super
          sh.export 'TRAVIS_GO_VERSION', version, echo: false
        end

        def announce
          super
          sh.cmd 'gvm version'
          sh.cmd 'go version'
          sh.cmd 'go env', fold: 'go.env'
        end

        def setup
          super
          sh.cmd 'gvm get', fold: 'gvm.get'
          sh.cmd "gvm update && source #{HOME_DIR}/.gvm/scripts/gvm", fold: 'gvm.update'
          sh.cmd "gvm install #{version} --binary || gvm install #{version}", fold: 'gvm.install'
          sh.cmd "gvm use #{version}"

          sh.export 'GOPATH', "#{HOME_DIR}/gopath:$GOPATH", echo: true
          sh.export 'PATH', "#{HOME_DIR}/gopath/bin:$PATH", echo: true

          sh.mkdir "#{HOME_DIR}/gopath/src/#{data.source_host}/#{data.slug}", recursive: true, assert: false, timing: false
          sh.cmd "rsync -az ${TRAVIS_BUILD_DIR}/ #{HOME_DIR}/gopath/src/#{data.source_host}/#{data.slug}/", assert: false, timing: false

          sh.export "TRAVIS_BUILD_DIR", "#{HOME_DIR}/gopath/src/#{data.source_host}/#{data.slug}"
          sh.cd "#{HOME_DIR}/gopath/src/#{data.source_host}/#{data.slug}", assert: true
        end

        def install
          sh.if '-f Godeps/Godeps.json' do
            sh.export 'GOPATH', '${TRAVIS_BUILD_DIR}/Godeps/_workspace:$GOPATH', retry: false
            sh.export 'PATH', '${TRAVIS_BUILD_DIR}/Godeps/_workspace/bin:$PATH', retry: false

            if version >= 'go1.1'
              sh.if '! -d Godeps/_workspace/src' do
                sh.cmd "#{go_get_cmd} github.com/tools/godep", echo: true, retry: true, timing: true, assert: true
                sh.cmd 'godep restore', retry: true, timing: true, assert: true, echo: true
              end
            end
          end

          sh.if uses_make do
            sh.cmd 'true', retry: true, fold: 'install' # TODO instead negate the condition
          end
          sh.else do
            sh.cmd "#{go_get_cmd} #{config[:gobuild_args]} ./...", retry: true, fold: 'install'
          end
        end

        def script
          sh.if uses_make do
            sh.cmd 'make'
          end
          sh.else do
            sh.cmd "go test #{config[:gobuild_args]} ./..."
          end
        end

        def cache_slug
          super << '--go-' << config[:go].to_s # TODO should this not be version?
        end

        private

          def uses_make
            '-f GNUmakefile || -f makefile || -f Makefile || -f BSDmakefile'
          end

          def version
            case version = config[:go].to_s
            when '1'
              'go1.3.3'
            when '1.0'
              'go1.0.3'
            when '1.2'
              'go1.2.2'
            when '1.3'
              'go1.3.3'
            when /^[0-9]\.[0-9\.]+/
              "go#{version}"
            else
              version
            end
          end

          def gobuild_args
            config[:gobuild_args]
          end

          def go_version
            version = config[:go].to_s
            case version
            when '1'
              'go1.3.3'
            when '1.0'
              'go1.0.3'
            when '1.2'
              'go1.2.2'
            when '1.3'
              'go1.3.3'
            when /^[0-9]\.[0-9\.]+/
              "go#{config[:go]}"
            else
              config[:go]
            end
          end

          def go_get_cmd
            version < 'go1.2' ? 'go get' : 'go get -t'
          end
      end
    end
  end
end
