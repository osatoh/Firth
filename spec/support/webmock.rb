require "webmock/rspec"

RSpec.configure do |config|
  # SafeHttp resolves hosts before connecting; keep specs off real DNS by
  # resolving every name to a public address by default.
  config.before do
    allow(Resolv).to receive(:getaddresses).and_return([ "93.184.215.14" ])
  end
end
