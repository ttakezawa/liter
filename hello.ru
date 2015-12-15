use Rack::Lint

run -> (env) {
  [
    '200',
    { 'Content-Type' => 'text/html' },
    ['Hello']
  ]
}
