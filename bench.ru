require 'geminabox'

Geminabox.data = 'gems'
Geminabox.build_legacy = false
Geminabox.rubygems_proxy = true
Geminabox.allow_remote_failure = true

use Rack::Lint
run Geminabox::Server
