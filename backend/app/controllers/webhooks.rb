class ArchivesSpaceService < Sinatra::Base


  Endpoint.post('/webhooks/register')
    .params(["url", String, "The URL to receive POST notifications"])
    .permissions([])
    .returns([200, "OK"]) \
  do
    Webhooks.add_listener(params[:url])
    "OK"
  end


  Endpoint.get('/webhooks/test')
    .permissions([])
    .returns([200, "OK"]) \
  do
    Webhooks.notify("HELLO", "it" => "works")
  end

end
